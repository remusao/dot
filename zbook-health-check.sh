#!/usr/bin/env bash
# HP ZBook Ultra G1a — Linux Health Check Script
# Checks the live system against every recommendation from the comprehensive Linux report.
# Strictly read-only. Never writes, modifies, creates, or deletes anything.

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

# ── Counters & remediation ───────────────────────────────────────────────────
COUNT_OK=0
COUNT_WARN=0
COUNT_FAIL=0
COUNT_SKIP=0
COUNT_INFO=0
REMEDIATION=()

# ── Kernel cmdline (parsed once, safely) ─────────────────────────────────────
CMDLINE_PARAMS=()
if [[ -r /proc/cmdline ]]; then
    read -ra CMDLINE_PARAMS < /proc/cmdline
fi

# ── Helper functions ─────────────────────────────────────────────────────────
ok()   { COUNT_OK=$((COUNT_OK+1));   printf '%s[  OK  ]%s %s\n' "$C_GREEN"  "$C_RESET" "$1"; }
warn() { COUNT_WARN=$((COUNT_WARN+1)); printf '%s[ WARN ]%s %s — %s\n' "$C_YELLOW" "$C_RESET" "$1" "$2"; }
fail() {
    COUNT_FAIL=$((COUNT_FAIL+1))
    printf '%s[ FAIL ]%s %s — %s\n' "$C_RED" "$C_RESET" "$1" "$2"
    if [[ -n "${3:-}" ]]; then
        REMEDIATION+=("$3")
    fi
}
info() { COUNT_INFO=$((COUNT_INFO+1)); printf '%s[ INFO ]%s %s\n' "$C_CYAN" "$C_RESET" "$1"; }
skip() { COUNT_SKIP=$((COUNT_SKIP+1)); printf '%s[ SKIP ]%s %s — %s\n' "$C_DIM" "$C_RESET" "$1" "$2"; }

section() {
    printf '\n%s── %s ──%s\n' "$C_BOLD" "$1" "$C_RESET"
}

has_root() { [[ ${EUID:-$(id -u)} -eq 0 ]]; }

cmd_exists() { command -v "$1" &>/dev/null; }

# Check if a kernel parameter is present in /proc/cmdline
# Handles underscore/hyphen equivalence (kernel treats them the same)
kparam_present() {
    local target="$1"
    local normalized_target="${target//-/_}"
    for param in "${CMDLINE_PARAMS[@]}"; do
        local normalized="${param//-/_}"
        if [[ "$normalized" == "$normalized_target" ]] || [[ "$normalized" == "${normalized_target}="* ]]; then
            return 0
        fi
    done
    return 1
}

# Get value of a kernel parameter (returns empty if not found or no value)
kparam_value() {
    local target="$1"
    local normalized_target="${target//-/_}"
    for param in "${CMDLINE_PARAMS[@]}"; do
        local normalized="${param//-/_}"
        if [[ "$normalized" == "${normalized_target}="* ]]; then
            printf '%s' "${param#*=}"
            return 0
        fi
    done
    return 1
}

# Check if a parameter exists in GRUB_CMDLINE_LINUX_DEFAULT
grub_has_param() {
    local target="$1"
    if [[ ! -r /etc/default/grub ]]; then
        return 1
    fi
    local grub_line
    grub_line=$(grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub 2>/dev/null) || return 1
    local normalized_target="${target//-/_}"
    local normalized_line="${grub_line//-/_}"
    [[ "$normalized_line" == *"$normalized_target"* ]]
}

pkg_installed() {
    local status
    status=$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null) || return 1
    [[ "$status" == "install ok installed" ]]
}

svc_active()  { systemctl is-active  "$1" &>/dev/null; }
svc_enabled() { systemctl is-enabled "$1" &>/dev/null; }

# ── Section 1: Hardware Identity ─────────────────────────────────────────────
check_hardware() {
    section "Hardware Identity"

    # Product name — SAFE: only reads product_name (never product_serial)
    local product
    product=$(cat /sys/class/dmi/id/product_name 2>/dev/null) || product=""
    if [[ "$product" == *"ZBook Ultra G1a"* ]]; then
        ok "HP ZBook Ultra G1a confirmed"
    else
        fail "Not a ZBook Ultra G1a" "detected: ${product:-unknown}. This script is hardware-specific and may give incorrect results on other hardware."
    fi

    # CPU — expected: Ryzen AI Max+ PRO 395
    local cpu
    cpu=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | sed 's/.*: //') || cpu="unknown"
    shopt -s nocasematch
    if [[ "$cpu" == *"Ryzen AI"* && "$cpu" == *"395"* ]]; then
        ok "CPU: $cpu"
    else
        fail "CPU mismatch" "expected Ryzen AI Max+ PRO 395, got: $cpu"
    fi
    shopt -u nocasematch

    # RAM — expected: 128 GB
    local ram_kb ram_gb
    ram_kb=$(grep -m1 "MemTotal" /proc/meminfo 2>/dev/null | awk '{print $2}') || ram_kb=0
    ram_gb=$(( ram_kb / 1048576 ))
    if [[ "$ram_gb" -ge 80 && "$ram_gb" -le 130 ]]; then
        ok "RAM: ${ram_gb} GB visible (128 GB physical — GPU frame buffer carves out ~25%)"
    else
        fail "RAM mismatch" "expected 80-130 GB visible (128 GB physical minus GPU frame buffer), got: ${ram_gb} GB"
    fi

    # Storage — expected: 4 TB NVMe SSD (PCIe 4x4, M.2 2280, TLC)
    local nvme_size_bytes nvme_size_tb
    nvme_size_bytes=$(lsblk -bdrn -o SIZE /dev/nvme0n1 2>/dev/null | head -1) || nvme_size_bytes=0
    if [[ "$nvme_size_bytes" =~ ^[0-9]+$ ]]; then
        nvme_size_tb=$(( nvme_size_bytes / 1000000000000 ))
    else
        nvme_size_tb=0
    fi
    if [[ "$nvme_size_tb" -ge 3 && "$nvme_size_tb" -le 4 ]]; then
        ok "NVMe SSD: ~${nvme_size_tb} TB (4 TB expected)"
    elif [[ "$nvme_size_tb" -gt 0 ]]; then
        fail "Storage mismatch" "expected 4 TB NVMe, got: ~${nvme_size_tb} TB"
    else
        fail "NVMe not detected" "expected 4 TB NVMe SSD at /dev/nvme0n1"
    fi

    # GPU — expected: AMD Radeon (Strix Halo)
    local gpu
    gpu=$(lspci -nn 2>/dev/null | grep "1002:" | head -1 | sed 's/.*: //') || gpu=""
    if [[ -n "$gpu" ]]; then
        ok "GPU: $gpu"
    else
        fail "AMD GPU not found" "expected AMD Radeon 8050S/8060S (vendor 1002). Ref: https://www.phoronix.com/review/hp-zbook-ultra-g1a/2"
    fi

    # WiFi — expected: MediaTek MT7925 (14c3:7925)
    local wifi_pci
    wifi_pci=$(lspci -nn 2>/dev/null | grep "14c3:7925") || wifi_pci=""
    if [[ -n "$wifi_pci" ]]; then
        ok "WiFi: MT7925 detected (Wi-Fi 7 + BT 5.4)"
    else
        fail "WiFi mismatch" "expected MediaTek MT7925 (14c3:7925), not found in lspci"
    fi

    # Random reboots advisory (hardware defect affecting subset of units)
    if has_root; then
        if journalctl -b -1 2>/dev/null | grep -qiE "hardware error|machine check|mce:|panic|Oops" 2>/dev/null; then
            warn "Unexpected reboot indicators found in previous boot journal" "random reboots affect some ZBook Ultra G1a units (3/8 in one batch). processor.max_cstate is NOT a reliable fix on AMD Zen 5 (Arch Wiki: parameter may not be applied, C6 state still entered). One user reported it worked for 2 days then failed — root cause was a hardware defect fixed by motherboard replacement. First: ensure pcie_aspm=off and update BIOS. If reboots persist, likely hardware — contact HP for RMA. Ref: https://h30434.www3.hp.com/t5/Business-Notebooks/HP-ZBook-Ultra-14-G1a-randomly-reboots/td-p/9549358 https://wiki.archlinux.org/title/Ryzen"
        fi
    fi

    # Pstore — most reliable source of kernel panic data
    if ls /sys/fs/pstore/dmesg-* &>/dev/null; then
        warn "Pstore panic logs found in /sys/fs/pstore/" "kernel panic data captured from a previous crash. Examine: cat /sys/fs/pstore/dmesg-*. Run the diagnostic script: bash ~/zbook-panic-diag.sh"
    elif ls /var/lib/systemd/pstore/dmesg-* &>/dev/null; then
        warn "Archived pstore panic logs found" "kernel panic data from a previous crash archived by systemd-pstore. Examine: cat /var/lib/systemd/pstore/dmesg-*"
    fi

    # Pstore availability (for capturing kernel panics)
    if [[ -d /sys/fs/pstore ]]; then
        ok "pstore available — kernel panic logs will be captured automatically"
    else
        warn "pstore not available" "kernel panic logs won't be captured. Install: sudo apt install linux-crashdump. Ref: https://wiki.ubuntu.com/Kernel/CrashdumpRecipe"
    fi

    # Persistent journal (for previous boot logs)
    if [[ -d /var/log/journal ]]; then
        ok "journald persistent storage enabled — previous boot logs available via journalctl -b -1"
    else
        warn "journald not using persistent storage" "previous boot logs are lost on reboot. Fix: sudo mkdir -p /var/log/journal && sudo systemd-tmpfiles --create --prefix /var/log/journal && sudo systemctl restart systemd-journald"
    fi

    # BIOS version — SAFE: only reads bios_version (never serial numbers)
    local bios_ver bios_date
    bios_ver=$(cat /sys/class/dmi/id/bios_version 2>/dev/null) || bios_ver="unknown"
    bios_date=$(cat /sys/class/dmi/id/bios_date 2>/dev/null) || bios_date="unknown"
    if [[ "$bios_ver" == *"01.03.02"* ]]; then
        warn "BIOS version $bios_ver ($bios_date)" "v1.03.02 has known fan regression — v1.03.00 was quieter. Check for BIOS update: sudo fwupdmgr update. Ref: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525"
    else
        info "BIOS: $bios_ver ($bios_date)"
    fi
}

