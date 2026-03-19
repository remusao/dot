#!/usr/bin/env bash
# HP ZBook Ultra G1a — Kernel Panic Diagnostic Script
# Collects all relevant data after a "Fatal exception in interrupt" panic.
# Strictly read-only. Never writes, modifies, creates, or deletes anything.
#
# Usage: bash zbook-panic-diag.sh
#        bash zbook-panic-diag.sh | tee diag-output.txt
#        sudo bash zbook-panic-diag.sh   # for full diagnostics

set -uo pipefail

# ── Color setup (NO_COLOR + terminal detection) ──────────────────────────────
USE_COLOR=true
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    USE_COLOR=false
fi

if $USE_COLOR && command -v tput &>/dev/null && tput colors &>/dev/null; then
    C_GREEN=$(tput setaf 2)
    C_YELLOW=$(tput setaf 3)
    C_RED=$(tput setaf 1)
    C_CYAN=$(tput setaf 6)
    C_DIM=$(tput dim)
    C_BOLD=$(tput bold)
    C_RESET=$(tput sgr0)
else
    C_GREEN="" C_YELLOW="" C_RED="" C_CYAN="" C_DIM="" C_BOLD="" C_RESET=""
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
has_root() { [[ ${EUID:-$(id -u)} -eq 0 ]]; }
cmd_exists() { command -v "$1" &>/dev/null; }

section() {
    printf '\n%s══ %s ══%s\n' "$C_BOLD" "$1" "$C_RESET"
}

finding() {
    local severity="$1" msg="$2"
    case "$severity" in
        critical) printf '  %s[CRITICAL]%s %s\n' "$C_RED"    "$C_RESET" "$msg" ;;
        warn)     printf '  %s[  WARN  ]%s %s\n' "$C_YELLOW" "$C_RESET" "$msg" ;;
        ok)       printf '  %s[   OK   ]%s %s\n' "$C_GREEN"  "$C_RESET" "$msg" ;;
        info)     printf '  %s[  INFO  ]%s %s\n' "$C_CYAN"   "$C_RESET" "$msg" ;;
        skip)     printf '  %s[  SKIP  ]%s %s\n' "$C_DIM"    "$C_RESET" "$msg" ;;
    esac
}

dump() {
    # Print raw output indented, truncated to $2 lines (default 30)
    local max_lines="${2:-30}"
    local output="$1"
    if [[ -z "$output" ]]; then
        printf '    %s(empty)%s\n' "$C_DIM" "$C_RESET"
        return
    fi
    echo "$output" | head -n "$max_lines" | while IFS= read -r line; do
        printf '    %s\n' "$line"
    done
    local total
    total=$(echo "$output" | wc -l)
    if [[ "$total" -gt "$max_lines" ]]; then
        printf '    %s... (%d more lines)%s\n' "$C_DIM" "$((total - max_lines))" "$C_RESET"
    fi
}

# ── Kernel cmdline (parsed once) ─────────────────────────────────────────────
CMDLINE_PARAMS=()
if [[ -r /proc/cmdline ]]; then
    read -ra CMDLINE_PARAMS < /proc/cmdline
fi

kparam_value() {
    local target="${1//-/_}"
    for param in "${CMDLINE_PARAMS[@]}"; do
        local normalized="${param//-/_}"
        if [[ "$normalized" == "${target}="* ]]; then
            printf '%s' "${param#*=}"
            return 0
        fi
    done
    return 1
}

kparam_present() {
    local target="${1//-/_}"
    for param in "${CMDLINE_PARAMS[@]}"; do
        local normalized="${param//-/_}"
        if [[ "$normalized" == "$target" ]] || [[ "$normalized" == "${target}="* ]]; then
            return 0
        fi
    done
    return 1
}

# ── Analysis state ────────────────────────────────────────────────────────────
declare -a LIKELY_CAUSES=()
declare -a RECOMMENDATIONS=()

flag_cause() { LIKELY_CAUSES+=("$1"); }
flag_fix()   { RECOMMENDATIONS+=("$1"); }