# ── Section 2: OS & Kernel ───────────────────────────────────────────────────
check_os_kernel() {
    section "OS & Kernel"

    # Ubuntu version
    local ver
    if cmd_exists lsb_release; then
        ver=$(lsb_release -rs 2>/dev/null) || ver=""
    else
        ver=$(grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release 2>/dev/null) || ver=""
    fi
    if [[ "$ver" == "24.04" ]]; then
        ok "Ubuntu 24.04 LTS — certified by Canonical for this hardware. Ref: https://ubuntu.com/certified/platforms/15242"
    else
        fail "Not Ubuntu 24.04" "detected: ${ver:-unknown}. This script targets Ubuntu 24.04 LTS only (the Canonical-certified version). Ref: https://ubuntu.com/certified/platforms/15242"
    fi

    # Snap kernel (Ubuntu's experimental TPM FDE uses snap-delivered kernel)
    if [[ -d /snap/pc-kernel ]]; then
        fail "Experimental snap kernel detected" "incompatible with OEM kernel. Ubuntu's TPM FDE snap kernel cannot coexist with linux-oem-24.04. Canonical warns: 'Use only on systems where you don't mind losing data.' Ref: https://documentation.ubuntu.com/desktop/en/24.04/explanation/hardware-backed-disk-encryption/"
    else
        ok "No snap kernel — snap kernels break OEM kernel compatibility. Ref: https://documentation.ubuntu.com/desktop/en/24.04/explanation/hardware-backed-disk-encryption/"
    fi

    # Mesa version (25.0+ required for Strix Halo GPU support)
    local mesa_ver
    mesa_ver=$(dpkg-query -W -f='${Version}' libgl1-mesa-dri 2>/dev/null) || mesa_ver=""
    if [[ -z "$mesa_ver" ]]; then
        mesa_ver=$(dpkg-query -W -f='${Version}' mesa-vulkan-drivers 2>/dev/null) || mesa_ver=""
    fi
    if [[ -n "$mesa_ver" ]]; then
        local mesa_major
        mesa_major=$(echo "$mesa_ver" | grep -oP '^\d+' 2>/dev/null) || mesa_major=0
        if [[ "$mesa_major" =~ ^[0-9]+$ ]] && [[ "$mesa_major" -ge 25 ]]; then
            ok "Mesa: $mesa_ver (25.0+ required for Strix Halo). Ref: https://www.phoronix.com/review/hp-zbook-ultra-g1a/2"
        else
            warn "Mesa: $mesa_ver" "Mesa 25.0+ required for Strix Halo GPU (gfx1151). Older versions have missing features and security fixes. Run: sudo apt update && sudo apt upgrade. Ref: https://www.phoronix.com/review/hp-zbook-ultra-g1a/2"
        fi
    fi

    # OEM kernel meta-package (critical for webcam — AMD ISP4 driver not in mainline until ~7.1)
    if pkg_installed linux-oem-24.04; then
        ok "linux-oem-24.04 installed — provides AMD ISP4 webcam driver + stability patches. Ref: https://www.phoronix.com/review/hp-zbook-ultra-g1a/2"
    else
        fail "linux-oem-24.04 not installed" "OEM kernel is the ONLY way to get the webcam working. AMD ISP4 driver missed every mainline merge window (6.18, 6.19, 7.0). Ref: https://www.phoronix.com/news/AMD-ISP4-Driver-Pending-Review" \
            "sudo apt install linux-oem-24.04"
    fi

    # Running OEM kernel
    local kver
    kver=$(uname -r)
    if [[ "$kver" == *"-oem"* ]]; then
        ok "Running OEM kernel: $kver"
        # Check kernel version
        if [[ "$kver" == 6.17.* ]]; then
            ok "OEM kernel is 6.17.x (latest track). Ref: https://canonical-kernel-docs.readthedocs-hosted.com/latest/reference/oem-kernels/"
        else
            warn "OEM kernel version $kver" "expected 6.17.x — run: sudo apt update && sudo apt upgrade to get latest OEM kernel. Ref: https://launchpad.net/ubuntu/noble/amd64/linux-oem-24.04c"
        fi
    else
        warn "Not running OEM kernel" "current: $kver — reboot and select the OEM kernel in GRUB (or install: sudo apt install linux-oem-24.04). Required for webcam (AMD ISP4). Ref: https://www.phoronix.com/review/hp-zbook-ultra-g1a/2"
    fi

    # Lettered OEM kernel variant check (e.g., linux-image-oem-24.04c without the rolling meta)
    if ! pkg_installed linux-oem-24.04; then
        local lettered_oem
        lettered_oem=$(dpkg-query -W -f='${Package}\n' 'linux-image-oem-24.04*' 2>/dev/null | head -1) || lettered_oem=""
        if [[ -n "$lettered_oem" ]]; then
            warn "$lettered_oem installed without rolling meta-package" "use linux-oem-24.04 (the rolling meta) instead of lettered variants — lettered packages are transitional and may not track future kernel migrations. Ref: https://canonical-kernel-docs.readthedocs-hosted.com/latest/reference/oem-kernels/"
        fi
    fi

    # Stella OEM packages (Canonical's codename for HP hardware enablement)
    local stella_pkgs
    stella_pkgs=$(dpkg-query -W -f='${Package}\n' 'oem-stella*' 2>/dev/null) || stella_pkgs=""
    if [[ -n "$stella_pkgs" ]]; then
        info "Stella OEM packages (HP firmware/drivers from Canonical): $(echo "$stella_pkgs" | tr '\n' ' '). Ref: https://launchpad.net/ubuntu/noble/+source/oem-stella-sensei-meta"
    else
        warn "No Stella OEM packages found" "these provide HP-specific firmware (AMD NPU, Cirrus audio amp DSP). Run: ubuntu-drivers list-oem. Ref: https://launchpad.net/ubuntu/noble/+source/oem-stella-sensei-meta"
    fi
}

# ── Section 3: Kernel Parameters ─────────────────────────────────────────────
check_kernel_params() {
    section "Kernel Parameters"

    # amd_pstate=active — the single most impactful power fix
    local pstate_val
    pstate_val=$(kparam_value "amd_pstate") || pstate_val=""
    if [[ "$pstate_val" == "active" ]]; then
        ok "amd_pstate=active — reduces idle power from 10-15W to 7-11W (down to 3-4W with GPU extension). Ref: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525"
    else
        fail "amd_pstate=active not set" "Ubuntu defaults to 'guided' which keeps CPU at higher power states. Expected: idle 10-15W → 7-11W, fans much quieter. Ref: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525" \
            "sudo sed -i -E 's/amd_pstate=[^ \"]*//g; s/GRUB_CMDLINE_LINUX_DEFAULT=\"(.*)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\\1 amd_pstate=active\"/; s/\"  +/\"/; s/  +\"/\"/' /etc/default/grub && sudo update-grub"
    fi

    # pcie_aspm=off — prevents GUI freezes
    local aspm_val
    aspm_val=$(kparam_value "pcie_aspm") || aspm_val=""
    if [[ "$aspm_val" == "off" ]]; then
        ok "pcie_aspm=off — prevents PCIe ASPM GUI freeze regression. Ref: https://bugs.launchpad.net/ubuntu/+source/linux-oem-6.14/+bug/2115969"
        # Check for known side effect: Intel Ethernet (IGC) loss
        local igc_pci
        igc_pci=$(lspci -nn 2>/dev/null | grep "8086:5502") || igc_pci=""
        if [[ -z "$igc_pci" ]]; then
            local eth_iface
            eth_iface=$(ip -br link 2>/dev/null | grep -E "^(eth|enp)" | head -1) || eth_iface=""
            if [[ -z "$eth_iface" ]]; then
                info "Intel Ethernet (IGC, 8086:5502) not detected — known side effect of pcie_aspm=off on this hardware. Ref: https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Using-the-webcam-on-zbook-ultra-g1a-Linux-ubuntu-25-04/td-p/9375051"
            fi
        fi
    else
        fail "pcie_aspm=off not set" "PCIe ASPM regression causes GUI freezes on OEM kernels after 6.14.0-1004-oem (PCIe power state transitions involving MT7925 WiFi). Mouse moves but desktop unresponsive within 1-2 min. Ref: https://bugs.launchpad.net/ubuntu/+source/linux-oem-6.14/+bug/2115969" \
            "sudo sed -i -E 's/pcie_aspm=[^ \"]*//g; s/GRUB_CMDLINE_LINUX_DEFAULT=\"(.*)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\\1 pcie_aspm=off\"/; s/\"  +/\"/; s/  +\"/\"/' /etc/default/grub && sudo update-grub"
    fi

    # amd_iommu=off — fixes suspend but disables NPU
    local iommu_val
    iommu_val=$(kparam_value "amd_iommu") || iommu_val=""
    if [[ "$iommu_val" == "off" ]]; then
        ok "amd_iommu=off — enables reliable s2idle (0.14-0.20W lid-closed). Trade-off: disables NPU. Ref: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525"
    elif kparam_present "iommu" && [[ "$(kparam_value "iommu")" == "pt" ]]; then
        info "iommu=pt set — this is for ROCm/VM passthrough, NOT a suspend fix (no Strix Halo user has confirmed it fixes suspend). For reliable suspend, use amd_iommu=off. Ref: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525"
    else
        warn "amd_iommu=off not set" "suspend may fail without it (10-15% battery drain overnight). Trade-off: disables NPU. For ROCm/VM passthrough use iommu=pt; for reliable suspend use amd_iommu=off (confirmed fix). Fix: sudo sed -i -E 's/amd_iommu=[^ \"]*//g; s/GRUB_CMDLINE_LINUX_DEFAULT=\"(.*)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\\1 amd_iommu=off\"/; s/\"  +/\"/; s/  +\"/\"/' /etc/default/grub && sudo update-grub. Ref: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525"
    fi

    # Retracted parameter check
    if kparam_present "pcie_aspm.policy"; then
        warn "pcie_aspm.policy found in cmdline" "this was retracted as ineffective — freezing still occurs during power transitions. Fix: remove pcie_aspm.policy from /etc/default/grub and use pcie_aspm=off instead. Ref: https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Using-the-webcam-on-zbook-ultra-g1a-Linux-ubuntu-25-04/td-p/9375051"
    fi

    # GRUB consistency
    local grub_mismatch=false
    for expected in "amd_pstate=active" "pcie_aspm=off"; do
        local param_name="${expected%%=*}"
        local param_set=false
        kparam_present "$param_name" && param_set=true

        if $param_set && ! grub_has_param "$expected"; then
            grub_mismatch=true
        fi
    done
    if $grub_mismatch; then
        warn "GRUB defaults don't match running cmdline" "parameters were likely set via boot menu but not persisted in /etc/default/grub. They will be lost on next reboot. Fix: edit /etc/default/grub GRUB_CMDLINE_LINUX_DEFAULT to include: amd_pstate=active pcie_aspm=off, then run: sudo update-grub. Ref: https://canonical-kernel-docs.readthedocs-hosted.com/latest/reference/oem-kernels/"
    else
        ok "GRUB defaults consistent with running cmdline — parameters will persist across reboots"
    fi

    # ROCm-conditional checks (GPU compute / AI workloads)
    local has_rocm=false
    if cmd_exists rocminfo || [[ -d /opt/rocm ]]; then
        has_rocm=true
    fi

    if $has_rocm; then
        # amdgpu.cwsr_enable=0 — workaround for MES firmware GPU hangs
        local cwsr_val
        cwsr_val=$(kparam_value "amdgpu.cwsr_enable") || cwsr_val=""
        if [[ "$cwsr_val" == "0" ]]; then
            ok "amdgpu.cwsr_enable=0 — prevents GPU hangs during ROCm compute. Ref: https://github.com/ROCm/ROCm/issues/5590"
        else
            warn "amdgpu.cwsr_enable=0 not set" "MES firmware CWSR (Compute Wave Save/Restore) hang regression. Only affects ROCm compute workloads — no impact on display or 3D rendering. Fix: sudo sed -i -E 's/GRUB_CMDLINE_LINUX_DEFAULT=\"(.*)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\\1 amdgpu.cwsr_enable=0\"/' /etc/default/grub && sudo update-grub. Ref: https://github.com/ROCm/ROCm/issues/5590"
        fi

        # ttm.pages_limit (only needed on kernel < 6.18.4)
        local kver_major kver_minor kver_patch
        kver_major=$(uname -r | cut -d. -f1)
        kver_minor=$(uname -r | cut -d. -f2)
        kver_patch=$(uname -r | cut -d. -f3 | cut -d- -f1)
        local needs_ttm=false
        if [[ "$kver_major" =~ ^[0-9]+$ ]] && [[ "$kver_minor" =~ ^[0-9]+$ ]] && [[ "$kver_patch" =~ ^[0-9]+$ ]]; then
            if [[ "$kver_major" -lt 6 ]]; then
                needs_ttm=true
            elif [[ "$kver_major" -eq 6 && "$kver_minor" -lt 18 ]]; then
                needs_ttm=true
            elif [[ "$kver_major" -eq 6 && "$kver_minor" -eq 18 && "$kver_patch" -lt 4 ]]; then
                needs_ttm=true
            fi
        fi

        if $needs_ttm; then
            local ttm_val
            ttm_val=$(kparam_value "ttm.pages_limit") || ttm_val=""
            if [[ -n "$ttm_val" ]]; then
                ok "ttm.pages_limit=$ttm_val — ROCm can access full unified memory. Ref: https://rocm.docs.amd.com/en/latest/how-to/system-optimization/strixhalo.html"
            else
                local ram_gb_total
                ram_gb_total=$(awk '/MemTotal/{printf "%d", $2/1048576}' /proc/meminfo 2>/dev/null) || ram_gb_total=0
                warn "ttm.pages_limit not set" "on kernel <6.18.4, ROCm sees only ~15.5GB of ${ram_gb_total}GB unified memory. Calculate: (desired_GiB * 1024 * 256). For ${ram_gb_total}GB system, use ~$(( (ram_gb_total - 4) * 1024 * 256 )). If using amdgpu-dkms, the module is named amdttm — use amdttm.pages_limit instead (check: lsmod | grep -E '^(ttm|amdttm)'). Note: amdgpu.gttsize is deprecated. Ref: https://rocm.docs.amd.com/en/latest/how-to/system-optimization/strixhalo.html https://github.com/ROCm/ROCm/issues/5562"
            fi
        else
            info "Kernel $(uname -r) >= 6.18.4: unified memory auto-managed. Ref: https://rocm.docs.amd.com/en/latest/how-to/system-optimization/strixhalo.html"
        fi
        # Check for deprecated amdgpu.gttsize
        if kparam_present "amdgpu.gttsize"; then
            warn "amdgpu.gttsize is deprecated" "use ttm.pages_limit instead. Kernel prints: 'Configuring gttsize via module parameter is deprecated'. Ref: https://rocm.docs.amd.com/en/latest/how-to/system-optimization/strixhalo.html"
        fi
    else
        skip "ROCm kernel parameter checks" "ROCm not installed (/opt/rocm not found, rocminfo not in PATH)"
    fi

    # PSR + Panel Replay check (X11 only — causes GUI freezes, especially with external displays)
    local session_type="${XDG_SESSION_TYPE:-}"
    if [[ "$session_type" == "x11" ]]; then
        local dc_val
        dc_val=$(kparam_value "amdgpu.dcdebugmask") || dc_val=""
        if [[ -n "$dc_val" ]]; then
            ok "amdgpu.dcdebugmask=$dc_val — PSR/Panel Replay control active for X11 stability"
        else
            warn "amdgpu.dcdebugmask not set (X11 session)" \
                "PSR + Panel Replay enabled — known cause of GUI freezes on X11 with external displays (desktop unresponsive, mouse moves). Try amdgpu.dcdebugmask=0x10 first (DC_DISABLE_PSR — disables PSR v1+SU, keeps Panel Replay, lower battery impact). If freezes persist, escalate to 0x410 (also disables Panel Replay). Trade-off: ~0.5W higher idle (Intel measurement; no AMD data) plus IPS cannot activate (depends on PSR). Ref: https://wiki.archlinux.org/title/AMDGPU"
        fi
    fi
}

# ── Section 4: Power Management ──────────────────────────────────────────────
check_power() {
    section "Power Management"

    # amd_pstate driver status (confirms the kernel param took effect)
    local pstate_status
    pstate_status=$(cat /sys/devices/system/cpu/amd_pstate/status 2>/dev/null) || pstate_status=""
    if [[ "$pstate_status" == "active" ]]; then
        ok "amd_pstate driver: active — hardware manages CPU frequency for lowest idle power"
    elif [[ -n "$pstate_status" ]]; then
        fail "amd_pstate driver: $pstate_status" "should be 'active'. Mode '$pstate_status' keeps CPU at higher power. Expected: 3-8W less idle power. Fix: add amd_pstate=active to GRUB params. Ref: https://docs.kernel.org/admin-guide/pm/amd-pstate.html"
    else
        warn "amd_pstate status not readable" "/sys/devices/system/cpu/amd_pstate/status missing — driver may not be loaded. Ref: https://docs.kernel.org/admin-guide/pm/amd-pstate.html"
    fi

    # PPD (power-profiles-daemon) — recommended by Framework for AMD
    if svc_active power-profiles-daemon; then
        ok "power-profiles-daemon running — integrates with ZBook's ACPI platform_profile. Low-power profile: ~32W avg (76% perf at 67% power). Ref: https://www.phoronix.com/review/amd-strix-halo-platform-profile"
    else
        warn "power-profiles-daemon not running" "PPD v0.20+ controls both platform_profile and amd_pstate. Recommended over TLP for AMD. Fix: sudo apt install power-profiles-daemon && sudo systemctl enable --now power-profiles-daemon. Ref: https://community.frame.work/t/tracking-ppd-v-tlp-for-amd-ryzen-7040/39423"
    fi

    # TLP conflict
    if svc_active tlp; then
        warn "TLP is active" "conflicts with power-profiles-daemon. Running both causes erratic frequency scaling. Fix: sudo systemctl disable --now tlp. Ref: https://community.frame.work/t/tracking-ppd-v-tlp-for-amd-ryzen-7040/39423"
    else
        ok "TLP not active — no conflict with PPD"
    fi

    # auto-cpufreq conflict
    if svc_active auto-cpufreq; then
        warn "auto-cpufreq is active" "conflicts with PPD — do not run more than one power manager simultaneously. Fix: sudo systemctl disable --now auto-cpufreq. Ref: https://community.frame.work/t/tracking-ppd-v-tlp-for-amd-ryzen-7040/39423"
    else
        ok "auto-cpufreq not active — no conflict"
    fi

    # Current profile
    if cmd_exists powerprofilesctl; then
        local profile
        profile=$(powerprofilesctl get 2>/dev/null) || profile=""
        if [[ -n "$profile" ]]; then
            info "Current power profile: $profile (change: powerprofilesctl set balanced|performance|power-saver)"
        fi
    fi

    # iGPU low-power mode (cool-ryzen-apply, GNOME extension, or manual)
    local gpu_perf_level=""
    gpu_perf_level=$(cat /sys/class/drm/card0/device/power_dpm_force_performance_level 2>/dev/null ||
                     cat /sys/class/drm/card1/device/power_dpm_force_performance_level 2>/dev/null) || gpu_perf_level=""
    if [[ "$gpu_perf_level" == "low" ]]; then
        ok "iGPU forced to low-power mode — drops idle from 7-11W to 3-4W"
    elif [[ "$gpu_perf_level" == "auto" || "$gpu_perf_level" == "high" ]]; then
        # Check for cool-ryzen-apply (i3/CLI) or GNOME extension
        local found_tooling=false
        if [[ -x /usr/local/bin/cool-ryzen-apply ]] && [[ -f /etc/udev/rules.d/85-cool-ryzen-ac.rules ]]; then
            ok "cool-ryzen-apply installed with AC/battery udev rule — toggles automatically (or \$mod+p). DPM currently: $gpu_perf_level"
            found_tooling=true
        fi
        if ! $found_tooling; then
            local ext_dir="${HOME}/.local/share/gnome-shell/extensions"
            for d in "$ext_dir"/cool*ryzen* "$ext_dir"/cool*amd* "$ext_dir"/*ryzen*ai*max*; do
                if [[ -d "$d" ]]; then
                    ok "Cool My Ryzen AI Max GNOME extension installed"
                    found_tooling=true
                    break
                fi
            done
        fi
        if ! $found_tooling; then
            info "iGPU power: $gpu_perf_level — to drop idle from 7-11W to 3-4W, run install.sh (deploys cool-ryzen-apply + udev auto-switch) or: echo low | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level. Ref: https://github.com/AnnoyingTechnology/gnome-extension-cool-my-ryzen-ai-max"
        fi
    fi
}

# ── Section 5: Suspend, Sleep & NPU ──────────────────────────────────────────
check_suspend() {
    section "Suspend, Sleep & NPU"

    # Sleep mode (S3 not available — HP removed it from BIOS)
    local mem_sleep
    mem_sleep=$(cat /sys/power/mem_sleep 2>/dev/null) || mem_sleep=""
    info "Sleep mode: $mem_sleep — S3 (deep sleep) does not exist on this hardware, only s2idle. Ref: https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/S3-sleep-option-missing-in-HP-ZBook-Ultra-Z1a/td-p/9420909"

    # WiFi suspend services (MT7925 driver timeout -110 after suspend)
    if svc_enabled wifi-pre-suspend.service; then
        ok "wifi-pre-suspend.service enabled — unloads mt7925e before suspend. Ref: https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2141198"
    else
        fail "wifi-pre-suspend.service not enabled" "MT7925 WiFi dies after suspend (driver timeout -110 error). This service unloads the module before sleep. Ref: https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2141198" \
            "sudo tee /etc/systemd/system/wifi-pre-suspend.service << 'SVCEOF'
[Unit]
Description=Unload MT7925 WiFi before suspend
Before=sleep.target
[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe -r mt7925e
[Install]
WantedBy=sleep.target
SVCEOF
sudo systemctl enable wifi-pre-suspend.service"
    fi

    if svc_enabled wifi-suspend-fix.service; then
        ok "wifi-suspend-fix.service enabled — reloads mt7925e after wake. Ref: https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2141198"
    else
        fail "wifi-suspend-fix.service not enabled" "WiFi won't reconnect after suspend without reloading the driver module. Ref: https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2141198" \
            "sudo tee /etc/systemd/system/wifi-suspend-fix.service << 'SVCEOF'
[Unit]
Description=Reload MT7925 WiFi after suspend
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe mt7925e
[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
SVCEOF
sudo systemctl enable wifi-suspend-fix.service"
    fi

    # IOMMU status (sysfs, no root needed)
    local iommu_groups
    iommu_groups=$(ls /sys/kernel/iommu_groups/ 2>/dev/null) || iommu_groups=""
    if [[ -z "$iommu_groups" ]]; then
        ok "IOMMU inactive — best for reliable s2idle suspend"
    else
        info "IOMMU active — NPU may work, but s2idle suspend may be unreliable. Ref: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525"
    fi

    # NPU checks (AMD XDNA 2 — 50 TOPS, but userspace not ready)
    local npu_loaded=false
    if lsmod 2>/dev/null | grep -q amdxdna; then
        npu_loaded=true
        local kver
        kver=$(uname -r)
        if [[ "$kver" == 6.18.* ]]; then
            warn "NPU driver (amdxdna) loaded on kernel $kver" "amdxdna does NOT work on kernels 6.18–6.18.7 due to IOMMU/SVA regression. Ref: https://www.phoronix.com/news/Linux-Dropping-AMD-NPU2"
        else
            info "NPU driver (amdxdna) loaded — kernel driver exists since 6.14 but userspace stack is fragmented. Ref: https://docs.kernel.org/accel/amdxdna/amdnpu.html"
        fi
    else
        info "NPU driver (amdxdna) not loaded — the 50 TOPS NPU is essentially unusable on Linux today. Use ROCm on the iGPU instead."
    fi

    if [[ -c /dev/accel/accel0 ]]; then
        info "NPU device /dev/accel/accel0 available"
    fi

    # NPU + IOMMU tradeoff explanation
    local iommu_off=false
    local iommu_val
    iommu_val=$(kparam_value "amd_iommu") || iommu_val=""
    [[ "$iommu_val" == "off" ]] && iommu_off=true

    if $iommu_off; then
        info "NPU disabled (amd_iommu=off) — recommended tradeoff for reliable suspend. Ref: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525"
    elif $npu_loaded && [[ -n "$iommu_groups" ]]; then
        info "NPU available (IOMMU active) — suspend may be unreliable. If suspend fails, add amd_iommu=off (disables NPU)."
    fi

    # Webcam / ISP4 (blocks GPU s2idle power-down)
    if lsmod 2>/dev/null | grep -q amd_isp; then
        info "AMD ISP4 webcam driver loaded — ISP firmware blocks SMU GPU power-down during s2idle. Expected: ~10-15% overnight drain. Ref: https://bugzilla.kernel.org/show_bug.cgi?id=220702"
    else
        info "AMD ISP4 webcam driver not loaded — optimal sleep power (0.14-0.20W, ~15 days standby on 74.5Wh). Ref: https://github.com/geohot/ztop"
    fi

    # Webcam + sleep summary
    local webcam_loaded=false
    lsmod 2>/dev/null | grep -q amd_isp && webcam_loaded=true
    if $webcam_loaded && $iommu_off; then
        info "Mode: Webcam ON + IOMMU OFF — webcam works, suspend works but with higher drain"
    elif ! $webcam_loaded && $iommu_off; then
        info "Mode: Webcam OFF + IOMMU OFF — optimal sleep (0.14-0.20W). Disable webcam in BIOS for this."
    elif $webcam_loaded && ! $iommu_off; then
        info "Mode: Webcam ON + IOMMU ON — webcam + NPU work, suspend may fail"
    fi

    # Screen blank after wake (amdgpu VRAM eviction bug)
    local gpu_recovery_val
    gpu_recovery_val=$(kparam_value "amdgpu.gpu_recovery") || gpu_recovery_val=""
    if [[ "$gpu_recovery_val" == "0" ]]; then
        warn "amdgpu.gpu_recovery=0 (disabled)" "GPU reset recovery is disabled — if screen goes blank after wake, recovery via Ctrl+Alt+F2/F7 may not work. Fix: remove amdgpu.gpu_recovery=0 from /etc/default/grub (default -1 auto-enables for GFX8+). Ref: https://docs.kernel.org/gpu/amdgpu/module-parameters.html"
    else
        info "Screen blank after wake: if display is black but system is alive (SSH works), press Ctrl+Alt+F2 then Ctrl+Alt+F7 to force GPU to reinitialize display"
    fi

    # Suspend-then-hibernate misconfiguration
    if [[ -r /etc/systemd/sleep.conf ]]; then
        if grep -qE '^\s*AllowSuspendThenHibernate\s*=\s*yes' /etc/systemd/sleep.conf 2>/dev/null; then
            local sb_on=false
            if cmd_exists mokutil; then
                local sb_check
                sb_check=$(mokutil --sb-state 2>/dev/null) || sb_check=""
                [[ "$sb_check" == *"SecureBoot enabled"* ]] && sb_on=true
            fi
            if $sb_on; then
                warn "AllowSuspendThenHibernate=yes in sleep.conf" "this cannot work — Secure Boot enables kernel lockdown which disables hibernate. Suspend-then-hibernate will fail silently. Fix: set AllowSuspendThenHibernate=no in /etc/systemd/sleep.conf. Ref: https://man7.org/linux/man-pages/man7/kernel_lockdown.7.html"
            fi
        fi
    fi

    # Hibernate status (conflicts with Secure Boot on this hardware)
    local disk_state
    disk_state=$(cat /sys/power/disk 2>/dev/null) || disk_state=""
    if [[ "$disk_state" == *"[disabled]"* ]]; then
        info "Hibernate: disabled by kernel lockdown (Secure Boot). This is expected — Secure Boot must stay enabled for suspend. Ref: https://man7.org/linux/man-pages/man7/kernel_lockdown.7.html"
    elif [[ -n "$disk_state" ]]; then
        info "Hibernate state: $disk_state"
    fi

    # Kernel lockdown
    local lockdown
    lockdown=$(cat /sys/kernel/security/lockdown 2>/dev/null) || lockdown=""
    if [[ -n "$lockdown" ]]; then
        info "Kernel lockdown: $lockdown"
    fi
}

# ── Section 6: Security — Boot & TPM ─────────────────────────────────────────
check_security() {
    section "Security — Boot & TPM"

    # UEFI
    if [[ -d /sys/firmware/efi ]]; then
        ok "UEFI boot mode — required for Secure Boot"
    else
        fail "Legacy BIOS boot" "UEFI required for Secure Boot and proper suspend on this hardware. Ref: https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface"
    fi

    # Secure Boot (disabling breaks suspend on this laptop)
    if cmd_exists mokutil; then
        local sb_state
        sb_state=$(mokutil --sb-state 2>/dev/null) || sb_state=""
        if [[ "$sb_state" == *"SecureBoot enabled"* ]]; then
            ok "Secure Boot enabled — required for suspend. Disabling breaks s2idle on this hardware. Ref: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525"
        elif [[ "$sb_state" == *"SecureBoot disabled"* ]]; then
            fail "Secure Boot disabled" "must be enabled — disabling breaks s2idle suspend on this hardware. Fix: F10 > Security > Secure Boot Configuration > enable. Ref: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525"
        else
            warn "Secure Boot state unknown" "mokutil returned: ${sb_state:-empty}. Try: sudo apt install mokutil. Ref: https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot"
        fi
    else
        skip "Secure Boot check" "mokutil not installed (sudo apt install mokutil)"
    fi

    # TPM 2.0 (Microsoft Pluton via CRB interface)
    local tpm_ver
    tpm_ver=$(cat /sys/class/tpm/tpm0/tpm_version_major 2>/dev/null) || tpm_ver=""
    if [[ "$tpm_ver" == "2" ]]; then
        ok "TPM 2.0 present — provides Clevis/systemd-cryptenroll auto-unlock and platform integrity"
    elif [[ -n "$tpm_ver" ]]; then
        warn "TPM version $tpm_ver" "expected 2.0 for full Clevis/systemd-cryptenroll support. Ref: https://www.phoronix.com/news/Pluton-TPM-CRB-Merged-Linux-6.3"
    else
        fail "TPM not detected" "expected TPM 2.0 (Microsoft Pluton via tpm_crb). Fix: enable Pluton in BIOS (F10 > Security > TPM). Ref: https://www.phoronix.com/news/Pluton-TPM-CRB-Merged-Linux-6.3"
    fi

    # TPM interface (CRB = Pluton, TIS = discrete)
    if lsmod 2>/dev/null | grep -q tpm_crb; then
        info "TPM interface: CRB (Microsoft Pluton) — supported since Linux 6.3. Ref: https://www.phoronix.com/news/Pluton-TPM-CRB-Merged-Linux-6.3"
    elif lsmod 2>/dev/null | grep -q tpm_tis; then
        info "TPM interface: TIS (discrete TPM, not Pluton)"
    fi

    # CPU microcode revision (important for CVE-2025-29943/StackWarp, AMD-SB-7055/RDSEED)
    local ucode_rev
    ucode_rev=$(grep -m1 "microcode" /proc/cpuinfo 2>/dev/null | awk -F': ' '{print $2}') || ucode_rev=""
    if [[ -n "$ucode_rev" ]]; then
        info "CPU microcode revision: $ucode_rev — verify this includes fixes for CVE-2025-29943 (StackWarp) and AMD-SB-7055 (RDSEED). Run 'sudo fwupdmgr update' to get latest. Ref: https://www.amd.com/en/resources/product-security.html"
    fi

    # SME/TSME (Transparent Secure Memory Encryption — encrypts all RAM)
    if has_root; then
        local sme_status=""
        sme_status=$(dmesg 2>/dev/null | grep -i "Memory Encryption" | head -1) || true
        if [[ -z "$sme_status" ]]; then
            sme_status=$(journalctl -k --no-pager -q 2>/dev/null | grep -i "Memory Encryption" | head -1) || true
        fi
        if [[ "$sme_status" == *"active"* ]]; then
            ok "Memory Encryption active: ${sme_status##*Features } — Zen 5 uses 256-bit AES-XTS, ~0.7% performance cost. Ref: https://www.phoronix.com/review/amd-memory-guard-ram-encrypt"
        elif [[ -n "$sme_status" ]]; then
            warn "Memory Encryption status" "$sme_status"
        else
            if grep -q sme /proc/cpuinfo 2>/dev/null; then
                warn "CPU supports SME but activation not confirmed in dmesg" "TSME must be enabled in BIOS (RAM Encryption) — required for suspend. Ref: https://docs.kernel.org/arch/x86/amd-memory-encryption.html"
            else
                warn "SME/TSME status unknown" "check BIOS: RAM Encryption (TSME) must be enabled for suspend. Ref: https://docs.kernel.org/arch/x86/amd-memory-encryption.html"
            fi
        fi
    else
        if grep -q sme /proc/cpuinfo 2>/dev/null; then
            info "CPU supports SME (activation check requires root). Ref: https://docs.kernel.org/arch/x86/amd-memory-encryption.html"
        else
            skip "SME/TSME check" "requires root"
        fi
    fi

    # EFI boot entry (HP BIOS quirk: doesn't always auto-detect GRUB)
    if has_root && cmd_exists efibootmgr; then
        local efi_entries
        efi_entries=$(efibootmgr 2>/dev/null | grep -i ubuntu) || efi_entries=""
        if [[ -n "$efi_entries" ]]; then
            ok "Ubuntu EFI boot entry present"
        else
            warn "No Ubuntu EFI boot entry" "HP BIOS may not auto-detect GRUB. Fix: F10 → Advanced → Boot Options → Add → EFI\\ubuntu\\shimx64.efi. Ref: https://forums.linuxmint.com/viewtopic.php?t=432222"
        fi
    elif ! has_root; then
        skip "EFI boot entry check" "requires root"
    fi

    # Shim bootloader (Secure Boot chain)
    if [[ -f /boot/efi/EFI/ubuntu/shimx64.efi ]]; then
        ok "Shim bootloader present — signs GRUB for Secure Boot chain"
    else
        warn "shimx64.efi not found" "Secure Boot chain may be incomplete. Fix: sudo apt install --reinstall shim-signed. Ref: https://forum.level1techs.com/t/the-ultimate-arch-secureboot-guide-for-ryzen-ai-max-ft-hp-g1a-128gb-8060s-monster-laptop/230652"
    fi

    # GRUB
    if [[ -f /boot/efi/EFI/ubuntu/grubx64.efi ]]; then
        ok "GRUB bootloader present"
    else
        warn "grubx64.efi not found at /boot/efi/EFI/ubuntu/" "Fix: sudo apt install --reinstall grub-efi-amd64-signed && sudo update-grub. Ref: https://wiki.archlinux.org/title/GRUB"
    fi

    # EFI partition size
    local efi_size_kb
    efi_size_kb=$(df /boot/efi 2>/dev/null | awk 'NR==2{print $2}') || efi_size_kb=0
    local efi_size_mb=$((efi_size_kb / 1024))
    if [[ $efi_size_mb -ge 450 ]]; then
        ok "EFI partition size: ${efi_size_mb}MB (standard 512MB VFAT recommended)"
    elif [[ $efi_size_mb -gt 0 ]]; then
        warn "EFI partition small: ${efi_size_mb}MB" "recommended >= 512MB for multiple kernel/bootloader entries. Ref: https://wiki.archlinux.org/title/EFI_system_partition"
    fi

    # EFI filesystem
    local efi_fs
    efi_fs=$(findmnt -n -o FSTYPE /boot/efi 2>/dev/null) || efi_fs=""
    if [[ "$efi_fs" == "vfat" ]]; then
        ok "EFI partition is FAT32 (vfat)"
    elif [[ -n "$efi_fs" ]]; then
        fail "EFI partition is $efi_fs" "must be vfat (FAT32) per UEFI specification. Ref: https://wiki.archlinux.org/title/EFI_system_partition"
    fi

    # kexec_load_disabled (prevents bypassing Secure Boot at runtime)
    local kexec_disabled
    kexec_disabled=$(cat /proc/sys/kernel/kexec_load_disabled 2>/dev/null) || kexec_disabled=""
    if [[ "$kexec_disabled" == "1" ]]; then
        ok "kexec disabled — cannot bypass Secure Boot at runtime"
    elif [[ "$kexec_disabled" == "0" ]]; then
        fail "kexec enabled" "allows loading unsigned kernels at runtime, bypassing Secure Boot" \
            "echo 'kernel.kexec_load_disabled = 1' | sudo tee /etc/sysctl.d/10-kernel-hardening.conf && sudo sysctl -p /etc/sysctl.d/10-kernel-hardening.conf"
    fi
}

# ── Section 7: Full Disk Encryption ──────────────────────────────────────────
check_fde() {
    section "Full Disk Encryption"

    if ! has_root; then
        skip "Full Disk Encryption checks" "requires root"
        return
    fi

    # Find root device and check if LUKS-backed
    local root_source luks_device=""
    root_source=$(findmnt -n -o SOURCE / 2>/dev/null) || root_source=""

    if [[ "$root_source" == /dev/mapper/* ]]; then
        local mapper_name="${root_source#/dev/mapper/}"
        local crypt_status
        crypt_status=$(cryptsetup status "$mapper_name" 2>/dev/null) || crypt_status=""
        if [[ "$crypt_status" == *"active"* ]]; then
            local backing_dev
            backing_dev=$(echo "$crypt_status" | grep "device:" | awk '{print $2}') || backing_dev=""
            if [[ -n "$backing_dev" ]]; then
                luks_device="$backing_dev"
            fi
        fi
    fi

    if [[ -z "$luks_device" ]]; then
        if lsblk -rf 2>/dev/null | grep -q crypto_LUKS; then
            luks_device=$(lsblk -rn -o NAME,FSTYPE 2>/dev/null | grep crypto_LUKS | head -1 | awk '{print "/dev/"$1}')
        fi
    fi

    if [[ -z "$luks_device" ]]; then
        warn "Root is not LUKS encrypted" "FDE not configured. Protects against physical disk theft. Ref: https://documentation.ubuntu.com/security/security-features/storage/encryption-full-disk/"
        return
    fi

    ok "Root is LUKS encrypted (device: ${luks_device##*/})"

    # LUKS metadata — allowlist grep only (never prints UUID, salt, digest, or key material)
    local luks_dump
    luks_dump=$(cryptsetup luksDump "$luks_device" 2>/dev/null) || luks_dump=""

    if [[ -z "$luks_dump" ]]; then
        warn "Could not read LUKS header" "cryptsetup luksDump failed"
        return
    fi

    # LUKS version
    local luks_ver
    luks_ver=$(echo "$luks_dump" | grep -m1 "^Version:" | awk '{print $2}') || luks_ver=""
    if [[ "$luks_ver" == "2" ]]; then
        ok "LUKS version 2 — supports argon2id, larger headers, token management"
    elif [[ -n "$luks_ver" ]]; then
        warn "LUKS version $luks_ver" "LUKS2 recommended for argon2id PBKDF and modern features. Ref: https://wiki.archlinux.org/title/Dm-crypt/Device_encryption"
    fi

    # Cipher — extracted via allowlist
    local cipher
    cipher=$(echo "$luks_dump" | grep -m1 -E "^\s+cipher:" | sed 's/.*cipher:\s*//') || cipher=""
    if [[ "$cipher" == "aes-xts-plain64" ]]; then
        ok "Cipher: aes-xts-plain64 — hardware-accelerated via AES-NI on Zen 5 (est. >10 GB/s, far exceeds NVMe bandwidth)"
    elif [[ -n "$cipher" ]]; then
        warn "Cipher: $cipher" "aes-xts-plain64 recommended — hardware-accelerated via AMD AES-NI. Ref: https://www.phoronix.com/news/3.3x-AES-CTR-AMD-Zen-5-Patches"
    fi

    # Key size — extracted via allowlist
    local keysize
    keysize=$(echo "$luks_dump" | grep -m1 -E "^\s+Key:" | grep -oP '\d+') || keysize=""
    if [[ "$keysize" == "512" ]]; then
        ok "Key size: 512 bits (AES-256-XTS) — maximum strength for AES-XTS"
    elif [[ -n "$keysize" ]]; then
        warn "Key size: ${keysize} bits" "512 bits (AES-256-XTS) recommended for maximum security. Ref: https://wiki.archlinux.org/title/Dm-crypt/Device_encryption"
    fi

    # Sector size
    local root_mapper="${root_source#/dev/mapper/}"
    local sector_size
    sector_size=$(cryptsetup status "$root_mapper" 2>/dev/null | grep "sector size:" | awk '{print $3}') || sector_size=""
    if [[ "$sector_size" == "4096" ]]; then
        ok "Sector size: 4096 — biggest single dm-crypt performance win. Ref: https://fedoraproject.org/wiki/Changes/LUKSEncryptionSectorSize"
    elif [[ -n "$sector_size" ]]; then
        warn "Sector size: $sector_size" "4096 is significantly faster (the #1 dm-crypt perf tweak). Cannot change without reformat. Ref: https://fedoraproject.org/wiki/Changes/LUKSEncryptionSectorSize"
    fi

    # PBKDF — extracted via allowlist
    local pbkdf
    pbkdf=$(echo "$luks_dump" | grep -m1 -E "^\s+PBKDF:" | sed 's/.*PBKDF:\s*//') || pbkdf=""
    if [[ "$pbkdf" == "argon2id" ]]; then
        ok "PBKDF: argon2id — memory-hard, resists GPU brute-force. Note: GRUB cannot unlock argon2id keyslots (keep /boot unencrypted)"
    elif [[ -n "$pbkdf" ]]; then
        warn "PBKDF: $pbkdf" "argon2id recommended (memory-hard, resists GPU attacks). Note: GRUB cannot unlock argon2id. Ref: https://wiki.archlinux.org/title/Dm-crypt/Device_encryption"
    fi

    # crypttab options
    if [[ -r /etc/crypttab ]]; then
        local crypttab
        crypttab=$(cat /etc/crypttab 2>/dev/null) || crypttab=""

        if echo "$crypttab" | grep -q "discard"; then
            ok "crypttab: discard (TRIM) enabled — allows NVMe TRIM through encryption layer. Note: leaks block usage patterns (not content) — acceptable for most threat models. Ref: https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)"
        else
            warn "crypttab: discard not set" "TRIM not passing through LUKS — minor NVMe performance/longevity impact. Fix: add 'discard' to options in /etc/crypttab, then run: sudo update-initramfs -u -k all. Ref: https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)"
        fi

        if echo "$crypttab" | grep -q "no-read-workqueue"; then
            ok "crypttab: no-read-workqueue — bypasses dm-crypt workqueue for lower latency. Ref: https://blog.cloudflare.com/speeding-up-linux-disk-encryption/"
        else
            info "crypttab: no-read-workqueue not set — optional, reduces dm-crypt overhead. Ref: https://blog.cloudflare.com/speeding-up-linux-disk-encryption/"
        fi

        if echo "$crypttab" | grep -q "no-write-workqueue"; then
            ok "crypttab: no-write-workqueue — bypasses dm-crypt workqueue for lower latency"
        else
            info "crypttab: no-write-workqueue not set — optional, reduces dm-crypt overhead"
        fi
    fi

    # LUKS keyslot count (recovery passphrase check)
    local keyslot_count
    keyslot_count=$(echo "$luks_dump" | grep -cE "^\s+[0-9]+: luks2") || keyslot_count=0
    if [[ "$keyslot_count" -le 1 ]] 2>/dev/null; then
        warn "Only $keyslot_count active LUKS keyslot(s)" "no recovery passphrase — if your primary passphrase is lost, ALL data is gone. Fix: sudo cryptsetup luksAddKey --key-slot 1 $luks_device. Ref: https://wiki.archlinux.org/title/Dm-crypt/Device_encryption"
    else
        ok "Multiple LUKS keyslots active ($keyslot_count) — recovery passphrase available"
    fi

    # Clevis TPM2 binding (recommended for auto-unlock on 24.04)
    if cmd_exists clevis; then
        local clevis_out
        clevis_out=$(clevis luks list -d "$luks_device" 2>/dev/null) || clevis_out=""
        if [[ "$clevis_out" == *"tpm2"* ]]; then
            ok "Clevis TPM2 auto-unlock configured — passphrase-free boot when boot chain is unmodified. Ref: https://github.com/latchset/clevis"
            # Check PCR selection — PCR 9 breaks on every kernel/initramfs update
            if [[ "$clevis_out" == *"pcr_ids"*"9"* ]]; then
                warn "Clevis TPM2 binding includes PCR 9" "PCR 9 measures initramfs — auto-unlock breaks on EVERY kernel or initramfs update (requires re-binding). Fix: sudo clevis luks unbind -d $luks_device -s <slot> && sudo clevis luks bind -d $luks_device tpm2 '{\"pcr_ids\":\"7\"}' && sudo update-initramfs -u -k all. Ref: https://wiki.archlinux.org/title/Clevis"
            fi
        else
            info "Clevis installed but no TPM2 binding — auto-unlock not configured. Ref: https://github.com/latchset/clevis"
        fi
    else
        info "Clevis not installed — TPM auto-unlock not available. Alternative: systemd-cryptenroll (built-in, faster, but requires dracut — not default on Ubuntu 24.04). Ref: https://www.freedesktop.org/software/systemd/man/systemd-cryptenroll.html"
    fi

    # LUKS header backup reminder (always)
    warn "LUKS header backup" "ensure you have a LUKS header backup stored off-device. If the LUKS header is corrupted, ALL data is permanently lost. Run: sudo cryptsetup luksHeaderBackup $luks_device --header-backup-file luks-header.img && gpg --symmetric --cipher-algo AES256 luks-header.img && shred -u luks-header.img. Ref: https://wiki.archlinux.org/title/Dm-crypt/Device_encryption"
}