# ══════════════════════════════════════════════════════════════════════════════
# Section 1: System Identity
# ══════════════════════════════════════════════════════════════════════════════
collect_identity() {
    section "System Identity"

    local product
    product=$(cat /sys/class/dmi/id/product_name 2>/dev/null) || product="unknown"
    finding info "Product: $product"

    local kver
    kver=$(uname -r)
    finding info "Kernel: $kver"

    local cmdline
    cmdline=$(cat /proc/cmdline 2>/dev/null) || cmdline="(unreadable)"
    finding info "Cmdline: $cmdline"

    # Check for missing critical params
    if ! kparam_present "pcie_aspm" || [[ "$(kparam_value pcie_aspm 2>/dev/null)" != "off" ]]; then
        finding critical "pcie_aspm=off is NOT set — #1 likely cause of kernel panics on this hardware"
        flag_cause "MISSING pcie_aspm=off: PCIe ASPM regression (Ubuntu #2115969) causes GUI freezes and potential panics, especially with external displays"
        flag_fix "Add pcie_aspm=off to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub"
    else
        finding ok "pcie_aspm=off is set"
    fi

    if ! kparam_present "amd_iommu" || [[ "$(kparam_value amd_iommu 2>/dev/null)" != "off" ]]; then
        finding warn "amd_iommu=off is NOT set — may cause suspend failures and contribute to instability"
        flag_fix "Add amd_iommu=off to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub"
    else
        finding ok "amd_iommu=off is set"
    fi

    local pstate_val
    pstate_val=$(kparam_value amd_pstate 2>/dev/null) || pstate_val=""
    if [[ "$pstate_val" == "active" ]]; then
        finding ok "amd_pstate=active is set"
    else
        finding warn "amd_pstate=active is NOT set (current: ${pstate_val:-not set})"
        flag_fix "Add amd_pstate=active to GRUB_CMDLINE_LINUX_DEFAULT"
    fi

    local bios_ver bios_date
    bios_ver=$(cat /sys/class/dmi/id/bios_version 2>/dev/null) || bios_ver="unknown"
    bios_date=$(cat /sys/class/dmi/id/bios_date 2>/dev/null) || bios_date="unknown"
    finding info "BIOS: $bios_ver ($bios_date)"

    printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════════
# Section 2: Pstore — Most Reliable Panic Source
# ══════════════════════════════════════════════════════════════════════════════
collect_pstore() {
    section "Pstore (Persistent Store — Best Panic Log Source)"

    local found_pstore=false

    # Check live pstore
    if [[ -d /sys/fs/pstore ]]; then
        local pstore_files
        pstore_files=$(ls /sys/fs/pstore/ 2>/dev/null) || pstore_files=""
        if [[ -n "$pstore_files" ]]; then
            found_pstore=true
            finding critical "Pstore panic logs found in /sys/fs/pstore/:"
            for f in /sys/fs/pstore/*; do
                [[ -f "$f" ]] || continue
                finding info "  $(basename "$f") ($(stat -c%s "$f" 2>/dev/null || echo '?') bytes)"
                printf '\n  %s── Contents of %s ──%s\n' "$C_BOLD" "$(basename "$f")" "$C_RESET"
                dump "$(cat "$f" 2>/dev/null)" 80
            done
        else
            finding info "Pstore directory exists but is empty (no panic captured, or already archived)"
        fi
    else
        finding warn "Pstore not available (/sys/fs/pstore/ missing) — panic logs may not be captured"
        flag_fix "Consider installing linux-crashdump: sudo apt install linux-crashdump"
    fi

    # Check archived pstore (systemd-pstore moves files here on boot)
    if [[ -d /var/lib/systemd/pstore ]]; then
        local archived
        archived=$(ls /var/lib/systemd/pstore/ 2>/dev/null) || archived=""
        if [[ -n "$archived" ]]; then
            found_pstore=true
            finding critical "Archived pstore logs found in /var/lib/systemd/pstore/:"
            for f in /var/lib/systemd/pstore/*; do
                [[ -f "$f" ]] || continue
                finding info "  $(basename "$f") ($(stat -c%s "$f" 2>/dev/null || echo '?') bytes)"
                printf '\n  %s── Contents of %s ──%s\n' "$C_BOLD" "$(basename "$f")" "$C_RESET"
                dump "$(cat "$f" 2>/dev/null)" 80
            done
        fi
    fi

    if ! $found_pstore; then
        finding info "No pstore panic data found — either no panic was captured, or pstore is not supported"
        # Check if pstore module is loaded
        local pstore_dmesg
        pstore_dmesg=$(dmesg 2>/dev/null | grep -i pstore | head -5) || pstore_dmesg=""
        if [[ -n "$pstore_dmesg" ]]; then
            finding info "Pstore in dmesg:"
            dump "$pstore_dmesg" 5
        fi
    fi

    printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════════
# Section 3: Previous Boot Logs
# ══════════════════════════════════════════════════════════════════════════════
collect_previous_boot() {
    section "Previous Boot Kernel Logs"

    # Check if persistent journal exists
    if [[ -d /var/log/journal ]]; then
        finding ok "journald persistent storage enabled (/var/log/journal exists)"
    else
        finding warn "journald NOT persistent — previous boot logs are lost on reboot"
        flag_fix "Enable persistent journal: sudo mkdir -p /var/log/journal && sudo systemd-tmpfiles --create --prefix /var/log/journal && sudo systemctl restart systemd-journald"
    fi

    # Try previous boot
    local prev_boot
    prev_boot=$(journalctl -b -1 -k --no-pager 2>/dev/null | grep -iE "panic|fatal|exception|fault|amdgpu|mt79|pcie|iommu|mce|machine.check|reset|timeout|GPU|error" | head -80) || prev_boot=""

    if [[ -n "$prev_boot" ]]; then
        finding critical "Relevant entries from previous boot kernel log:"
        dump "$prev_boot" 80

        # Pattern matching for known causes
        if echo "$prev_boot" | grep -qi "Fatal exception in interrupt"; then
            finding critical "CONFIRMED: 'Fatal exception in interrupt' — oops in IRQ context, kernel panicked"
        fi
        if echo "$prev_boot" | grep -qi "GCVM_L2_PROTECTION_FAULT"; then
            finding critical "GPU memory protection fault detected — likely MES firmware issue (ROCm #5724)"
            flag_cause "GPU memory protection fault (GCVM_L2_PROTECTION_FAULT) — check linux-firmware version"
        fi
        if echo "$prev_boot" | grep -qi "MES failed to respond\|MES.*timeout\|MES.*unrecoverable"; then
            finding critical "MES firmware hang detected — GPU scheduler became unresponsive"
            flag_cause "MES firmware hang — may need amdgpu.cwsr_enable=0 and/or linux-firmware update"
        fi
        if echo "$prev_boot" | grep -qi "ring.*timeout\|device lost from bus"; then
            finding critical "GPU ring timeout or device loss detected"
            flag_cause "amdgpu ring timeout / device loss — GPU became unresponsive"
        fi
        if echo "$prev_boot" | grep -qiE "AER.*error\|PCIe Bus Error\|severity="; then
            finding critical "PCIe AER (Advanced Error Reporting) errors detected"
            flag_cause "PCIe bus errors — strongly suggests pcie_aspm=off is needed"
        fi
        if echo "$prev_boot" | grep -qiE "mce.*hardware|machine check|Fatal Machine check"; then
            finding critical "Machine Check Exception (MCE) / hardware error detected"
            flag_cause "Hardware error (MCE) — may indicate hardware defect. Update BIOS, consider RMA if persistent."
        fi
        if echo "$prev_boot" | grep -qi "mt7925\|mt76"; then
            finding warn "MT7925 WiFi driver messages found in crash context"
            flag_cause "MT7925 WiFi driver involved — PCIe ASPM interaction suspected"
        fi
    else
        finding warn "No relevant entries found in previous boot log (may not have been persisted before panic)"
        finding info "Pstore (section above) is the more reliable source for panic data"
    fi

    # Also check current boot for GPU errors (indicators of ongoing instability)
    local current_gpu_errors
    current_gpu_errors=$(dmesg 2>/dev/null | grep -iE "amdgpu.*error|amdgpu.*fault|amdgpu.*timeout|amdgpu.*reset|amdgpu.*fail|gpu.*hang" | head -20) || current_gpu_errors=""
    if [[ -n "$current_gpu_errors" ]]; then
        finding warn "GPU errors in CURRENT boot dmesg (indicates ongoing instability):"
        dump "$current_gpu_errors" 20
    else
        finding ok "No GPU errors in current boot dmesg"
    fi

    printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════════
# Section 4: GPU & Firmware State
# ══════════════════════════════════════════════════════════════════════════════
collect_gpu() {
    section "GPU & Firmware State"

    # GPU device
    local gpu
    gpu=$(lspci -nn 2>/dev/null | grep "1002:" | head -1) || gpu=""
    if [[ -n "$gpu" ]]; then
        finding info "GPU: $gpu"
    else
        finding warn "AMD GPU not found in lspci"
    fi

    # amdgpu firmware versions (debugfs — root only)
    if has_root && [[ -d /sys/kernel/debug/dri ]]; then
        local fw_info=""
        for card_dir in /sys/kernel/debug/dri/*/; do
            if [[ -f "${card_dir}amdgpu_firmware_info" ]]; then
                fw_info=$(cat "${card_dir}amdgpu_firmware_info" 2>/dev/null) || fw_info=""
                break
            fi
        done
        if [[ -n "$fw_info" ]]; then
            finding info "amdgpu firmware versions (from debugfs):"
            # Show key firmware versions
            local mes_ver sdma_ver rlc_ver
            mes_ver=$(echo "$fw_info" | grep -i "MES" | head -2) || mes_ver=""
            sdma_ver=$(echo "$fw_info" | grep -i "SDMA" | head -2) || sdma_ver=""
            rlc_ver=$(echo "$fw_info" | grep -i "RLC" | head -2) || rlc_ver=""
            [[ -n "$mes_ver" ]] && dump "$mes_ver" 5
            [[ -n "$sdma_ver" ]] && dump "$sdma_ver" 5
            [[ -n "$rlc_ver" ]] && dump "$rlc_ver" 5

            # Check for problematic MES firmware 0x83
            if echo "$fw_info" | grep -qi "MES.*83\|MES.*0x83"; then
                finding critical "MES firmware 0x83 detected — KNOWN to cause GPU page faults on Strix Halo (ROCm #5724)"
                flag_cause "MES firmware 0x83 (from linux-firmware-20251125) causes GCVM_L2_PROTECTION_FAULT"
                flag_fix "Update linux-firmware to >= 20260110: sudo apt update && sudo apt install linux-firmware"
            fi
        else
            finding info "Could not read amdgpu firmware versions from debugfs"
        fi
    elif cmd_exists amdgpu_top; then
        finding info "Trying amdgpu_top for firmware info (no root needed)..."
        local amdgpu_top_out
        amdgpu_top_out=$(timeout 5 amdgpu_top -d 2>/dev/null | head -30) || amdgpu_top_out=""
        if [[ -n "$amdgpu_top_out" ]]; then
            dump "$amdgpu_top_out" 30
        fi
    else
        finding skip "amdgpu firmware version check — requires root (debugfs) or amdgpu_top"
    fi

    # linux-firmware package version
    local fw_pkg_ver
    fw_pkg_ver=$(dpkg-query -W -f='${Version}' linux-firmware 2>/dev/null) || fw_pkg_ver=""
    if [[ -n "$fw_pkg_ver" ]]; then
        finding info "linux-firmware package: $fw_pkg_ver"
        if [[ "$fw_pkg_ver" == *"20251125"* ]] && [[ "$fw_pkg_ver" != *"20251125-2"* ]]; then
            finding critical "linux-firmware 20251125 is BROKEN for Strix Halo — causes GPU memory faults"
            flag_cause "Broken linux-firmware-20251125 (MES 0x83 regression)"
            flag_fix "Upgrade linux-firmware: sudo apt update && sudo apt install linux-firmware (need >= 20260110)"
        elif [[ "$fw_pkg_ver" == *"20251125-2"* ]]; then
            finding warn "linux-firmware 20251125-2 is a partial fix — upgrade to 20260110+ recommended"
            flag_fix "Upgrade linux-firmware to >= 20260110"
        fi
    fi

    # Connected displays
    finding info "Connected displays:"
    for connector in /sys/class/drm/card*-*/status; do
        [[ -f "$connector" ]] || continue
        local status name
        status=$(cat "$connector" 2>/dev/null) || status="unknown"
        name=$(basename "$(dirname "$connector")")
        if [[ "$status" == "connected" ]]; then
            finding info "  $name: $status"
            # Check if it's USB-C/DP (relevant to panic context)
            if [[ "$name" == *"DP"* || "$name" == *"USB"* ]]; then
                finding info "    ^ USB-C/DisplayPort — external displays increase amdgpu freeze frequency (Bug #2033295)"
            fi
        fi
    done

    # amdgpu module parameters
    local cwsr_val
    cwsr_val=$(cat /sys/module/amdgpu/parameters/cwsr_enable 2>/dev/null) || cwsr_val=""
    if [[ -n "$cwsr_val" ]]; then
        if [[ "$cwsr_val" == "0" ]]; then
            finding ok "amdgpu.cwsr_enable=0 (CWSR disabled — prevents compute-triggered MES hangs)"
        else
            finding info "amdgpu.cwsr_enable=$cwsr_val (CWSR enabled — only relevant for ROCm compute)"
        fi
    fi

    printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════════
# Section 5: PCIe & ASPM State
# ══════════════════════════════════════════════════════════════════════════════
collect_pcie() {
    section "PCIe & ASPM State"

    # Global ASPM policy
    local aspm_policy
    aspm_policy=$(cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null) || aspm_policy=""
    if [[ -n "$aspm_policy" ]]; then
        finding info "PCIe ASPM policy: $aspm_policy"
        if [[ "$aspm_policy" == *"[default]"* ]] || [[ "$aspm_policy" != *"off"* && "$aspm_policy" != *"\[performance\]"* ]]; then
            finding warn "ASPM is active — on this hardware, ASPM causes GUI freezes and potential panics"
        fi
    else
        finding info "PCIe ASPM policy not readable (may be compiled out with pcie_aspm=off)"
    fi

    # Key PCIe devices and their ASPM state
    finding info "Key PCIe devices:"

    # MT7925 WiFi (14c3:7925 — known ASPM interaction)
    local wifi_pci
    wifi_pci=$(lspci -nn 2>/dev/null | grep "14c3:7925") || wifi_pci=""
    if [[ -n "$wifi_pci" ]]; then
        finding info "  WiFi: $wifi_pci"
        local wifi_addr
        wifi_addr=$(echo "$wifi_pci" | awk '{print $1}')
        if [[ -f "/sys/bus/pci/devices/0000:${wifi_addr}/link/l1_aspm" ]]; then
            local wifi_l1
            wifi_l1=$(cat "/sys/bus/pci/devices/0000:${wifi_addr}/link/l1_aspm" 2>/dev/null) || wifi_l1=""
            finding info "    L1 ASPM: $wifi_l1"
        fi
    fi

    # AMD GPU
    local gpu_pci
    gpu_pci=$(lspci -nn 2>/dev/null | grep "1002:" | head -1) || gpu_pci=""
    if [[ -n "$gpu_pci" ]]; then
        finding info "  GPU: $gpu_pci"
    fi

    # Intel Ethernet (IGC — may disappear with pcie_aspm=off)
    local igc_pci
    igc_pci=$(lspci -nn 2>/dev/null | grep "8086:5502") || igc_pci=""
    if [[ -n "$igc_pci" ]]; then
        finding info "  Intel Ethernet: $igc_pci (note: may disappear with pcie_aspm=off)"
    else
        local any_eth
        any_eth=$(ip -br link 2>/dev/null | grep -E "^(eth|enp)" | head -1) || any_eth=""
        if [[ -z "$any_eth" ]] && kparam_present "pcie_aspm"; then
            finding info "  Intel Ethernet not detected (known side effect of pcie_aspm=off on some units)"
        fi
    fi

    # PCIe AER errors in current boot
    local aer_errors
    aer_errors=$(dmesg 2>/dev/null | grep -iE "AER.*error\|PCIe Bus Error" | head -10) || aer_errors=""
    if [[ -n "$aer_errors" ]]; then
        finding warn "PCIe AER errors in current boot:"
        dump "$aer_errors" 10
    else
        finding ok "No PCIe AER errors in current boot"
    fi

    printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════════
# Section 6: CPU, MCE & Hardware Errors
# ══════════════════════════════════════════════════════════════════════════════
collect_cpu_mce() {
    section "CPU, MCE & Hardware Errors"

    # CPU info
    local cpu
    cpu=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | sed 's/.*: //') || cpu="unknown"
    finding info "CPU: $cpu"

    # Microcode revision (important for CVE-2025-29943/StackWarp, AMD-SB-7055/RDSEED)
    local ucode
    ucode=$(grep -m1 "microcode" /proc/cpuinfo 2>/dev/null | awk -F': ' '{print $2}') || ucode=""
    if [[ -n "$ucode" ]]; then
        finding info "Microcode revision: $ucode (check AMD Security Bulletins for required versions)"
    fi

    # MCE errors in journal
    local mce_errors=""
    if has_root; then
        mce_errors=$(journalctl -b -k --no-pager -q 2>/dev/null | grep -iE "mce|machine.check|hardware.error|edac" | head -20) || mce_errors=""
    fi
    if [[ -z "$mce_errors" ]]; then
        mce_errors=$(dmesg 2>/dev/null | grep -iE "mce|machine.check|hardware.error|edac" | head -20) || mce_errors=""
    fi

    if [[ -n "$mce_errors" ]]; then
        finding critical "Machine Check Exception / hardware errors detected:"
        dump "$mce_errors" 20
        flag_cause "Hardware errors (MCE) detected — may indicate hardware defect or need BIOS/microcode update"
        flag_fix "Update BIOS/microcode: sudo fwupdmgr refresh && sudo fwupdmgr update"
    else
        finding ok "No MCE / hardware errors detected"
    fi

    # rasdaemon (correct MCE tool for AMD Zen — mcelog is non-functional)
    if cmd_exists rasdaemon; then
        finding ok "rasdaemon installed (correct MCE monitoring tool for AMD Zen)"
        if has_root; then
            local ras_errors
            ras_errors=$(ras-mc-ctl --errors 2>/dev/null | head -10) || ras_errors=""
            if [[ -n "$ras_errors" ]]; then
                finding info "rasdaemon error log:"
                dump "$ras_errors" 10
            fi
        fi
    else
        finding info "rasdaemon not installed — recommended for AMD Zen MCE monitoring (mcelog is non-functional on AMD). Install: sudo apt install rasdaemon"
    fi

    printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════════
# Section 7: IOMMU & NPU State
# ══════════════════════════════════════════════════════════════════════════════
collect_iommu() {
    section "IOMMU & NPU State"

    local iommu_groups
    iommu_groups=$(ls /sys/kernel/iommu_groups/ 2>/dev/null) || iommu_groups=""
    if [[ -z "$iommu_groups" ]]; then
        finding ok "IOMMU inactive — best for suspend reliability"
    else
        finding info "IOMMU active — suspend may be unreliable on this hardware"
    fi

    # NPU
    if lsmod 2>/dev/null | grep -q amdxdna; then
        finding info "NPU driver (amdxdna) loaded"
    else
        finding info "NPU driver (amdxdna) not loaded (expected if amd_iommu=off)"
    fi

    printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════════
# Section 8: Power & Thermal State
# ══════════════════════════════════════════════════════════════════════════════
collect_power() {
    section "Power & Thermal State"

    # AC/battery
    local ac_status
    ac_status=$(cat /sys/class/power_supply/AC*/online 2>/dev/null | head -1) || ac_status=""
    if [[ "$ac_status" == "1" ]]; then
        finding info "Power: AC connected"
    elif [[ "$ac_status" == "0" ]]; then
        finding info "Power: on battery"
    fi

    # amd_pstate driver
    local pstate_status
    pstate_status=$(cat /sys/devices/system/cpu/amd_pstate/status 2>/dev/null) || pstate_status=""
    if [[ -n "$pstate_status" ]]; then
        finding info "amd_pstate driver: $pstate_status"
    fi

    # Power profile
    if cmd_exists powerprofilesctl; then
        local profile
        profile=$(powerprofilesctl get 2>/dev/null) || profile=""
        if [[ -n "$profile" ]]; then
            finding info "Power profile: $profile"
        fi
    fi

    printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════════
# Section 9: USB-C & Thunderbolt
# ══════════════════════════════════════════════════════════════════════════════
collect_usbc() {
    section "USB-C & Thunderbolt"

    # Thunderbolt devices
    local tb
    tb=$(lspci 2>/dev/null | grep -iE "thunderbolt|usb4" | head -3) || tb=""
    if [[ -n "$tb" ]]; then
        finding info "Thunderbolt/USB4 controllers:"
        dump "$tb" 5
    fi

    # USB devices (look for displays, docks)
    if cmd_exists lsusb; then
        local usb_devices
        usb_devices=$(lsusb 2>/dev/null | head -20) || usb_devices=""
        if [[ -n "$usb_devices" ]]; then
            finding info "USB devices:"
            dump "$usb_devices" 20
        fi
    fi

    # Thunderbolt security level
    local tb_security
    tb_security=$(cat /sys/bus/thunderbolt/devices/domain0/security 2>/dev/null) || tb_security=""
    if [[ -n "$tb_security" ]]; then
        finding info "Thunderbolt security: $tb_security"
    fi

    printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════════
# Section 10: GRUB Configuration
# ══════════════════════════════════════════════════════════════════════════════
collect_grub() {
    section "GRUB Configuration"

    if [[ -r /etc/default/grub ]]; then
        local grub_line
        grub_line=$(grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub 2>/dev/null) || grub_line=""
        if [[ -n "$grub_line" ]]; then
            finding info "Persisted: $grub_line"
        else
            finding warn "GRUB_CMDLINE_LINUX_DEFAULT not found in /etc/default/grub"
        fi

        # Check if running params match persisted params
        local running_cmdline
        running_cmdline=$(cat /proc/cmdline 2>/dev/null) || running_cmdline=""
        finding info "Running: $running_cmdline"

        # Check for critical params in GRUB
        if ! echo "$grub_line" | grep -q "pcie_aspm"; then
            finding warn "pcie_aspm=off not persisted in GRUB — will be lost on reboot"
        fi
        if ! echo "$grub_line" | grep -q "amd_iommu"; then
            finding warn "amd_iommu=off not persisted in GRUB"
        fi
    else
        finding skip "Cannot read /etc/default/grub"
    fi

    printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════════
# Section 11: Systemd State
# ══════════════════════════════════════════════════════════════════════════════
collect_systemd() {
    section "Systemd State"

    # Failed units
    local failed
    failed=$(systemctl --failed --no-pager --no-legend 2>/dev/null) || failed=""
    if [[ -n "$failed" ]]; then
        finding warn "Failed systemd units:"
        dump "$failed" 10
    else
        finding ok "No failed systemd units"
    fi

    # WiFi suspend services
    if systemctl is-enabled wifi-pre-suspend.service &>/dev/null; then
        finding ok "wifi-pre-suspend.service enabled"
    else
        finding warn "wifi-pre-suspend.service not enabled — WiFi may die after suspend"
    fi
    if systemctl is-enabled wifi-suspend-fix.service &>/dev/null; then
        finding ok "wifi-suspend-fix.service enabled"
    else
        finding warn "wifi-suspend-fix.service not enabled — WiFi may not reconnect after suspend"
    fi

    printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════════
# Section 12: Analysis & Recommendations
# ══════════════════════════════════════════════════════════════════════════════
print_analysis() {
    section "Analysis & Recommendations"

    # Likely causes
    if [[ ${#LIKELY_CAUSES[@]} -gt 0 ]]; then
        printf '\n  %sLikely Causes:%s\n' "$C_BOLD" "$C_RESET"
        local i=1
        for cause in "${LIKELY_CAUSES[@]}"; do
            printf '    %s%d.%s %s\n' "$C_RED" "$i" "$C_RESET" "$cause"
            i=$((i + 1))
        done
    else
        printf '\n  %sNo specific cause identified from available data.%s\n' "$C_YELLOW" "$C_RESET"
        printf '  If the panic was a one-time event and pstore has no data, apply the\n'
        printf '  recommended kernel parameters below to prevent recurrence.\n'
    fi

    # Recommendations
    printf '\n  %sRecommended Fix:%s\n' "$C_BOLD" "$C_RESET"
    printf '\n  Edit /etc/default/grub and set:\n'
    printf '  %sGRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_pstate=active amd_iommu=off pcie_aspm=off"%s\n' "$C_GREEN" "$C_RESET"
    printf '\n  Then run:\n'
    printf '  %ssudo update-grub && sudo reboot%s\n' "$C_GREEN" "$C_RESET"

    if [[ ${#RECOMMENDATIONS[@]} -gt 0 ]]; then
        printf '\n  %sAdditional Recommendations:%s\n' "$C_BOLD" "$C_RESET"
        local i=1
        for rec in "${RECOMMENDATIONS[@]}"; do
            printf '    %s%d.%s %s\n' "$C_YELLOW" "$i" "$C_RESET" "$rec"
            i=$((i + 1))
        done
    fi

    # Open bugs to track
    printf '\n  %sOpen Bugs to Track (remove workarounds when fixed):%s\n' "$C_BOLD" "$C_RESET"
    cat << 'BUGS'
    - pcie_aspm=off    → Ubuntu #2115969  https://bugs.launchpad.net/ubuntu/+source/linux-oem-6.14/+bug/2115969
    - amd_iommu=off    → Kernel #220702   https://bugzilla.kernel.org/show_bug.cgi?id=220702
    - amd_iommu=off    → Ubuntu #2141198  https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2141198
    - MES firmware      → ROCm  #5590     https://github.com/ROCm/ROCm/issues/5590
    - MES firmware      → ROCm  #5724     https://github.com/ROCm/ROCm/issues/5724
    - Random reboots   → HP    #9549358  https://h30434.www3.hp.com/t5/Business-Notebooks/HP-ZBook-Ultra-14-G1a-randomly-reboots/td-p/9549358
BUGS

    # If still panicking
    printf '\n  %sIf panics continue after applying all fixes:%s\n' "$C_BOLD" "$C_RESET"
    printf '    1. Install crash dump tool: sudo apt install linux-crashdump\n'
    printf '    2. Run this script again to collect new pstore/journal data\n'
    printf '    3. Update BIOS: sudo fwupdmgr refresh && sudo fwupdmgr update\n'
    printf '    4. If problem persists, likely hardware defect — contact HP for RMA\n'
    printf '       (random reboots affect 3/8 units in some batches, both Windows & Linux)\n'

    printf '\n'
}

# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════
main() {
    printf '%s╔══════════════════════════════════════════════════════════════╗%s\n' "$C_BOLD" "$C_RESET"
    printf '%s║  HP ZBook Ultra G1a — Kernel Panic Diagnostic              ║%s\n' "$C_BOLD" "$C_RESET"
    printf '%s╚══════════════════════════════════════════════════════════════╝%s\n' "$C_BOLD" "$C_RESET"
    printf 'Date: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Reference: ~/HP-ZBook-Ultra-G1a-Linux-Report.md\n'
    if ! has_root; then
        printf '%sNote: Run with sudo for full diagnostics (debugfs, MCE, firmware versions)%s\n' "$C_YELLOW" "$C_RESET"
    fi

    collect_identity
    collect_pstore
    collect_previous_boot
    collect_gpu
    collect_pcie
    collect_cpu_mce
    collect_iommu
    collect_power
    collect_usbc
    collect_grub
    collect_systemd
    print_analysis
}

main "$@"