# ── Section 8: WiFi ──────────────────────────────────────────────────────────
check_wifi() {
    section "WiFi (MT7925)"

    # PCI device (MediaTek MT7925 — vendor 14c3)
    local mt_pci
    mt_pci=$(lspci -nn 2>/dev/null | grep "14c3:7925") || mt_pci=""
    if [[ -n "$mt_pci" ]]; then
        ok "MT7925 WiFi adapter found — requires kernel 6.14.3+ and linux-firmware from May 2025+. Ref: https://wiki.gentoo.org/wiki/User:Owenwastaken/HP_ZBook_Ultra_G1a"
    else
        warn "MT7925 WiFi adapter not found" "expected PCI device 14c3:7925. Ref: https://wiki.gentoo.org/wiki/User:Owenwastaken/HP_ZBook_Ultra_G1a"
        return
    fi

    # Driver
    if lsmod 2>/dev/null | grep -q mt7925e; then
        ok "mt7925e driver loaded"
    else
        fail "mt7925e driver not loaded" "WiFi adapter present but driver missing — may need linux-firmware update. Ref: https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2118937" \
            "sudo modprobe mt7925e"
    fi

    # Interface
    local wl_iface
    wl_iface=$(ip -br link 2>/dev/null | grep -E "^wl" | head -1) || wl_iface=""
    if [[ -n "$wl_iface" ]]; then
        local iface_name
        iface_name=$(echo "$wl_iface" | awk '{print $1}')
        if echo "$wl_iface" | grep -q "UP"; then
            ok "WiFi interface $iface_name is UP"
        else
            info "WiFi interface $iface_name exists but is DOWN"
        fi
    else
        warn "No wireless interface found" "expected wl* interface. Check: lsmod | grep mt7925e. Ref: https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2118937"
    fi
}

# ── Section 9: Firmware & Updates ────────────────────────────────────────────
check_firmware() {
    section "Firmware & Updates"

    # fwupd (delivers BIOS + PD firmware from LVFS)
    if cmd_exists fwupdmgr; then
        ok "fwupd installed — enables BIOS and USB-C PD firmware updates from Linux. Ref: https://fwupd.org/"
    else
        fail "fwupd not installed" "needed for BIOS updates (security patches for CVE-2025-29943/StackWarp, AMD-SB-7055/RDSEED) and PD firmware (fixes USB-C charging issues). Ref: https://www.amd.com/en/resources/product-security.html" \
            "sudo apt install fwupd"
    fi

    # linux-firmware version (20251125 is broken for ROCm on Strix Halo)
    local fw_ver
    fw_ver=$(dpkg-query -W -f='${Version}' linux-firmware 2>/dev/null) || fw_ver=""
    if [[ -n "$fw_ver" ]]; then
        if [[ "$fw_ver" == *"20251125"* ]] && [[ "$fw_ver" != *"20251125-2"* ]]; then
            warn "linux-firmware $fw_ver" "version 20251125 is BROKEN for Strix Halo — MES firmware 0x83 causes GPU memory faults (GCVM_L2_PROTECTION_FAULT_STATUS:0x00800932, ROCm #5724). Can contribute to kernel panics. Upgrade to 20260110+. Run: sudo apt update && sudo apt upgrade linux-firmware. Ref: https://github.com/ROCm/ROCm/issues/5724"
        elif [[ "$fw_ver" == *"20251125-2"* ]]; then
            warn "linux-firmware $fw_ver" "version 20251125-2 is a partial fix for MES 0x83 regression — did not cover all GPUs. Upgrade to 20260110+ recommended. Run: sudo apt update && sudo apt upgrade linux-firmware. Ref: https://github.com/ROCm/ROCm/issues/5724"
        else
            ok "linux-firmware: $fw_ver"
        fi
    fi

    # Pending security updates
    local sec_count=0
    sec_count=$(apt-get -s dist-upgrade 2>/dev/null | grep -c "^Inst.*security") || sec_count=0
    if [[ "$sec_count" -eq 0 ]]; then
        ok "No pending security updates"
    else
        warn "$sec_count pending security update(s)" "includes potential fixes for CVE-2025-29943 (StackWarp), AMD-SB-7055 (RDSEED). Run: sudo apt update && sudo apt upgrade. Ref: https://www.amd.com/en/resources/product-security.html"
    fi

    # TI PD firmware version (fixes USB-C charging connect/disconnect bug)
    if cmd_exists fwupdmgr; then
        local pd_info
        pd_info=$(fwupdmgr get-devices 2>/dev/null | grep -A2 -i "TI.*PD\|USB.*PD\|Power Delivery" | head -5) || pd_info=""
        if [[ -n "$pd_info" ]]; then
            info "USB-C PD controller detected. TI PD firmware v6.9.0 (dual) / v5.9.0 (single) fixes third-party charger disconnect bug. Note: some charging instability may persist after firmware update due to PD 3.1 voltage-switching sensitivity. Ref: https://h30434.www3.hp.com/t5/Notebook-Hardware-and-Upgrade-Questions/hp-zbook-ultra-g1a-needs-more-stable-pd-3-1-charging/td-p/9465799"
        fi
    fi

    # Pending firmware updates (uses cached metadata — may prompt for refresh if stale)
    if cmd_exists fwupdmgr; then
        local fw_rc=0
        fwupdmgr get-updates --no-unreported-check --no-metadata-check &>/dev/null || fw_rc=$?
        if [[ $fw_rc -eq 2 ]]; then
            ok "No pending firmware updates (BIOS, PD controller up to date)"
        elif [[ $fw_rc -eq 0 ]]; then
            warn "Firmware updates available" "may include BIOS, USB-C PD firmware (TI PD v6.9.0 fixes charging issues). Run: sudo fwupdmgr update. Ref: https://h30434.www3.hp.com/t5/Notebook-Hardware-and-Upgrade-Questions/hp-zbook-ultra-g1a-needs-more-stable-pd-3-1-charging/td-p/9465799"
        else
            info "Could not check firmware updates (fwupdmgr exit code: $fw_rc — may need: sudo fwupdmgr refresh)"
        fi
    fi

    # rasdaemon — correct MCE monitoring tool for AMD Zen (mcelog is non-functional on AMD)
    if cmd_exists rasdaemon || systemctl is-active rasdaemon &>/dev/null; then
        ok "rasdaemon available — hardware error monitoring for AMD Zen. Ref: https://wiki.archlinux.org/title/Rasdaemon"
    else
        info "rasdaemon not installed — recommended for AMD Zen MCE/hardware error monitoring (mcelog is non-functional on AMD). Install: sudo apt install rasdaemon"
    fi
}

# ── Section 10: Peripherals ──────────────────────────────────────────────────
check_peripherals() {
    section "Peripherals"

    # Thunderbolt/USB4
    local tb
    tb=$(lspci 2>/dev/null | grep -iE "thunderbolt|usb4" | head -1) || tb=""
    if [[ -n "$tb" ]]; then
        info "Thunderbolt/USB4: $tb. Note: dock disconnection with >90W PD is a known bug. Workarounds: (1) route through <=60W TB hub [HP#9521854], (2) connect HP 140W charger first, then TB cable [HP#9488066]. Ref: https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Ultrabook-G1a-constantly-disconnecting-from-docks-any-docks/td-p/9521854"
    fi

    # Audio (Cirrus Logic amplifier for speakers)
    local audio
    audio=$(lspci 2>/dev/null | grep -i "cirrus\|audio" | head -2) || audio=""
    if [[ -n "$audio" ]]; then
        ok "Audio controller detected — note: quality is degraded vs Windows (Cirrus amp DSP firmware). HDA-Jack Retask tool may improve quality. Ref: https://wiki.gentoo.org/wiki/User:Owenwastaken/HP_ZBook_Ultra_G1a"
    else
        warn "Audio controller not detected" "expected Cirrus Logic amplifier. Ref: https://wiki.gentoo.org/wiki/User:Owenwastaken/HP_ZBook_Ultra_G1a"
    fi
    # Cirrus amp DSP firmware files (added to linux-firmware Sep 2024)
    if ! ls /lib/firmware/cirrus/cs35l54-b0-dsp1-misc-103c8d01-amp*.bin* &>/dev/null; then
        info "Cirrus amp DSP firmware not found in /lib/firmware/cirrus/ — speaker output may be suboptimal. Update linux-firmware: sudo apt update && sudo apt install linux-firmware"
    fi

    # Fingerprint (Synaptics, works via libfprint)
    if cmd_exists lsusb; then
        local fp
        fp=$(lsusb 2>/dev/null | grep -i fingerprint) || fp=""
        if [[ -n "$fp" ]]; then
            info "Fingerprint reader detected — enroll with: fprintd-enroll. Ref: https://launchpad.net/ubuntu/+source/libfprint/+bug/2058193"
        else
            info "Fingerprint reader not detected (may be disabled in BIOS)"
        fi
    fi

    # Bluetooth (MT7925 combo — known bug: firmware setup failure -110)
    if cmd_exists bluetoothctl; then
        local bt_powered
        bt_powered=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk '{print $2}') || bt_powered=""
        if [[ "$bt_powered" == "yes" ]]; then
            ok "Bluetooth powered on"
        elif [[ "$bt_powered" == "no" ]]; then
            info "Bluetooth detected but powered off"
        else
            if has_root && journalctl -b --no-pager -q 2>/dev/null | grep -qE "wmt.*(timed out|-110)"; then
                warn "Bluetooth firmware setup failure detected (MediaTek WMT timeout/-110)" "toggle BT in BIOS (disable → save → re-enable → save). Ref: https://wiki.gentoo.org/wiki/User:Owenwastaken/HP_ZBook_Ultra_G1a"
            else
                warn "Bluetooth status unknown" "if BT fails with firmware setup error -110: toggle in BIOS (disable → save → re-enable → save). Ref: https://wiki.gentoo.org/wiki/User:Owenwastaken/HP_ZBook_Ultra_G1a"
            fi
        fi
    fi

    # Keyboard backlight power draw (~2W — significant portion of idle power)
    local kbd_brightness=""
    for kbd_path in /sys/class/leds/*/brightness; do
        if [[ "$kbd_path" == *"kbd"* || "$kbd_path" == *"keyboard"* || "$kbd_path" == *"::kbd_backlight"* ]]; then
            kbd_brightness=$(cat "$kbd_path" 2>/dev/null) || kbd_brightness=""
            break
        fi
    done
    if [[ "$kbd_brightness" =~ ^[0-9]+$ ]] && [[ "$kbd_brightness" -gt 0 ]]; then
        info "Keyboard backlight on (brightness: $kbd_brightness) — draws ~2W (significant at 7W idle). Reduce on battery for power savings. Ref: https://geohot.github.io/blog/jekyll/update/2025/11/28/replacing-my-macbook.html"
    fi

    # Touchpad configuration (i3/X11 — GNOME handles this automatically)
    if [[ -f /etc/X11/xorg.conf.d/30-touchpad.conf ]]; then
        ok "Touchpad config exists (/etc/X11/xorg.conf.d/30-touchpad.conf)"
    else
        fail "Touchpad config missing" "tap-to-click, clickfinger, and drag lock are not configured for i3/X11" \
            "Create /etc/X11/xorg.conf.d/30-touchpad.conf — see Section 14 of the report, or re-run install.sh"
    fi

    if cmd_exists xinput; then
        local tp_name="SYNA3133:00 06CB:CFE2 Touchpad"
        local tp_props
        tp_props=$(xinput list-props "$tp_name" 2>/dev/null) || tp_props=""
        if [[ -n "$tp_props" ]]; then
            # Check tapping
            if echo "$tp_props" | grep -q "libinput Tapping Enabled (.*):.*1"; then
                ok "Touchpad tap-to-click enabled"
            else
                warn "Touchpad tap-to-click disabled" "enable with: xinput set-prop '$tp_name' 'libinput Tapping Enabled' 1 (or reboot after creating 30-touchpad.conf)"
            fi
            # Check click method (clickfinger = 0, 1)
            if echo "$tp_props" | grep -q "libinput Click Method Enabled (.*):.*0,.*1"; then
                ok "Touchpad click method: clickfinger"
            else
                warn "Touchpad click method: not clickfinger" "2-finger click won't right-click. Fix: add Option \"ClickMethod\" \"clickfinger\" to 30-touchpad.conf"
            fi
            # Check natural scrolling
            if echo "$tp_props" | grep -q "libinput Natural Scrolling Enabled (.*):.*1"; then
                info "Touchpad natural scrolling enabled (disable in 30-touchpad.conf if not desired)"
            else
                ok "Touchpad traditional scrolling (natural scrolling disabled)"
            fi
        else
            skip "Touchpad properties" "xinput could not read '$tp_name' (not on X11, or device name changed)"
        fi
    fi

    # Keyboard XKB options
    if cmd_exists setxkbmap; then
        local xkb_opts
        xkb_opts=$(setxkbmap -query 2>/dev/null | grep "options:" | sed 's/.*options:\s*//') || xkb_opts=""
        if [[ "$xkb_opts" == *"ctrl:nocaps"* ]]; then
            ok "XKB: Caps Lock as Ctrl (ctrl:nocaps)"
        else
            warn "XKB: Caps Lock is not mapped to Ctrl" "recommended for ZBook's awkward CTRL position. Fix: add ctrl:nocaps to XKBOPTIONS in /etc/default/keyboard"
        fi
        if [[ "$xkb_opts" == *"compose:ralt"* ]]; then
            ok "XKB: Right Alt as Compose (compose:ralt)"
        else
            info "XKB: compose:ralt not set (optional — enables accented character input)"
        fi
        if [[ "$xkb_opts" == *"terminate:ctrl_alt_bksp"* ]]; then
            ok "XKB: Ctrl+Alt+Backspace kills X (terminate:ctrl_alt_bksp)"
        else
            info "XKB: terminate:ctrl_alt_bksp not set (optional — emergency X11 kill)"
        fi
    fi

    # Trackpad gestures (fusuma)
    if cmd_exists fusuma; then
        if pgrep -f fusuma &>/dev/null; then
            ok "fusuma running (trackpad gestures active)"
        else
            warn "fusuma installed but not running" "start with: fusuma -d"
        fi
    else
        info "fusuma not installed (optional — enables trackpad gestures for i3). Install: sudo gem install fusuma"
    fi
    if ! id -nG "$USER" 2>/dev/null | grep -qw input; then
        warn "User not in 'input' group" "required for trackpad gestures. Fix: sudo gpasswd -a $USER input (then log out/in)"
    fi

    # NVMe TRIM (important for SSD longevity, especially with LUKS discard)
    local trim_gran
    trim_gran=$(lsblk -Drn 2>/dev/null | grep nvme | head -1 | awk '{print $3}') || trim_gran=""
    if [[ -n "$trim_gran" && "$trim_gran" != "0B" && "$trim_gran" != "0" ]]; then
        ok "NVMe TRIM supported (DISC-GRAN: $trim_gran) — ensure crypttab has 'discard' if using LUKS"
    elif [[ -n "$trim_gran" ]]; then
        info "NVMe TRIM granularity: $trim_gran"
    fi

    # Webcam (AMD ISP4) — requires libcamera with ISP4 pipeline handler
    if lsmod 2>/dev/null | grep -q amd_isp4; then
        if cmd_exists cam; then
            local cam_list
            cam_list=$(cam -l 2>/dev/null) || cam_list=""
            if [[ -n "$cam_list" ]] && [[ "$cam_list" != *"No cameras"* ]]; then
                ok "AMD ISP4 webcam detected via libcamera: $cam_list"
            else
                fail "AMD ISP4 module loaded but libcamera sees no camera" \
                    "install libcamera with ISP4 pipeline handler from ppa:amd-team/isp. Stock Noble libcamera 0.2.0 lacks the ISP4 handler." \
                    "sudo add-apt-repository -y ppa:amd-team/isp && sudo apt-get update && sudo apt-get install -y v4l-utils libcamera-tools libspa-0.2-libcamera gstreamer1.0-libcamera"
            fi
        else
            fail "libcamera-tools not installed" \
                "needed to verify ISP4 webcam. Install from ppa:amd-team/isp" \
                "sudo add-apt-repository -y ppa:amd-team/isp && sudo apt-get update && sudo apt-get install -y libcamera-tools"
        fi
    fi
}

# ── Section 11: Display & Desktop ────────────────────────────────────────────
check_display() {
    section "Display & Desktop"

    local session_type="${XDG_SESSION_TYPE:-}"
    if [[ -z "$session_type" ]]; then
        info "XDG_SESSION_TYPE not set — if using startx/xinit, add 'export XDG_SESSION_TYPE=x11' to ~/.xinitrc before 'exec i3'. Ref: https://wiki.archlinux.org/title/Xinit"
    fi

    if [[ "$session_type" == "wayland" ]]; then
        ok "Wayland session — recommended for Strix Halo (better amdgpu integration, fewer PSR bugs). Ref: https://www.phoronix.com/review/hp-zbook-ultra-g1a/2"
    elif [[ "$session_type" == "x11" ]]; then
        info "X11 session detected"

        # Detect WM (GNOME vs tiling WMs like i3/sway)
        local wm_name=""
        if [[ -n "${DESKTOP_SESSION:-}" ]]; then
            wm_name="$DESKTOP_SESSION"
        elif [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
            wm_name="$XDG_CURRENT_DESKTOP"
        fi

        # X11 tearing fix (critical for i3/non-compositing WMs)
        local tearfree_set=false
        if [[ -d /etc/X11/xorg.conf.d ]]; then
            if grep -rqs "TearFree" /etc/X11/xorg.conf.d/ 2>/dev/null; then
                tearfree_set=true
            fi
        fi
        if grep -qs "TearFree" /etc/X11/xorg.conf 2>/dev/null; then
            tearfree_set=true
        fi

        local has_picom=false
        cmd_exists picom && has_picom=true

        if $tearfree_set; then
            ok "amdgpu TearFree enabled in Xorg config — prevents tearing without a compositor"
        elif $has_picom; then
            ok "picom compositor available — use 'backend = \"glx\"; vsync = true;' for tear-free. Do NOT combine with TearFree. Ref: https://wiki.archlinux.org/title/Picom"
        else
            warn "No X11 tearing fix detected" "i3 has no built-in compositor — fix: sudo mkdir -p /etc/X11/xorg.conf.d && printf 'Section \"Device\"\\n  Identifier \"AMD\"\\n  Driver \"amdgpu\"\\n  Option \"TearFree\" \"true\"\\nEndSection\\n' | sudo tee /etc/X11/xorg.conf.d/10-amdgpu.conf, OR: sudo apt install picom. Ref: https://wiki.archlinux.org/title/AMDGPU"
        fi

        # HiDPI scaling guidance (only relevant for high-res panels like 2880x1800 OLED)
        local max_res=""
        if cmd_exists xrandr; then
            max_res=$(xrandr 2>/dev/null | grep -oP '\d+x\d+' | sort -t'x' -k1 -rn | head -1) || max_res=""
        fi
        local res_width=0
        if [[ -n "$max_res" ]]; then
            res_width=${max_res%%x*}
        fi
        if [[ "$res_width" =~ ^[0-9]+$ ]] && [[ "$res_width" -gt 2000 ]]; then
            local xft_dpi=""
            if cmd_exists xrdb; then
                xft_dpi=$(xrdb -query 2>/dev/null | grep -i "Xft.dpi" | awk '{print $2}') || xft_dpi=""
            fi
            if [[ "$xft_dpi" =~ ^[0-9]+$ ]] && [[ "$xft_dpi" -gt 120 ]]; then
                ok "HiDPI DPI set to $xft_dpi (Xft.dpi) — appropriate for ${max_res} panel"
            else
                info "High-res panel (${max_res}) detected — for HiDPI on i3+X11, set 'Xft.dpi: 192' in ~/.Xresources (2x). Also set GDK_SCALE=2 and QT_SCALE_FACTOR=2. Ref: https://wiki.archlinux.org/title/HiDPI"
            fi
        elif [[ -n "$max_res" ]]; then
            info "Display resolution: ${max_res} — no HiDPI scaling needed at this resolution"
        fi

        # GNOME fractional scaling (only relevant for GNOME on X11)
        if [[ "${wm_name,,}" == *"gnome"* ]] && cmd_exists gsettings; then
            local exp_features
            exp_features=$(gsettings get org.gnome.mutter experimental-features 2>/dev/null) || exp_features=""
            if [[ "$exp_features" == *"scale-monitor-framebuffer"* ]]; then
                info "GNOME fractional scaling enabled"
            fi
        fi

        # i3-specific desktop service checks
        if [[ "${wm_name,,}" == *"i3"* ]]; then
            # video group (required for brightnessctl without root)
            if id -nG 2>/dev/null | grep -qw video; then
                ok "User in 'video' group — brightnessctl can control backlight"
            else
                fail "User not in 'video' group" "brightnessctl will fail with 'Permission denied'" \
                    "sudo usermod -aG video \$USER && logout/login"
            fi

            # Backlight writable
            local bl_path="/sys/class/backlight"
            if [[ -d "$bl_path" ]]; then
                local bl_dev
                bl_dev=$(find "$bl_path" -maxdepth 1 -mindepth 1 -printf '%f\n' 2>/dev/null | head -1)
                if [[ -n "$bl_dev" ]] && [[ -w "$bl_path/$bl_dev/brightness" ]]; then
                    ok "Backlight '$bl_dev' writable"
                elif [[ -n "$bl_dev" ]]; then
                    fail "Backlight '$bl_dev' not writable" "user must be in 'video' group" \
                        "sudo usermod -aG video \$USER && logout/login"
                fi
            fi

            # xss-lock (screen lock on suspend)
            if pgrep -x xss-lock &>/dev/null; then
                ok "xss-lock running — screen locks on suspend"
            else
                fail "xss-lock not running" "screen will NOT lock on suspend/lid close" \
                    "Add to i3 config: exec --no-startup-id xss-lock --transfer-sleep-lock -- i3lock --nofork --color 475263"
            fi

            # polkit agent (GUI privilege escalation)
            if pgrep -f polkit-gnome-auth &>/dev/null || pgrep -f lxpolkit &>/dev/null; then
                ok "Polkit authentication agent running"
            else
                warn "No polkit authentication agent" "GUI privilege escalation will silently fail. Fix: add to i3 config: exec --no-startup-id /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1"
            fi

            # playerctl (generic MPRIS media controls)
            if cmd_exists playerctl; then
                ok "playerctl installed — media keys work with any MPRIS player"
            else
                warn "playerctl not installed" "media keys limited to hardcoded player. Fix: sudo apt install playerctl"
            fi

            # media-keys.sh (volume/brightness with OSD — i3 can't inline compound shell due to ; parsing)
            local media_keys="${HOME}/.i3/media-keys.sh"
            if [[ -x "$media_keys" ]]; then
                ok "media-keys.sh installed — volume/brightness keys with OSD notifications"
            elif [[ -f "$media_keys" ]]; then
                fail "media-keys.sh exists but not executable" "volume/brightness keys will not work" \
                    "chmod +x $media_keys"
            else
                fail "media-keys.sh missing" "volume/brightness keys will not work" \
                    "Re-run install.sh or check that ~/.i3 symlink points to the dotfiles i3/ directory"
            fi
        fi
    elif [[ -n "$session_type" ]]; then
        info "Session type: $session_type"
    fi
}

# ── Section 13: Pareto Security (Endpoint Compliance) ─────────────────────
check_pareto() {
    section "Pareto Security — Endpoint Compliance"

    # Binary
    if ! cmd_exists paretosecurity; then
        skip "Pareto Security" "not installed (sudo apt install paretosecurity)"
        return
    fi
    ok "Pareto Security installed ($(paretosecurity --version 2>/dev/null | head -1 || echo 'unknown version'))"

    # Team linking
    local pareto_conf="$HOME/.config/pareto.toml"
    if [[ -r "$pareto_conf" ]]; then
        local team_id
        team_id=$(grep -oP '^TeamID\s*=\s*"\K[^"]+' "$pareto_conf" 2>/dev/null) || team_id=""
        if [[ -n "$team_id" && "$team_id" != '""' ]]; then
            ok "Linked to team: $team_id"
        else
            warn "Pareto not linked to a team" "run: paretosecurity link <invite-url>"
        fi
    else
        warn "Pareto config missing" "expected $pareto_conf — run: paretosecurity link <invite-url>"
    fi

    # Systemd socket (system-level, root helper)
    if svc_active paretosecurity.socket; then
        ok "Root helper socket active"
    else
        fail "Root helper socket inactive" "root checks (firewall, encryption, updates) will fail" \
            "sudo systemctl enable --now paretosecurity.socket"
    fi

    # User timer (intentionally disabled — manual-only mode)
    if systemctl --user is-enabled paretosecurity-user.timer &>/dev/null; then
        info "Hourly check timer enabled — checks run automatically every hour"
    else
        info "Hourly check timer disabled — manual-only mode (run: paretosecurity check)"
    fi

    # ── Pareto check prerequisites (what the checks actually verify) ──

    # Firewall (Pareto checks iptables/nftables for DROP/REJECT or ufw/firewalld chains)
    if has_root; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null) || ufw_status=""
        if [[ "$ufw_status" == *"Status: active"* ]]; then
            ok "UFW firewall active — Pareto firewall check will pass"
        else
            fail "UFW firewall inactive" "Pareto reports: Firewall is off" \
                "sudo ufw enable    # add 'sudo ufw allow OpenSSH' first ONLY if others SSH into this laptop"
        fi
    else
        skip "Firewall check" "requires root"
    fi

    # docker.io residual (Pareto false positive: dpkg-query -W returns 0 for uninstalled packages in database)
    local docker_io_status
    docker_io_status=$(dpkg-query -W -f='${Status}' docker.io 2>/dev/null) || docker_io_status=""
    if [[ -z "$docker_io_status" ]]; then
        ok "No docker.io in dpkg database — Pareto docker.io check OK"
    elif [[ "$docker_io_status" == "install ok installed" ]]; then
        fail "docker.io package installed" "Pareto reports: Deprecated docker.io package. Replace with docker-ce" \
            "sudo apt-get remove docker.io && sudo apt-get install docker-ce docker-ce-cli containerd.io"
    else
        # Status is "unknown ok not-installed" or similar — residual entry, triggers Pareto false positive
        fail "Residual docker.io in dpkg database (status: $docker_io_status)" "triggers Pareto false positive" \
            "sudo dpkg --purge docker.io"
    fi

    # Docker rootless mode (Pareto checks docker info --format {{.SecurityOptions}} for "rootless")
    if cmd_exists docker; then
        local docker_sec
        docker_sec=$(docker info --format '{{.SecurityOptions}}' 2>/dev/null) || docker_sec=""
        if [[ "$docker_sec" == *"rootless"* ]]; then
            ok "Docker running in rootless mode — Pareto docker check will pass"
        elif [[ -n "$docker_sec" ]]; then
            warn "Docker not in rootless mode" "Pareto will report failure. Rootless is a significant change (different networking/storage). Accept or disable check: add 25443ceb-c1ec-408c-b4f3-2328ea0c84e1 to DisableChecks in ~/.config/pareto.toml"
        fi
    fi

    # Snap updates (Pareto runs snap refresh --list)
    if cmd_exists snap && svc_active snapd; then
        local snap_updates
        snap_updates=$(snap refresh --list 2>/dev/null) || snap_updates=""
        if [[ -z "$snap_updates" ]] || [[ "$snap_updates" == *"All snaps up to date"* ]]; then
            ok "All snaps up to date — Pareto app updates check OK"
        else
            fail "Snap updates available" "Pareto reports: Updates available for: Snap" \
                "sudo snap refresh"
        fi
    fi
}

# ── Section 14: Summary & Remediation ────────────────────────────────────────
print_summary() {
    section "Summary"

    local total=$((COUNT_OK + COUNT_WARN + COUNT_FAIL + COUNT_SKIP))
    printf '\n  %sOK: %d%s | %sWARN: %d%s | %sFAIL: %d%s | %sSKIP: %d%s | INFO: %d | Total: %d\n' \
        "$C_GREEN"  "$COUNT_OK"   "$C_RESET" \
        "$C_YELLOW" "$COUNT_WARN" "$C_RESET" \
        "$C_RED"    "$COUNT_FAIL" "$C_RESET" \
        "$C_DIM"    "$COUNT_SKIP" "$C_RESET" \
        "$COUNT_INFO" "$total"

    # Remediation
    if [[ ${#REMEDIATION[@]} -gt 0 ]]; then
        printf '\n%s── Remediation Commands ──%s\n' "$C_BOLD" "$C_RESET"
        printf 'Copy-paste these commands to fix FAILed checks:\n\n'
        local i=1
        for cmd in "${REMEDIATION[@]}"; do
            printf '%s%d.%s %s\n\n' "$C_BOLD" "$i" "$C_RESET" "$cmd"
            i=$((i + 1))
        done
        printf '%sAfter applying changes, run: sudo update-grub && sudo reboot%s\n' "$C_YELLOW" "$C_RESET"
    else
        printf '\n%sNo FAILed checks — no remediation needed.%s\n' "$C_GREEN" "$C_RESET"
    fi

    # Manual BIOS checks
    printf '\n%s── Manual BIOS Checks (F10 at boot) ──%s\n' "$C_BOLD" "$C_RESET"
    printf 'These cannot be verified from the OS. Check each in BIOS:\n\n'
    cat << 'BIOS'
  [ ] FIRST: Restore BIOS Defaults (F10 > Restore Defaults)
      Fixes most suspend issues. Apply other settings after restoring defaults.
      Source: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525

  [ ] Secure Boot: ENABLED
      Required for suspend. Source: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525

  [ ] RAM Encryption (TSME): ENABLED
      Required for suspend. 256-bit AES-XTS on Zen 5. Source: https://www.phoronix.com/review/amd-memory-guard-ram-encrypt

  [ ] Microsoft Pluton: ENABLED
      Required for suspend. All sources confirm disabling breaks s2idle. Source: https://www.phoronix.com/review/hp-zbook-ultra-g1a/3

  [ ] Motion Sensing Cooling Mode: DISABLED
      Causes erratic fan bursts based on accelerometer. Source: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525

  [ ] Fan Offset: +3
      Raises temperature threshold before fans spin up — quieter idle. Source: https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525

  [ ] Security > BIOS Sure Start > Secure Boot Keys Protection: DISABLED
      Prevents infinite boot loops when Linux modifies Secure Boot keys.
      NOTE: This does NOT disable Secure Boot itself — only stops Sure Start from locking the key database.
      Source: https://forum.level1techs.com/t/the-ultimate-arch-secureboot-guide-for-ryzen-ai-max-ft-hp-g1a-128gb-8060s-monster-laptop/230652

  [ ] Security > BIOS Sure Start > Save/Restore MBR of System Hard Drive: DISABLED
      Prevents Sure Start from reverting partition table changes during install. Source: https://h20195.www2.hp.com/v2/getpdf.aspx/4AA5-4453ENW.pdf

  [ ] Security > BIOS Sure Start > Save/Restore GPT of System Hard Drive: DISABLED
      Same as above — prevents partition table restoration. Source: https://h20195.www2.hp.com/v2/getpdf.aspx/4AA5-4453ENW.pdf

  [ ] Webcam: your choice
      DISABLED = better sleep (0.14-0.20W, ~15 days standby). ENABLED = webcam works but ~10-15% overnight drain.
      ISP firmware blocks GPU s2idle. Source: https://bugzilla.kernel.org/show_bug.cgi?id=220702
BIOS

    # Important reminders
    printf '\n%s── Important Reminders ──%s\n' "$C_BOLD" "$C_RESET"
    printf '  - Download and keep the HP OEM ISO (stella-noble-oem-24.04b-*.iso) from\n'
    printf '    https://support.hp.com/us-en/drivers/hp-zbook-ultra-g1a-14-inch-mobile-workstation-pc/2102737532\n'
    printf '    There is NO HP recovery partition on the Ubuntu variant.\n'
    printf '  - Back up EFI tools: sudo cp -r /boot/efi/EFI/HP /path/to/backup/ (before any reinstall)\n'
    printf '  - Do NOT use 65W USB-C chargers — firmware-enforced minimum wattage, will not charge.\n'
    printf '    Source: https://h30434.www3.hp.com/t5/Notebook-Hardware-and-Upgrade-Questions/Charging-HP-Zbook-Ultra-G1A-with-65w/td-p/9538308\n'
    printf '  - Do NOT attempt a major version upgrade (24.04 → 25.x) — breaks OEM kernel track.\n'
    printf '    Ubuntu 26.04 ships Linux 7.0 — AMD ISP4 missed merge window (targeting 7.1+). Webcam requires OEM kernel.\n'
    printf '  - Reinstalling is safe — BIOS/Sure Start are on isolated SPI chip, unaffected by disk ops.\n'
    printf '    HP Wolf Security software agents (Sure Run, Sure Click, Sure Sense) are Windows-only.\n'
    printf '  - Verify serial: sudo cat /sys/class/dmi/id/product_serial (expected: 5CG609201K)\n'
    printf '\n'
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    printf '%sHP ZBook Ultra G1a — Linux Health Check%s\n' "$C_BOLD" "$C_RESET"
    printf 'Reference: ~/HP-ZBook-Ultra-G1a-Linux-Report.md\n'
    printf 'Date: %s\n' "$(date +%Y-%m-%d)"

    check_hardware
    check_os_kernel
    check_kernel_params
    check_power
    check_suspend
    check_security
    check_fde
    check_wifi
    check_firmware
    check_peripherals
    check_display
    check_pareto
    print_summary

    # Exit code: 0 if no FAILs, 1 if any FAILs
    if [[ $COUNT_FAIL -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
