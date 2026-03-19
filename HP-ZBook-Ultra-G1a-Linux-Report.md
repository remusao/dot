# HP ZBook Ultra G1a: Comprehensive Linux Report

> **Date:** March 18, 2026
> **Hardware:** HP ZBook Ultra G1a 14" Mobile Workstation (AMD Ryzen AI Max+ PRO 395 / Strix Halo)
> **Purpose:** Should you keep the HP pre-installed Ubuntu, reinstall clean Ubuntu 24.04 LTS, or use another distro?

---

## Table of Contents

1. [TL;DR — Recommendation](#1-tldr--recommendation)
2. [What Is the HP Pre-Installed Ubuntu?](#2-what-is-the-hp-pre-installed-ubuntu)
3. [Full Disk Encryption (FDE)](#3-full-disk-encryption-fde)
4. [The GRUB / Bootloader Situation](#4-the-grub--bootloader-situation)
5. [The "Partial Upgrade" Issue](#5-the-partial-upgrade-issue)
6. [Stock Ubuntu vs OEM Ubuntu — What Breaks?](#6-stock-ubuntu-vs-oem-ubuntu--what-breaks)
7. [Ubuntu 26.04 LTS — Will It Work?](#7-ubuntu-2604-lts--will-it-work)
8. [Known Linux Issues — Detailed Breakdown](#8-known-linux-issues--detailed-breakdown)
9. [Suspend, Sleep, and Hibernate — Deep Dive](#9-suspend-sleep-and-hibernate--deep-dive)
10. [Fan Noise and Thermal Management — Deep Dive](#10-fan-noise-and-thermal-management--deep-dive)
11. [Full Disk Encryption Setup — Deep Dive](#11-full-disk-encryption-setup--deep-dive)
12. [Other Linux Distributions — Comparison](#12-other-linux-distributions--comparison)
13. [Complete Hardware Status Matrix](#13-complete-hardware-status-matrix)
14. [Input Device Configuration for i3/X11](#14-input-device-configuration-for-i3x11)
15. [Recommended Setup — Step by Step](#15-recommended-setup--step-by-step)
16. [HP Wolf Security — Linux Compatibility and Reinstall Safety](#16-hp-wolf-security--linux-compatibility-and-reinstall-safety)
17. [Support Channels](#17-support-channels)
18. [All Sources](#18-all-sources)
19. [Open Bugs & Workaround Tracking](#19-open-bugs--workaround-tracking)
20. [Pareto Security — Endpoint Compliance](#20-pareto-security--endpoint-compliance)

---

## 1. TL;DR — Recommendation

**Keep the HP OEM Ubuntu** (or reinstall using HP's OEM ISO). It's standard Ubuntu 24.04 LTS with a Canonical-maintained OEM kernel providing critical hardware support — especially the webcam (AMD ISP4 driver).

- **Stock Ubuntu 24.04 + OEM kernel** (`sudo apt install linux-oem-24.04`) is also a valid path — you don't strictly need the HP OEM ISO
- **The only component that requires the OEM kernel is the webcam** — everything else works on mainline Linux 6.14+
- **Ubuntu 26.04 LTS** (releasing April 23, 2026) will NOT solve the webcam issue — the AMD ISP4 driver missed the Linux 7.0 merge window
- **Your "Partial Upgrade" and GRUB issues are expected behavior** — not signs of a broken system (see sections 4 and 5)
- **No full disk encryption by default** — you need to set it up yourself (see section 11)
- **Reinstalling is safe** — HP Wolf Security hardware features (Sure Start, ESC) are on isolated chips, unaffected by disk operations. No HP recovery partition exists on the Ubuntu variant. Disable "Secure Boot Keys Protection" in BIOS before reinstalling (see section 15)

---

## 2. What Is the HP Pre-Installed Ubuntu?

The pre-installed OS is **Ubuntu 24.04 LTS with a custom OEM kernel** (`linux-oem-24.04b`, kernel 6.11.0-1020-oem), built and maintained by **[Canonical's OEM Enablement Team](https://canonical-kernel-docs.readthedocs-hosted.com/latest/reference/oem-kernels/)** — not by HP.

The codename in Canonical's system is **"Stella"** — their internal name for all HP hardware enablement projects. Dell is "Somerville", Lenovo is "Sutton" ([source: Canonical HWE Team PPA](https://launchpad.net/~canonical-hwe-team/+archive/ubuntu/pc-oem-dkms)).

### What's different from stock Ubuntu 24.04

- **OEM kernel** with out-of-tree patches, most critically the [AMD ISP4 camera driver](https://github.com/amd/Linux_ISP_Kernel)
- **HP "stella" meta packages** pulling HP-specific firmware/drivers from [Canonical's OEM archive](https://launchpad.net/ubuntu/noble/+source/oem-stella-sensei-meta)
- **AMD NPU firmware** (`amdnpu/17f0_11/npu.sbin`) for the AI accelerator
- **Cirrus Logic audio amplifier DSP firmware** for the speakers

### What's the same

Standard GNOME desktop, apt, all standard Ubuntu repos, standard GRUB bootloader. The userspace is vanilla Ubuntu 24.04.

### HP OEM ISO

Available from [HP Support](https://support.hp.com/us-en/drivers/hp-zbook-ultra-g1a-14-inch-mobile-workstation-pc/2102737532) (select "Linux" as OS). The filename is `stella-noble-oem-24.04b-20250422-107.iso` ([confirmed on HP Community forums](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Using-the-webcam-on-zbook-ultra-g1a-Linux-ubuntu-25-04/td-p/9375051/page/3)).

### Important nuance

You do NOT strictly need the HP OEM ISO. You can install stock Ubuntu 24.04 and then add the OEM kernel:

```bash
sudo apt install linux-oem-24.04
ubuntu-drivers list-oem
```

The HP OEM ISO is a convenience (pre-configured), but there are no secret HP-only drivers beyond what the `linux-oem-24.04` meta-package provides. The only component that *requires* the OEM kernel is the webcam ([Phoronix confirmed](https://www.phoronix.com/review/hp-zbook-ultra-g1a/2): "if on Linux 6.14+ and Mesa 25.0+ you should basically be in good shape for all standard functionality... with one exception: the web camera").

### Ubuntu Certification

The HP ZBook Ultra G1a is **[officially certified by Canonical for Ubuntu 24.04 LTS](https://ubuntu.com/certified/platforms/15242)** in multiple configurations:
- [Ryzen AI Max+ PRO 395](https://ubuntu.com/certified/202411-36033/24.04%20LTS)
- [Ryzen AI Max 385](https://ubuntu.com/certified/202411-36043/24.04%20LTS)

It is also [Red Hat certified for RHEL 10](https://catalog.redhat.com/en/hardware/system/detail/282387).

> **Critical warning from [Ubuntu's certification page](https://ubuntu.com/certified/platforms/15242):**
> "Pre-installed in some regions with a custom Ubuntu image that takes advantage of the system's hardware features and may include additional software. **Standard images of Ubuntu may not work well, or at all.**"

---

## 3. Full Disk Encryption (FDE)

**The HP OEM image most likely does NOT ship with FDE enabled by default.** Ubuntu 24.04's FDE is opt-in during installation, and no evidence was found of HP pre-enabling it. The OEM first-boot flow may have offered it as an option that was skipped.

### How to check if your current install has FDE

```bash
# Quick check — look for "crypto_LUKS" in the FSTYPE column
lsblk -f

# Find any LUKS partitions
sudo blkid -t TYPE=crypto_LUKS

# Check a specific partition
sudo cryptsetup isLuks /dev/nvme0n1p3 && echo "LUKS encrypted" || echo "Not encrypted"

# View LUKS header details (if encrypted)
sudo cryptsetup luksDump /dev/nvme0n1p3
```

See [Section 11](#11-full-disk-encryption-setup--deep-dive) for a complete FDE setup guide.

---

## 4. The GRUB / Bootloader Situation

The HP OEM Ubuntu uses **standard GRUB** — there is no custom bootloader from HP. The issues you're seeing are a well-documented **HP BIOS/UEFI firmware quirk** affecting the entire ZBook lineup.

### The problem

HP's UEFI firmware doesn't always auto-detect GRUB boot entries. It can ignore `efibootmgr` entries, causing boot to a blank screen or falling through to other boot options ([Ubuntu Forums](https://ubuntuforums.org/showthread.php?t=2335223), [Linux.org](https://www.linux.org/threads/hp-laptop-running-windows-10-ubuntu-and-mageia-no-grub-must-select-f9-to-get-selection.33148/)).

### Why "Ubuntu couldn't find Grub partition"

This likely means the HP BIOS isn't properly surfacing the EFI System Partition where GRUB is installed — not that GRUB is missing.

### Fixes

1. **F10 → Advanced → Boot Options → Customized Boot → Add** — set path to `EFI\ubuntu\shimx64.efi` (Secure Boot ON) or `EFI\ubuntu\grubx64.efi` (Secure Boot OFF), then set as first boot priority ([Linux Mint Forums](https://forums.linuxmint.com/viewtopic.php?t=432222))
2. **F9** provides a one-time boot menu to select Ubuntu/GRUB
3. EFI System Partition should be standard 512MB VFAT

**Sources:** [Level1Techs Arch+SecureBoot Guide](https://forum.level1techs.com/t/the-ultimate-arch-secureboot-guide-for-ryzen-ai-max-ft-hp-g1a-128gb-8060s-monster-laptop/230652), [Gentoo Wiki](https://wiki.gentoo.org/wiki/User:Owenwastaken/HP_ZBook_Ultra_G1a), [ArchWiki — HP EliteBook 840 G1](https://wiki.archlinux.org/title/HP_EliteBook_840_G1)

---

## 5. The "Partial Upgrade" Issue

This is consistent with the OEM kernel track. The HP OEM image uses `linux-oem-24.04b` from Canonical's OEM archive (outside standard Ubuntu repos). When Ubuntu's standard updater sees packages from a different archive, it may offer a "partial upgrade" instead of a full one. **This is expected behavior — not a sign of a broken system.**

### Recommendation

Stay on the OEM kernel track. Use the rolling meta-package that always points to the latest OEM kernel:

```bash
sudo apt install linux-oem-24.04    # rolling meta-package — always latest OEM kernel
```

**Important:** Do NOT use `linux-image-oem-24.04c` or other lettered variants — they are transitional packages that may not track future migrations. The unnumbered `linux-oem-24.04` meta-package is the correct one per [Canonical's OEM kernel documentation](https://canonical-kernel-docs.readthedocs-hosted.com/latest/reference/oem-kernels/). As of March 2026, it resolves to kernel 6.17.x ([Launchpad](https://launchpad.net/ubuntu/noble/amd64/linux-oem-24.04c)).

**Do NOT** attempt a major version upgrade (e.g., 24.04 → 25.04) — this will replace the OEM kernel. Regular `apt update && apt upgrade` within 24.04 (including point releases like 24.04.1, 24.04.2) is fine and keeps you current.

---

## 6. Stock Ubuntu vs OEM Ubuntu — What Breaks?

| Component | Stock Ubuntu 24.04 (generic kernel) | With OEM kernel (`linux-oem-24.04`) |
|---|---|---|
| **Webcam (5MP IR, AMD ISP4)** | Completely broken | Works (`amd_isp_capture`) |
| **AMD NPU (50 TOPS, XDNA 2)** | Kernel driver exists but limited | Kernel driver + firmware |
| CPU, GPU, WiFi, BT, NVMe, TB4 | Works | Works |
| Audio (Cirrus amp) | Works (may need firmware) | Works |
| Fingerprint reader | Works ([libfprint](https://launchpad.net/ubuntu/+source/libfprint/+bug/2058193)) | Works |
| LVFS firmware updates | Works | Works |

**The webcam is the primary reason the OEM kernel is critical.** Everything else nominally works on the generic kernel with Linux 6.14+ and Mesa 25.0+ ([Phoronix tested across 7 distros](https://www.phoronix.com/review/hp-zbook-ultra-g1a/2)). However, the OEM kernel also provides better stability — generic kernels 6.14-6.16 are affected by GUI freeze regressions ([Bug #2115969](https://bugs.launchpad.net/ubuntu/+source/linux-oem-6.14/+bug/2115969)), and WiFi resume behavior varies by kernel version.

### Recovery path if you already installed stock Ubuntu

```bash
sudo apt install linux-oem-24.04
ubuntu-drivers list-oem    # shows which OEM meta-packages match your hardware
# Install the specific stella meta package identified above —
# Do NOT wildcard all oem-stella-* packages (each HP platform has its own sub-codename)
# e.g.: sudo apt install oem-stella-sensei-meta
```

`ubuntu-drivers list-oem` is the canonical way to check whether your machine is recognized on the OEM kernel track and which additional OEM meta-packages to install.

---

## 7. Ubuntu 26.04 LTS — Will It Work?

Ubuntu 26.04 LTS **"Resolute Raccoon"** is releasing **[April 23, 2026](https://www.omgubuntu.co.uk/2025/11/ubuntu-26-04-release-schedule)**. Beta drops [March 26](https://www.omgubuntu.co.uk/2026/02/ubuntu-2604-snapshot-4-download). It ships with **[Linux kernel 7.0](https://www.phoronix.com/news/Ubuntu-26.04-LTS-Linux-Commit)** (originally numbered 6.20 before Linus renumbered).

### Will it work on the ZBook Ultra G1a?

**General hardware: YES** — Strix Halo CPU/GPU, WiFi, NVMe, Thunderbolt are all well-supported in kernel 7.0. ROCm will be installable directly via `sudo apt install rocm` ([AMD Strix Halo ROCm docs](https://rocm.docs.amd.com/en/latest/how-to/system-optimization/strixhalo.html)).

**Webcam: NO — not out of the box.** The AMD ISP4 driver has missed every merge window (6.18, 6.19, AND 7.0). It's now on its **[v9 patch revision](https://lkml.org/lkml/2026/3/2/278)** (posted March 2, 2026) targeting Linux 7.1. The media subsystem maintainers are [overloaded and can't guarantee review timelines](https://www.phoronix.com/news/AMD-ISP4-Driver-Pending-Review). This means:

- Ubuntu 26.04 LTS at launch will **not** have webcam support on the generic kernel ([Phoronix — Linux 7.0 Media Updates, AMD ISP4 Still Missing](https://www.phoronix.com/news/Linux-7.0-Media))
- You will still need the OEM kernel or out-of-tree patches
- Canonical may backport the ISP4 driver via SRU or HWE update later, but this is not confirmed

### Other Ubuntu 26.04 highlights

- **TPM-backed full disk encryption** native in installer ([PBXScience](https://pbxscience.com/ubuntu-26-04-lts-tpm-encryption-rust-core-and-post-quantum-security-arrive/))
- **GNOME 50** (Wayland-only — X11 session removed)
- **x86-64-v3** optimized packages
- **Post-quantum cryptography** (ML-KEM + X25519) by default
- Upgrades from 24.04 LTS won't be enabled until the **26.04.1 point release ([August 6, 2026](https://linuxconfig.org/ubuntu-26-04-release-date-and-new-features-in-resolute-raccoon))**

### Daily builds and beta

- **[Daily builds available](https://cdimage.ubuntu.com/daily-live/current/)** now
- **[Snapshot 4](https://www.phoronix.com/news/Ubuntu-26.04-Snapshot-4)** (February 26, 2026) is the latest milestone
- Beta: March 26, 2026
- Kernel Freeze: April 9, 2026
- Final Release: April 23, 2026

**Bottom line:** Waiting for 26.04 won't solve the webcam problem. Stay on 24.04 LTS + OEM kernel. Revisit when 26.04.1 drops (August 2026).

---

## 8. Known Linux Issues — Detailed Breakdown

### 8.1 GUI Freezes / System Hangs (CRITICAL)

- **Cause:** PCIe ASPM regression in certain OEM kernels after `6.14.0-1004-oem`, affecting the AMD GPU/display stack via MT7925 WiFi ASPM interaction ([Ubuntu Bug #2115969](https://bugs.launchpad.net/ubuntu/+source/linux-oem-6.14/+bug/2115969)). Kernel 6.11 (stock) and OEM 6.14.0-1004 are unaffected; the regression appears in 6.14.0-1006-oem and later.
- **Symptoms:** Mouse moves but desktop unresponsive, especially in Power Saver mode. Happens within 1-2 minutes on kernel 6.14-1007-oem and later. Terminal via Alt+F3 still works.
- **Fix:** Add `pcie_aspm=off` to kernel parameters. Note: `pcie_aspm.policy=performance` was initially suggested as a softer alternative but was [subsequently found to be ineffective](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Using-the-webcam-on-zbook-ultra-g1a-Linux-ubuntu-25-04/td-p/9375051) — freezing still occurs when transitioning from low to high demand.
- **Side effects:**
  - May lose Intel Ethernet controller (IGC driver, `8086:5502` — no `eth0`). [Confirmed by user Jean-Eric Cuendet](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Using-the-webcam-on-zbook-ultra-g1a-Linux-ubuntu-25-04/td-p/9375051)
  - One user reported [no measurable battery impact via Powertop](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Using-the-webcam-on-zbook-ultra-g1a-Linux-ubuntu-25-04/td-p/9375051) — possibly because buggy ASPM was paradoxically increasing power draw on this hardware (a [known phenomenon on some laptops](https://www.spinics.net/lists/linux-pci/msg71787.html))
- **Most stable OEM kernel without ASPM workaround:** `linux-image-6.14.0-1004-oem` — does not exhibit the GUI freeze. However, it has a known WiFi suspend/resume bug. With `pcie_aspm=off`, kernel `6.14.0-1011-oem` is reported as "[rock solid](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Using-the-webcam-on-zbook-ultra-g1a-Linux-ubuntu-25-04/td-p/9375051)."

### 8.2 USB-C Charging (PD 3.1 Firmware Bug)

- Third-party USB-C chargers repeatedly connect/disconnect — a PD 3.1 voltage negotiation bug switching between 20V and 28V ([HP Support — Charging Issues](https://h30434.www3.hp.com/t5/Notebook-Hardware-and-Upgrade-Questions/Zbook-Ultra-g1a-Ubuntu-not-charging-redux/td-p/9437876))
- **HP 140W charger** always works
- **Confirmed working third-party:** Satechi 145W, Anker Desktop 250W (with 240W-rated cable), Samsung Galaxy Book 140W + Apple TB 240W cable ([HP Support — PD 3.1 Firmware](https://h30434.www3.hp.com/t5/Notebook-Hardware-and-Upgrade-Questions/hp-zbook-ultra-g1a-needs-more-stable-pd-3-1-charging/td-p/9465799))
- **65W chargers do NOT work** — firmware-enforced minimum wattage ([HP Support — 65W Charging](https://h30434.www3.hp.com/t5/Notebook-Hardware-and-Upgrade-Questions/Charging-HP-Zbook-Ultra-G1A-with-65w/td-p/9538308))
- **Fix:** Apply TI PD firmware update (v6.9.0 dual port / v5.9.0 single port) via fwupd or HP Support
- Laptop may cap third-party chargers at 96-97% with a warning recommending HP chargers

### 8.3 Thunderbolt Dock Disconnection

- When any USB-C device supplies >90W, the laptop randomly disconnects/reconnects — affects ALL docks (HP and third-party), both Linux and Windows ([HP Support — Dock Disconnection](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Ultrabook-G1a-constantly-disconnecting-from-docks-any-docks/td-p/9521854))
- **Workaround:** Route dock through a TB hub that limits power delivery to 60W
- **Monitor tip:** Connect HP charger FIRST, then connect TB cable to monitor

### 8.4 Random Reboots (Some Units)

- Affects a subset of hardware units — [3/8 in one reported batch](https://h30434.www3.hp.com/t5/Business-Notebooks/HP-ZBook-Ultra-14-G1a-randomly-reboots/td-p/9549358) (128GB/8060S config)
- Appears hardware-level — affects both Windows and Linux. Another user [returned 2 units for BSODs/restarts](https://h30434.www3.hp.com/t5/Notebook-Hardware-and-Upgrade-Questions/HP-ZBook-Ultra-14-G1a-BSOD-Reliability/td-p/9402236/page/2)
- Some resolved by motherboard replacement; BIOS updates help others
- `pcie_aspm=off` may help (addresses PCIe-related instability)
- `processor.max_cstate=1` is **not a reliable fix** — one user reported it appeared to work for 2 days then failed. Root cause was a hardware defect fixed by **motherboard replacement**. Additionally, `processor.max_cstate` may not be honored on AMD Zen 5 (the Arch Wiki notes the parameter is not always applied and C6 state may still be entered)

### 8.5 Audio Quality

- Degraded vs Windows — HDA-Jack Retask tool can help
- Cirrus Logic amplifier firmware needed for proper speaker output

### 8.6 Bluetooth

- If Bluetooth stops working (firmware setup failure `-110`): enter BIOS → disable BT → save → re-enable BT → save ([Gentoo Wiki](https://wiki.gentoo.org/wiki/User:Owenwastaken/HP_ZBook_Ultra_G1a))
- On Fedora 42: BT toggles off immediately after enabling ([Fedora Discussion](https://discussion.fedoraproject.org/t/bluetooth-toggling-off-immediately-after-trying-to-turn-it-on/163260))

### 8.7 NPU (AMD XDNA 2)

- **Kernel driver (`amdxdna`)** exists since Linux 6.14 ([AMD NPU kernel docs](https://docs.kernel.org/accel/amdxdna/amdnpu.html))
- **Userspace stack is NOT ready** — the XRT runtime, ONNX Runtime with Vitis AI execution provider, and IREE+MLIR-AIE compiler toolchain are fragmented, not in distro repos, and require building from source
- **The GPU (Radeon 8060S) is the practical AI accelerator on Linux** — up to 96GB unified memory via ROCm
- **NPU regression:** `amdxdna` does NOT work on kernels 6.18–6.18.7 due to an IOMMU/SVA regression ([Phoronix](https://www.phoronix.com/news/Linux-Dropping-AMD-NPU2))
- **Bottom line:** The NPU's 50 TOPS is essentially unusable on Linux today. Use ROCm on the iGPU instead.

### 8.8 linux-firmware Compatibility (CRITICAL for ROCm)

- **`linux-firmware-20251125` is BROKEN** for Strix Halo — MES firmware 0x83 causes GPU memory faults (`GCVM_L2_PROTECTION_FAULT_STATUS:0x00800932`), tracked as [ROCm #5724](https://github.com/ROCm/ROCm/issues/5724). A partial fix shipped in `20251125-2` but did not cover all GPUs. ([Framework Community](https://community.frame.work/t/fyi-linux-firmware-amdgpu-20251125-breaks-rocm-on-ai-max-395-8060s/78554), [Arch Forums](https://bbs.archlinux.org/viewtopic.php?id=310497))
- **Use `linux-firmware 20260110` or newer** for stable ROCm on Strix Halo.
- MES firmware `0x83` introduced a new GPU hang regression. Workaround: `amdgpu.cwsr_enable=0` ([ROCm Issue #5590](https://github.com/ROCm/ROCm/issues/5590))

### 8.9 Security Advisories (AMD Zen 5)

| Advisory | Severity | Impact | Fix |
|---|---|---|---|
| **[CVE-2025-29943 (StackWarp)](https://www.amd.com/en/resources/product-security.html)** | Medium | Allows privileged host to execute code inside SEV-SNP VMs. Affects Zen 1-5 (including Strix Halo). | Microcode update via BIOS/fwupd |
| **[AMD-SB-7055 (RDSEED)](https://www.amd.com/en/resources/product-security.html)** | High | RDSEED instruction on Zen 5 returns "0" incorrectly signaling success — generates potentially predictable keys. | AGESA firmware update via BIOS |
| **[AMD-SB-6024](https://www.amd.com/en/resources/product-security/bulletin/amd-sb-6024.html)** | Multiple | Graphics driver security bulletin (February 2026), multiple CVEs. | Update Mesa/amdgpu drivers |
| **[AMD-SB-7033 (EntrySign)](https://www.amd.com/en/resources/product-security/bulletin/amd-sb-7033.html)** | High | Allows loading unsigned microcode on Zen 1–5 (including Strix Halo) via flawed signature verification. | AGESA ≥1.2.0.3C via BIOS/fwupd |
| **[CrackArmor (USN-8095-1)](https://ubuntu.com/security/notices/USN-8095-1)** | High | 9 AppArmor privilege escalation CVEs (March 2026). Exploitation chain via su/sudo (USN-8091-1, USN-8092-1). | Kernel update + su/sudo patches |

**Action:** Run `sudo fwupdmgr update` to ensure you have the latest microcode and AGESA firmware. Run `sudo apt update && sudo apt upgrade` for CrackArmor kernel patches.

**MCE Monitoring:** Use `rasdaemon` for hardware error monitoring on AMD Zen — `mcelog` is non-functional on AMD processors. Install: `sudo apt install rasdaemon`.

### 8.10 Kernel Panic — Fatal Exception in Interrupt

- **What it means:** "Fatal exception in interrupt" is a kernel panic triggered when an oops (NULL pointer dereference, page fault, etc.) occurs inside a hardware interrupt handler. The kernel panics because there's no user process to kill — verified behavior from `arch/x86/kernel/dumpstack.c:oops_end()`.
- **Most likely causes on this hardware:**
  1. **PCIe ASPM interaction** — the ASPM regression (Bug #2115969) causes GUI freezes; on some kernel versions, the underlying fault may occur in interrupt context, escalating to a panic. External displays make this more frequent ([Ubuntu Bug #2033295](https://bugs.launchpad.net/bugs/2033295)). Fix: `pcie_aspm=off`
  2. **amdgpu driver fault** — MES firmware hangs ([ROCm #5590](https://github.com/ROCm/ROCm/issues/5590)) cause GPU resets; if the reset path faults in IRQ context, it becomes a panic. MES firmware 0x83 (linux-firmware-20251125) causes GPU page faults `GCVM_L2_PROTECTION_FAULT_STATUS` ([ROCm #5724](https://github.com/ROCm/ROCm/issues/5724)). Fix: linux-firmware ≥20260110; `amdgpu.cwsr_enable=0` for compute workloads
  3. **Hardware defect** — affects subset of units (3/8 in one batch). `processor.max_cstate=1` is not a reliable fix. May require motherboard replacement.
- **Diagnosis:** Run the diagnostic script: `bash ~/zbook-panic-diag.sh` — checks pstore (most reliable post-panic log source), previous boot journal, GPU firmware versions, PCIe state, and MCE errors
- **Post-mortem tools:** pstore (`/sys/fs/pstore/`, `/var/lib/systemd/pstore/`) captures kernel log tail before panic. `linux-crashdump` provides full vmcore. `rasdaemon` monitors hardware errors on AMD Zen (mcelog is non-functional on AMD).
- **Slow reboot after panic:** Consistent with amdgpu failing to cleanly shut down the GPU (known pattern — VRAM eviction delays, SMU quiesce failures)

### 8.11 No HP Recovery Partition

There is no Ubuntu-specific recovery partition. The HP OEM ISO serves as the recovery mechanism. **Download and keep a copy** before making any changes.

### 8.12 Panel Self Refresh / Panel Replay — Display Freezes on X11

- **Cause:** PSR (Panel Self Refresh) and Panel Replay are display controller power-saving features (managed by DCN 3.5.1's DMUB firmware) that allow the GPU scanout engine to sleep when screen content is static. On X11, the compositor's damage tracking does not properly signal dirty regions to the display controller, so the panel stays in its self-refreshed (frozen) state. External displays via USB-C/DP exacerbate this — hotplug events trigger PSR state machine transitions that X11 cannot track. **This is independent of the PCIe ASPM issue** (Section 8.1) — you may need both `pcie_aspm=off` and `amdgpu.dcdebugmask=0x410`.
- **Symptoms:** Identical to 8.1 — desktop unresponsive, mouse moves, TTY accessible. More frequent when connecting/disconnecting external displays.
- **Wayland is not affected** — Wayland compositors (Mutter, KWin) have proper PSR integration.
- **Fix:** Add `amdgpu.dcdebugmask=0x410` to kernel parameters.
- **⚠️ Note:** This parameter was documented here but **was not applied to the live GRUB config** as of March 2026 audit. Ensure it is present in `/etc/default/grub` and run `sudo update-grub`.

**Understanding `dcdebugmask` — the `DC_DEBUG_MASK` enum** (source: [`drivers/gpu/drm/amd/include/amd_shared.h`](https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/include/amd_shared.h)):

| Bit | Name | Effect |
|---|---|---|
| `0x10` | `DC_DISABLE_PSR` | Disables PSR v1 **and** PSR-SU (kdoc: "disable Panel self refresh v1 and PSR-SU") |
| `0x200` | `DC_DISABLE_PSR_SU` | Disables PSR-SU only (leaves PSR v1). Currently redundant — PSR-SU is hardcoded off in mainline (`link_supports_psrsu()` returns `false`) |
| `0x400` | `DC_DISABLE_REPLAY` | Disables Panel Replay (FreeSync Panel Replay, eDP 1.5) |
| `0x800` | `DC_DISABLE_IPS` | Disables all Idle Power States |

**Common values:**

| Value | What it disables | Use case |
|---|---|---|
| `0x10` | PSR v1 + PSR-SU | Standard fix for PSR freezes |
| `0x410` | PSR + Panel Replay | **Recommended for X11** — comprehensive display stability |
| `0x600` | PSR-SU + Panel Replay | ⚠️ Leaves PSR v1 active — incomplete fix despite being widely cited ([CachyOS](https://discuss.cachyos.org/t/tutorial-mitigate-gfx-crash-lockup-apparent-freeze-with-amdgpu/10842), [EndeavourOS](https://forum.endeavouros.com/t/howto-mitigate-gfx-crash-lockup-apparent-freeze-with-amdgpu/73082)) |

How it works: in `amdgpu_dm.c`, `DC_DISABLE_PSR` (0x10) prevents `psr_feature_enabled` from being set to `true`, so `amdgpu_dm_set_psr_caps()` is never called — PSR v1 and PSR-SU are both prevented from initializing. `DC_DISABLE_REPLAY` (0x400) separately disables Panel Replay. DCN 3.5.1 (Strix Halo, `IP_VERSION(3, 5, 1)`) is in the explicit switch-case list where PSR is enabled by default.

- **Battery trade-off:** Disabling PSR forces the GPU scanout engine to remain active at the panel's refresh rate (120Hz) even when content is static. PSR power savings are ~0.5W (measured on Intel i915 — [Hans de Goede, Red Hat](https://hansdegoede.livejournal.com/18653.html); no public AMD-specific measurements exist). Additionally, IPS (Idle Power States) depends on PSR — `amdgpu_dm_psr_enable()` calls `dc_allow_idle_optimizations(true)` when `caps.ips_support` is set, so with PSR disabled, the DCN block cannot enter deep idle. The compounding IPS cost is unquantified but likely larger than PSR alone. Other power mechanisms (DPMS, clock gating, GFXOFF, `amd_pstate=active`) still function normally. Measure your own impact with `powertop` on battery.
- **Graduated approach:** Try `0x10` alone first (disables PSR, keeps Panel Replay). Escalate to `0x410` if freezes persist. On Wayland, this parameter is unnecessary.
- **References:** [Arch Wiki AMDGPU](https://wiki.archlinux.org/title/AMDGPU), [kernel DC debug docs](https://docs.kernel.org/gpu/amdgpu/display/dc-debug.html), [Ubuntu PSR-SU bug #2024774](https://bugs.launchpad.net/bugs/2024774), [Ubuntu PSR-SU disable #2046131](https://bugs.launchpad.net/bugs/2046131)

---

## 9. Suspend, Sleep, and Hibernate — Deep Dive

### 9.1 S3 vs S2idle

**S3 (deep sleep) does NOT exist on this laptop.** HP removed it from BIOS entirely. Only **s2idle** (Modern Standby / S0ix) is available ([HP Support — S3 Sleep Missing](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/S3-sleep-option-missing-in-HP-ZBook-Ultra-Z1a/td-p/9420909)).

### 9.2 Fixing S2idle

The two critical fixes for s2idle power drain:

1. **Disable the webcam in BIOS** — the ISP firmware (`isp_4_1_1.bin`) blocks the SMU from properly powering down the GPU during s2idle ([Kernel Bug #220702](https://bugzilla.kernel.org/show_bug.cgi?id=220702))
2. **Add `amd_iommu=off`** to kernel parameters ([HP Support — Suspend Issues](https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525))

With both fixes, [geohot achieved **0.14–0.20W** lid-closed idle](https://github.com/geohot/ztop) — approximately 15 days standby on the 74.5Wh battery. Without them, expect 10-15% battery drain overnight.

### 9.3 BIOS Settings for Suspend

All settings accessible via **F10** at boot:

| Setting | Recommended | Why |
|---|---|---|
| **Secure Boot** | **ENABLED** (default) | Disabling breaks suspend ([confirmed by users](https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525)) |
| **RAM Encryption (TSME)** | **ENABLED** (default) | Disabling breaks suspend |
| **Microsoft Pluton** | **ENABLED** (default) | All sources consistently report disabling breaks suspend ([HP Community](https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525), [Phoronix](https://www.phoronix.com/review/hp-zbook-ultra-g1a/3), [Julien Arnaud blog](https://blog.julienarnaud.fr/hp-zbook-ultra-g1a-ryzen-ai-max-395-linux.html)). Must stay enabled. |
| **Motion Sensing Cooling Mode** | **DISABLED** | Causes erratic fan behavior |
| **Webcam** | **DISABLED** (if you need sleep) | ISP firmware blocks s2idle |
| **BIOS defaults** | **Restore defaults first** | Fixes most suspend issues |

### 9.4 Security Caveat: `amd_iommu=off`

`amd_iommu=off` completely disables DMA protection from the IOMMU. This:
- Removes a security boundary against rogue PCIe device DMA attacks
- Prevents GPU/device passthrough to VMs
- **Disables the AMD NPU** (`amdxdna` requires IOMMU/SVA) — if you plan to use the NPU, you cannot use this flag
- **Alternative:** `iommu=pt` (passthrough mode) is less invasive — the IOMMU is still active but maps device addresses 1:1. However, **no source confirms `iommu=pt` actually fixes suspend on this laptop** — all hardware-specific guidance uses `amd_iommu=off`. Try `iommu=pt` first; fall back to `amd_iommu=off` if suspend still fails.

### 9.5 Webcam vs Sleep Tradeoff

**You currently cannot have both a working webcam AND proper s2idle.** The AMD ISP4 driver does not yet support proper suspend power management. When upstreamed (targeting kernel 7.1+), proper power state management should be included. Until then, you must choose:

- **Option A: Webcam ON + sleep broken** (10-15% overnight drain)
- **Option B: Webcam OFF (in BIOS) + sleep works** (0.14-0.20W)
- **Option C: Unload ISP4 before suspend** — untested but plausible: create a systemd sleep hook to `modprobe -r amd_isp4` before suspend and `modprobe amd_isp4` after resume (similar to the MT7925 WiFi workaround in 9.6). This avoids the BIOS toggle but requires the camera to reinitialize after every wake.

### 9.6 WiFi After Suspend Fix

MT7925 WiFi fails after suspend due to driver timeout (-110 error) ([Ubuntu Bug #2141198](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2141198)). Create a systemd hook to reload the module:

```bash
# Create /etc/systemd/system/wifi-suspend-fix.service
sudo tee /etc/systemd/system/wifi-suspend-fix.service << 'EOF'
[Unit]
Description=Reload MT7925 WiFi after suspend
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe mt7925e

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

# Create matching pre-suspend unload
sudo tee /etc/systemd/system/wifi-pre-suspend.service << 'EOF'
[Unit]
Description=Unload MT7925 WiFi before suspend
Before=sleep.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe -r mt7925e

[Install]
WantedBy=sleep.target
EOF

sudo systemctl enable wifi-suspend-fix.service wifi-pre-suspend.service
```

### 9.7 Screen Blank After Wake Fix

An amdgpu VRAM eviction bug can cause blank screen after wake. System is alive (SSH works).

- **Quick recovery:** `Ctrl+Alt+F2` then `Ctrl+Alt+F7` (forces GPU to reinitialize display)
- **Kernel parameter:** `amdgpu.gpu_recovery=1` may help, but has **mixed results** — some users report success, others no effect. Not a reliable fix for all cases.

### 9.8 Hibernate (Suspend-to-Disk)

Hibernate is technically possible but has complications:

- Requires swap >= RAM size (128GB for the max config)
- **Conflict:** The kernel hard-disables hibernate when Secure Boot is enabled. Since the ZBook Ultra G1a needs Secure Boot enabled for suspend to work, **you cannot have both Secure Boot and hibernate simultaneously**
- If you disable Secure Boot for hibernate, standard s2idle suspend may break

**Suspend-then-hibernate** would be ideal — instant s2idle wake for a configurable period, then automatic hibernate for zero drain. However, there is an **inherent conflict on this hardware**: kernel lockdown (from Secure Boot) disables hibernate, but Secure Boot must stay enabled for suspend to work reliably. This means suspend-then-hibernate **does not work out of the box** on this laptop.

If you disable Secure Boot to enable hibernate, standard s2idle suspend may break (see BIOS table above). This is currently an unresolved trade-off.

```bash
# Only works if you find a configuration where both Secure Boot
# and hibernate coexist (e.g., future kernel patches):
# /etc/systemd/sleep.conf
[Sleep]
AllowSuspendThenHibernate=yes
SuspendMode=suspend
HibernateMode=shutdown
HibernateDelaySec=30min
```

### 9.9 Complete Recommended Kernel Parameters

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_pstate=active amd_iommu=off pcie_aspm=off amdgpu.dcdebugmask=0x410"
```

| Parameter | Purpose |
|---|---|
| `amd_pstate=active` | Reduces idle power from 10-15W to 7-11W (down to 3-4W with GPU low-power extension) |
| `amd_iommu=off` | Fixes suspend (security tradeoff — see 9.4; also disables NPU) |
| `pcie_aspm=off` | Fixes GUI freezes (may lose Ethernet) |
| `amdgpu.dcdebugmask=0x410` | Fixes PSR/Panel Replay display freezes on X11 (see 8.12). Trade-off: higher idle power |

**Additional parameters for specific use cases:**

| Parameter | When to add |
|---|---|
| `resume=UUID=<swap-UUID>` | If using hibernate |
| `ttm.pages_limit=32505856` | For GPU compute with large unified memory (replaces deprecated `amdgpu.gttsize`) |
| `amdgpu.cwsr_enable=0` | Fix ROCm GPU hangs during AI/compute workloads ([ROCm #5590](https://github.com/ROCm/ROCm/issues/5590)). Only affects compute (CWSR = Compute Wave Save/Restore) — no impact on display or 3D rendering. |

After editing `/etc/default/grub`:
```bash
sudo update-grub && sudo reboot
```

---

## 10. Fan Noise and Thermal Management — Deep Dive

### 10.1 The Problem

Fans spin constantly at idle (~44-45 dB at idle, up to ~60 dB under load) with **10-15W PPT at idle** using default kernel settings. The warm palm rest is a known complaint across both Windows and Linux ([HP Support — High APU PPT](https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525), [HP Support — Fan Spikes](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/ZBook-Ultra-G1a-random-fan-spikes/td-p/9482254)).

### 10.2 Fix: `amd_pstate=active`

The single most impactful fix. Ubuntu 24.04 defaults to `amd_pstate=guided`, which keeps the CPU at higher power states.

```bash
# Add to /etc/default/grub GRUB_CMDLINE_LINUX_DEFAULT:
amd_pstate=active
```

| Mode | Idle Power | Notes |
|---|---|---|
| `guided` (default) | 10-15W | Higher base frequency, warmer |
| `active` | 7-11W | Hardware manages states; cooler, quieter |
| `active` + GPU low-power (via GNOME extension) | 3-4W | Lowest idle power; requires [Cool My Ryzen AI Max](https://github.com/AnnoyingTechnology/gnome-extension-cool-my-ryzen-ai-max) |

### 10.3 BIOS Settings

- **Disable "Motion Sensing Cooling Mode"** — causes erratic fan bursts based on accelerometer
- **Add +3 fan offset** — raises the temperature threshold before fans spin up

**Note:** BIOS version matters — version 1.03.00 was [reportedly much quieter than 1.03.02](https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525). **BIOS downgrade is blocked:** Attempting to revert from v1.03.02 to v1.03.00 fails with a "security policy violation" error, even with rollback policy set to permissive ([HP Support Community](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Zbook-ultra-G1a-fans-constantly-spinning-when-no-usage/td-p/9484899)).

### 10.4 Power Management Tools

**Monitoring:**
```bash
sudo apt install powertop
sudo powertop    # real-time power monitoring

# Or use turbostat for CPU state details
sudo turbostat --show PkgWatt,CorWatt,GFXWatt,Busy%,Bzy_MHz
```

**Auto-tuning:**
```bash
# Recommended: power-profiles-daemon (PPD) — best for AMD systems
# PPD is pre-installed on Ubuntu 24.04. Verify it's running:
sudo systemctl status power-profiles-daemon

# PPD v0.20+ supports multi-driver mode, controlling both
# platform_profile and amd_pstate simultaneously.
# Use GNOME Power settings or:
powerprofilesctl set balanced    # balanced / performance / power-saver
```

**Note:** [Framework recommends PPD over TLP for AMD systems](https://community.frame.work/t/tracking-ppd-v-tlp-for-amd-ryzen-7040/39423). TLP and auto-cpufreq are alternatives but may conflict with PPD — **do not run more than one simultaneously**. PPD integrates with the ZBook's ACPI `platform_profile` (balanced/performance/low-power), which [Phoronix benchmarked](https://www.phoronix.com/review/amd-strix-halo-platform-profile) showing the low-power profile reduces average power to ~32W (67% of default) while retaining 76% of performance.

### 10.5 Keyboard Backlight

[geohot measured the keyboard backlight draws **~2W**](https://geohot.github.io/blog/jekyll/update/2025/11/28/replacing-my-macbook.html) — a significant portion of the ~7W lid-open idle power. Disable or reduce it when on battery for meaningful power savings.

### 10.6 iGPU Low-Power Mode

Forcing the iGPU to `low` and dropping the CPU frequency floor to 1GHz reduces idle PPT from 7-11W to 3-4W.

**What it does:**
- `/sys/class/drm/card*/device/power_dpm_force_performance_level` → `low` (from `auto`)
- `/sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq` → `1000000` (from `2000000`)

**GNOME:** Install the [Cool My Ryzen AI Max](https://github.com/AnnoyingTechnology/gnome-extension-cool-my-ryzen-ai-max) extension.

**i3/CLI:** The dotfiles include `cool-ryzen-apply` (deployed by `install.sh` on ZBook hardware):
- **Manual toggle:** `$mod+p` or `sudo cool-ryzen-apply on|off`
- **Automatic:** A [udev rule](udev/85-cool-ryzen-ac.rules) enables power saver on battery and disables it on AC
- **Boot:** i3 config checks AC state at login and applies accordingly

**Note:** `power-profiles-daemon` does not write to `power_dpm_force_performance_level` — no conflict. When power saver is ON, GPU-heavy tasks will be slower (force it OFF with `$mod+p` before GPU workloads).

**Optional kernel parameter:** `workqueue.power_efficient=Y` routes deferred kernel work to power-efficient CPU cores. Minor additional power savings; slight cache locality cost. Not included in the default GRUB line — add manually if battery life is a priority.

---

## 11. Full Disk Encryption Setup — Deep Dive

### 11.1 Option A: Ubuntu Installer FDE (Simplest)

Ubuntu 24.04's installer supports FDE when you select "Erase disk and install Ubuntu":

1. Select "Erase disk and install Ubuntu"
2. Click **"Advanced features"**
3. Select **"Use LVM and encryption"**
4. Enter a security key (passphrase)
5. Proceed with installation

Creates: unencrypted EFI partition, unencrypted `/boot` (~1 GB), LUKS-encrypted LVM with root and swap ([TecMint guide](https://www.tecmint.com/encrypt-ubuntu-24-04-installation/)).

**Limitation:** Only works with "Erase entire disk" — no dual-boot or custom partitioning.

### 11.2 Option B: Manual LUKS + LVM (Full Control)

For custom partitioning ([Thomas Horsten guide](https://thomashorsten.substack.com/p/installing-ubuntu-2404-with-lukslvm)):

```bash
# Boot from Live USB, then:

# 1. Partition
gdisk /dev/nvme0n1
# p1: 512M EFI (EF00)
# p2: 1G /boot (8300)
# p3: rest for LUKS (8300)

# 2. Create LUKS container (optimal settings for AMD Zen 5 with AES-NI)
sudo cryptsetup luksFormat --type luks2 \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --hash sha256 \
  --pbkdf argon2id \          # Note: GRUB cannot unlock argon2id keyslots.
                               # Keep /boot unencrypted (recommended) or use
                               # a PBKDF2 keyslot if GRUB must unlock LUKS.
  --iter-time 2000 \
  --sector-size 4096 \
  --use-urandom /dev/nvme0n1p3

# 3. Open and create LVM
sudo cryptsetup open /dev/nvme0n1p3 cryptroot
sudo pvcreate /dev/mapper/cryptroot
sudo vgcreate vg0 /dev/mapper/cryptroot
sudo lvcreate -L 16G -n swap vg0      # adjust size; >=RAM for hibernate
sudo lvcreate -l 100%FREE -n root vg0
sudo mkfs.ext4 /dev/vg0/root
sudo mkswap /dev/vg0/swap

# 4. Run installer with "Something else" partitioning
# Point / to /dev/vg0/root, swap to /dev/vg0/swap,
# /boot to /dev/nvme0n1p2, EFI to /dev/nvme0n1p1

# 5. Post-install chroot to configure crypto
sudo mount /dev/vg0/root /mnt
sudo mount /dev/nvme0n1p2 /mnt/boot
sudo mount /dev/nvme0n1p1 /mnt/boot/efi
for d in proc sys dev dev/pts run; do sudo mount --bind /$d /mnt/$d; done
sudo chroot /mnt

# In chroot:
echo "cryptroot UUID=$(blkid -s UUID -o value /dev/nvme0n1p3) none luks,discard" >> /etc/crypttab
echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub
update-initramfs -u -k all
update-grub
exit
```

### 11.3 Cipher Choice for AMD Zen 5

| Cipher | Encrypt Speed | Decrypt Speed | Notes |
|---|---|---|---|
| `aes-xts-plain64` (512-bit key = AES-256) | Est. >10,000 MiB/s | Est. >10,000 MiB/s | Hardware-accelerated via AES-NI, industry standard |

*Note: Exact Zen 5 AES-XTS throughput has not been publicly benchmarked. Zen 1 achieves ~2,710 MiB/s/core; Zen 5 has ~35-45% IPC improvement plus wider pipelines, and [3.3x AES-CTR improvement patches](https://www.phoronix.com/news/3.3x-AES-CTR-AMD-Zen-5-Patches) were merged. Multi-core aggregate throughput easily exceeds NVMe bandwidth.*

CPU AES throughput far exceeds NVMe bandwidth (~7,000 MB/s). **Encryption should NOT be the bottleneck**, but real-world dm-crypt overhead can reduce speeds to ~2,000 MB/s due to workqueue overhead ([Cloudflare blog](https://blog.cloudflare.com/speeding-up-linux-disk-encryption/)). Use `--sector-size 4096` and `no-read-workqueue,no-write-workqueue` to minimize this (see 11.4).

### 11.4 Performance Tuning

Add to `/etc/crypttab` after the `none` field:

```
cryptroot UUID=<uuid> none luks,discard,no-read-workqueue,no-write-workqueue
```

The `--sector-size 4096` at format time is the single biggest performance win — up to 76% higher sequential throughput ([Fedora Wiki](https://fedoraproject.org/wiki/Changes/LUKSEncryptionSectorSize)).

**Sector size caveat:** The Ubuntu 24.04 GUI installer does not allow specifying `--sector-size`. cryptsetup ≥2.4.0 auto-detects from the NVMe's reported `physical_block_size`. If the drive reports 512-byte physical sectors (as the ZBook's 4TB NVMe does), you get 512. Post-install fix: `cryptsetup reencrypt --sector-size 4096` rewrites all encrypted data (slow and risky on 4TB — do a full backup first). For a fresh install, if the NVMe supports native 4K sectors, change the LBA format first with `nvme format --lbaf=1` (check `nvme id-ns` for supported formats).

**Persistent performance flags:** The `no-read-workqueue` / `no-write-workqueue` flags in `/etc/crypttab` depend on initramfs parsing. For belt-and-suspenders, store them persistently in the LUKS2 header:

```bash
sudo cryptsetup refresh --persistent --allow-discards \
  --perf-no_read_workqueue --perf-no_write_workqueue dm_crypt-0
```

Verify with: `sudo cryptsetup luksDump /dev/nvme0n1p3 | grep -A5 flags`

### 11.5 Clevis + TPM2: Automatic Unlock (Recommended for 24.04)

Since Ubuntu 24.04's native TPM FDE is experimental and **incompatible with the OEM kernel** (uses snap-based generic kernel), use [Clevis](https://github.com/latchset/clevis) with traditional LUKS for TPM-assisted automatic unlock:

```bash
# Install
sudo apt install clevis clevis-luks clevis-tpm2 clevis-initramfs

# Bind LUKS to TPM2 (seal to PCRs 1,4,5,7,9)
sudo clevis luks bind -d /dev/nvme0n1p3 tpm2 '{"pcr_ids":"1,4,5,7,9"}'

# Regenerate initramfs
sudo update-initramfs -u -k all
```

This gives you:
- **Automatic unlock at boot** when boot chain is unmodified (no passphrase)
- **Falls back to passphrase** if firmware/kernel changes
- **Works with the OEM kernel** (deb-based, not snap)
- **Compatible with AMD Pluton's TPM2 interface** (supported since [Linux 6.3](https://www.phoronix.com/news/Pluton-TPM-CRB-Merged-Linux-6.3))

**PCR selection guide:**

| PCR | Measures | Why include |
|---|---|---|
| 1 | Platform configuration | Detects hardware/firmware config changes |
| 4 | Boot manager code | Detects bootloader tampering |
| 5 | Boot manager configuration | Detects GRUB config changes |
| 7 | Secure Boot policy | Detects Secure Boot changes |
| 9 | initramfs hash | Detects initramfs tampering — **changes on every kernel/initramfs update**, requiring re-binding |

**Important:** PCR 9 provides strong integrity but **breaks auto-unlock on every kernel or initramfs update** (you must re-run `clevis luks bind`). For a less fragile setup, use only **PCR 7** (or PCR 1+7) — you trade some security for not having to re-bind after every `apt upgrade`. Choose based on your threat model.

**Alternative to Clevis:** [`systemd-cryptenroll`](https://www.freedesktop.org/software/systemd/man/systemd-cryptenroll.html) is a modern, faster alternative (bundled with systemd, no extra dependencies, faster boot unlock). It works best with `dracut` rather than `initramfs-tools`. For Ubuntu 24.04's default initramfs-tools setup, Clevis remains the easier path.

### 11.6 Ubuntu 24.04 Experimental TPM FDE — Why NOT to Use It

Ubuntu 24.04 includes experimental TPM-backed FDE ([Ubuntu docs](https://documentation.ubuntu.com/desktop/en/24.04/explanation/hardware-backed-disk-encryption/)) but:

- **Uses snap-delivered generic kernel** — incompatible with the OEM kernel the ZBook G1a needs
- **Experimental / not production-ready** — Canonical warns: "Use it only on systems where you don't mind if you accidentally lose your data"
- **No external kernel modules** (NVIDIA, out-of-tree drivers)

Use Clevis + LUKS instead (11.5).

### 11.7 TSME and LUKS — Complementary Protection

The ZBook Ultra G1a's AMD TSME (Transparent Secure Memory Encryption) and LUKS operate at different layers ([AMD Memory Encryption docs](https://docs.kernel.org/arch/x86/amd-memory-encryption.html)):

| Layer | Technology | Protects Against |
|---|---|---|
| Disk (at rest) | LUKS FDE | Physical disk theft, offline data extraction |
| RAM (in use) | TSME | Cold boot attacks, physical RAM snooping |

TSME encrypts ALL system RAM with a key generated randomly by the AMD Secure Processor at each boot, requiring no OS involvement. Starting with Zen 4, AMD upgraded from 128-bit AES to **256-bit AES-XTS** ([Phoronix — AMD SME Genoa](https://www.phoronix.com/review/amd-sme-genoa)). The Strix Halo (Zen 5) in the ZBook Ultra G1a uses 256-bit AES-XTS. AMD brands this as "Memory Guard" on PRO processors. LUKS keys in RAM are themselves encrypted by TSME.

Performance impact: ~0.7% average on EPYC servers ([Cloudflare benchmark](https://blog.cloudflare.com/securing-memory-at-epyc-scale/)). However, [Phoronix tested the actual Ryzen AI Max+ PRO 395](https://www.phoronix.com/review/amd-memory-guard-ram-encrypt) and found "measurable impact" on some workloads; AMD's own whitepaper cites 3.4% on PCMark 10. Since TSME must stay enabled for suspend to work, you get this protection "for free."

**Verify TSME from Linux (no BIOS needed):** `sudo dmesg | grep -i "Memory Encryption"` — if TSME is active, output shows `Memory Encryption Features active: AMD SME`. Note: the kernel does not distinguish TSME from SME in dmesg output; TSME is transparent to the OS. For definitive verification, AMD provides a test kernel module at [AMDESE/mem-encryption-tests](https://github.com/AMDESE/mem-encryption-tests) (build, load, read `/sys/kernel/tsme`). Warning: `fwupdmgr security --force` can falsely report "Encrypted RAM: Enabled" even when TSME is off ([fwupd #4176](https://github.com/fwupd/fwupd/issues/4176)).

### 11.8 LUKS Header Backup (Critical)

```bash
# Backup header
sudo cryptsetup luksHeaderBackup /dev/nvme0n1p3 \
  --header-backup-file luks-header-backup.img

# Encrypt the backup
gpg --symmetric --cipher-algo AES256 luks-header-backup.img

# Securely delete unencrypted copy
shred -u luks-header-backup.img

# Store .gpg file on separate USB, cloud, or safe

# Also add a recovery passphrase to key slot 1
sudo cryptsetup luksAddKey --key-slot 1 /dev/nvme0n1p3

# Test recovery passphrase (IMPORTANT: do this before relying on it)
sudo cryptsetup open --test-passphrase --key-slot 1 --verbose /dev/nvme0n1p3
# Expected: "Key slot 1 unlocked. Command successful."
```

**Important:** Always create the header backup AFTER adding the recovery key — the backup captures keyslot state at time of backup. A backup made before adding the recovery key won't contain it.

### 11.9 FDE Decision Matrix

| Approach | Complexity | OEM Kernel Compatible | Passphrase-less Boot | Production Ready | Recommended? |
|---|---|---|---|---|---|
| **Installer FDE (LUKS+LVM)** | Low | Yes | No | Yes | **Yes — simplest** |
| Manual LUKS+LVM | High | Yes | No | Yes | If custom partitioning needed |
| **Clevis + LUKS + TPM2** | Medium | Yes | Yes | Yes | **Yes — best TPM option for 24.04** |
| Ubuntu 24.04 TPM FDE (experimental) | Low | **No** | Yes | **No** | **No** |
| Post-install encryption | Very High | Yes | No | Risky | Only if reinstall impossible |
| Wait for Ubuntu 26.04 TPM FDE | N/A | TBD | Yes | Expected GA | Evaluate when released |

---

## 12. Other Linux Distributions — Comparison

### 12.1 Fedora 42/43

**Kernel:** Shipped 6.14 (April 2025); rolling updates to 6.19.7 within F42's lifecycle.

**General experience:** [Phoronix confirmed](https://www.phoronix.com/review/hp-zbook-ultra-g1a/2) it works "well out-of-the-box." [HN users](https://news.ycombinator.com/item?id=45256880) report daily-driving it for containers/Kubernetes development.

**Webcam:** Does NOT work. ISP4 not in any mainline kernel yet.

**ROCm:** Not officially supported by AMD on Fedora. Community packages via [Fedora HC SIG](https://fedoraproject.org/wiki/SIGs/HC) (ROCm 6.3 on F42, 6.4.4 on F43). AMD's official Strix Halo docs now list [Fedora 43 for native ROCm](https://rocm.docs.amd.com/en/latest/how-to/system-optimization/strixhalo.html). Containerized workarounds exist.

**Known issues:** Bluetooth toggling bug ([Fedora Discussion](https://discussion.fedoraproject.org/t/bluetooth-toggling-off-immediately-after-trying-to-turn-it-on/163260)). Set `amdgpu.cwsr_enable=0` for ROCm stability. Avoid `linux-firmware-20251125` (breaks ROCm).

### 12.2 Arch Linux

The [Level1Techs guide](https://forum.level1techs.com/t/the-ultimate-arch-secureboot-guide-for-ryzen-ai-max-ft-hp-g1a-128gb-8060s-monster-laptop/230652) is the definitive resource — "The Ultimate Arch + Secureboot Guide for Ryzen AI Max."

- **Secure Boot:** Works via `sbctl` key generation and signing
- **BTRFS:** Subvolumes with zstd compression and Snapper rollback
- **Fingerprint reader:** Works flawlessly with `fprintd`
- **WiFi:** Requires kernel 6.14.3+ and `linux-firmware` from May 2025+
- **Webcam:** [`amdisp4-dkms`](https://github.com/iglooom/AMD-ISP4-kernel-patches) AUR package available, but ISP driver doesn't fully bind on 6.16+
- **GPU compute:** Vulkan backend outperforms HIP. DeepSeek R1 70B Q4 at ~5.5 t/s
- **Most stable kernel for sleep:** 6.14.9 — newer kernels (6.15/6.16) regressed
- [Gentoo Wiki](https://wiki.gentoo.org/wiki/User:Owenwastaken/HP_ZBook_Ultra_G1a) documents the hardware thoroughly

### 12.3 NixOS

[NixOS Discourse threads](https://discourse.nixos.org/t/hp-zbook-ultra-g1a/69595) from NixCon 2025: Multiple attendees running ZBook G1a's.

- **Webcam:** Community member created [**`srhb/isp4-nixos`**](https://github.com/srhb/isp4-nixos) — a NixOS module for ISP4 webcam support, described as "working fine (beta software)." One of only two distro-specific webcam solutions.
- **WiFi:** Works on kernel 6.17+ but MT7925 caused complete lockups at NixCon (edge-case WiFi)
- **Declarative advantages:** Kernel parameters, out-of-tree patches, firmware overrides, and exact kernel version pinning — all version-controlled and reproducible
- **ROCm:** Available via `pkgsRocm` in nixpkgs (community-maintained, updated to ROCm 7.1.1 in nixpkgs-unstable). Not AMD-official but functional.

### 12.4 CachyOS

[Phoronix included CachyOS](https://www.phoronix.com/review/hp-zbook-ultra-g1a/2) in their 7-way distribution comparison on this laptop.

- **Optimized kernel:** BORE scheduler, sched-ext, AMD P-State EPP, AVX-512 enabled — 5-10% performance gains
- **Known issues:** Random Xorg freezes during install. **KDE is significantly more stable than GNOME** on Strix Halo ([CachyOS forum](https://discuss.cachyos.org/t/installer-crash-on-strix-halo-laptop/13980))
- **Workarounds:** Disable Secure Boot temporarily, disable Adaptive Sync, boot with `amdgpu.dcdebugmask=0x410`, or use Wayland
- **AUR:** Same `amdisp4-dkms` package available for webcam

### 12.5 Debian 13 "Trixie"

- **Kernel:** Ships Linux 6.12 LTS — below the 6.18.4 threshold for stable ROCm
- **Suspend:** **Broken** — s2idle wakeup produces endless `amd-pmf` error loops ([blog post on HP EliteBook 8 G1a, same platform](https://blog.frehi.be/2025/12/30/debian-gnu-linux-on-a-hp-elitebook-hp-elitebook-8-g1a-14))
- Author concluded: "For a laptop it's an essential thing to have sleep and wake-up working reliably, and this is not the case"
- **ROCm:** AMD officially supports Debian 13 with ROCm 7.0.2, but **only for Instinct datacenter GPUs** (MI300X, MI325X, etc.) — the Strix Halo iGPU is NOT officially supported on Debian. Kernel is also suboptimal (6.12 < 6.18.4 stability threshold).

### 12.6 Pop!_OS 24.04

- Shipped kernel 6.17.9 at launch (December 2025), updated to 6.18.7 via post-release updates. Mesa 25.1.5, COSMIC desktop (Rust-based, replaces GNOME entirely)
- **No specific testing or community reports found** for the ZBook Ultra G1a
- Does NOT carry the Ubuntu OEM kernel (no webcam)
- Untested but plausible

### 12.7 Red Hat Enterprise Linux 10

- [Red Hat certified](https://catalog.redhat.com/en/hardware/system/detail/282387) for RHEL 10.0-10.x
- **Only distro where AMD officially supports ROCm AND the laptop is vendor-certified**
- Strongest choice for enterprise GPU compute
- ISP4 webcam not in RHEL's conservative kernel

### 12.8 Comparison Matrix

| Feature | Ubuntu 24.04 OEM | Fedora 42 | Arch | NixOS | CachyOS | Debian 13 | RHEL 10 |
|---|---|---|---|---|---|---|---|
| **Webcam (ISP4)** | **Works** | No | AUR (partial) | **Module (beta)** | AUR (partial) | No | No |
| **WiFi (MT7925)** | Works | Works; BT bug | Works | Works; edge issues | Works | Works | Certified |
| **Suspend/Sleep** | With tweaks | Mixed | 6.14.9 best | Underdocumented | Underdocumented | **Broken** | Unknown |
| **ROCm / GPU** | AMD pkgs | Community | AUR/manual | pkgsRocm | AUR; optimized | AMD-supported | **AMD official** |
| **FDE (LUKS)** | Yes | Yes | Yes (guide) | Yes (declarative) | Yes | Yes | Yes |
| **Ease of Setup** | Easy | Easy | Hard | Hard | Medium | Medium | Medium |
| **Kernel** | 6.17.x (OEM) | 6.19.x | Rolling | Channel-dep. | 6.19 | 6.12 | ~6.12 |
| **Community Docs** | HP forums, Canonical | Fedora forums | **Level1Techs** | NixOS Discourse | CachyOS forum | Blog post | Enterprise |
| **Secure Boot** | Shim-signed | Shim-signed | `sbctl` | Manual | Works | Shim-signed | Certified |
| **LVFS/fwupd** | Yes | Yes | Yes | Yes | Yes | Yes | Yes |

### 12.9 Recommendation by Use Case

| Use Case | Best Choice | Runner-Up |
|---|---|---|
| **Webcam working today** | **Ubuntu 24.04 OEM kernel** | NixOS + `isp4-nixos` |
| **General workstation** | **Fedora 42/43** | Arch Linux |
| **Maximum performance / LLM** | **CachyOS** | Arch Linux |
| **Reproducible config** | **NixOS** | — |
| **Enterprise / certified** | **RHEL 10** | Ubuntu 24.04 LTS |
| **Avoid** | Debian 13 (kernel too old, suspend broken) | Pop!_OS (untested) |

---

## 13. Complete Hardware Status Matrix

| Component | Status | Kernel Req. | Notes |
|---|---|---|---|
| CPU (Ryzen AI Max+ PRO 395) | Works | 6.14+ | `amd_pstate=active` recommended |
| GPU (Radeon 8050S/8060S) | Works | 6.14+ / Mesa 25.0+ | amdgpu; ROCm improving |
| Display (2.8K OLED 120Hz) | Works | 6.14+ | Fractional scaling at 150-175% in GNOME/Wayland. 400 nits max, DCI-P3 100%. PWM dimming present. |
| Webcam (5MP IR, AMD ISP4) | **OEM kernel only** | OEM 6.11+ | Not mainline until ~Linux 7.1+. Requires libcamera with ISP4 pipeline handler from `ppa:amd-team/isp` (stock Noble libcamera 0.2.0 lacks it). Not a standard V4L2 device — uses media-controller API. |
| WiFi (MediaTek MT7925) | Works (with caveats) | 6.14.3+ | `pcie_aspm=off` may be needed; dies after suspend |
| Bluetooth (MT7925) | Works | 6.14+ | May need BIOS toggle to reset |
| NVMe Storage | Works | any | Standard nvme driver |
| Audio (Cirrus Logic amp) | Works | 6.14+ | Degraded quality vs Windows |
| Fingerprint Reader (Synaptics) | Works | any | [libfprint](https://launchpad.net/ubuntu/+source/libfprint/+bug/2058193); `fprintd-enroll` |
| Touchpad (Synaptics) | Works | any | Requires [libinput config for i3/X11](#14-input-device-configuration-for-i3x11) — GNOME configures automatically |
| Touchscreen (ELAN) | Works | any | On OLED model only |
| Thunderbolt 4 | Works | 6.14+ | Dock disconnection bug with >90W PD |
| NPU (XDNA 2, 50 TOPS) | **Not usable** | 6.14+ | Kernel driver exists; userspace stack not ready. Note: `amd_iommu=off` (needed for suspend) also disables the NPU. |
| Suspend (s2idle) | **Broken without tweaks** | — | See [Section 9](#9-suspend-sleep-and-hibernate--deep-dive) |
| Hibernate | **Conflicts with Secure Boot** | — | Kernel lockdown disables hibernate when Secure Boot is on; but Secure Boot is needed for suspend. Unresolved trade-off. See [Section 9.8](#98-hibernate-suspend-to-disk) |
| LVFS/fwupd | Works | — | BIOS + PD firmware updates from Linux |
| Secure Boot | Works | — | OEM kernel is signed; keep enabled |
| TPM 2.0 / Pluton | Works | 6.3+ | Must stay enabled — disabling breaks suspend (see Section 9.3) |
| Function/Media Keys | Works (needs i3 config) | any | Brightness requires `video` group; keyboard backlight is firmware-handled. See [Section 14](#14-input-device-configuration-for-i3x11) |

---

## 14. Input Device Configuration for i3/X11

GNOME's `gnome-settings-daemon` automatically configures the touchpad (tap-to-click, clickfinger, natural scrolling) and keyboard options. When running i3 or another standalone WM on X11, these must be configured manually.

### Touchpad

Create `/etc/X11/xorg.conf.d/30-touchpad.conf`:

```
Section "InputClass"
    Identifier "touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
    Option "TappingButtonMap" "lrm"
    Option "TappingDragLock" "on"
    Option "NaturalScrolling" "off"
    Option "ClickMethod" "clickfinger"
EndSection
```

| Option | Default | Set to | Why |
|---|---|---|---|
| Tapping | off | on | 1-finger tap = left click |
| TappingButtonMap | lrm | lrm | 2-finger tap = right click, 3-finger = middle |
| TappingDragLock | off | on | Lift and reposition finger mid-drag without releasing |
| NaturalScrolling | off | off | Swipe down = content moves up (traditional) |
| ClickMethod | buttonareas | clickfinger | 2-finger physical click = right click (recommended by [libinput docs](https://wayland.freedesktop.org/libinput/doc/latest/clickpad-softbuttons.html)) |

Settings left at defaults (already optimal): `DisableWhileTyping` (on), `TappingDrag` (on), `AccelProfile` (adaptive), `AccelSpeed` (0.0), `ScrollMethod` (twofinger), `ScrollingPixelDistance` (15).

No conflict with `/usr/share/X11/xorg.conf.d/40-libinput.conf` — that file only assigns the driver, sets no options. Custom files in `/etc/X11/xorg.conf.d/` take precedence.

**Sources:** [ArchWiki — libinput](https://wiki.archlinux.org/title/Libinput), [libinput(4) man page](https://man.archlinux.org/man/libinput.4.en)

### Keyboard

The ZBook Ultra G1a's physical keyboard layout has the bottom-left row ordered CTRL > FN > WIN > ALT, making Ctrl+shortcuts and especially Ctrl+Alt+shortcuts uncomfortable. Remapping Caps Lock to Ctrl puts a Ctrl key on the home row.

Update `/etc/default/keyboard`:
```
XKBOPTIONS="ctrl:nocaps,compose:ralt,terminate:ctrl_alt_bksp"
```

Then apply: `sudo dpkg-reconfigure -f noninteractive keyboard-configuration`

Also update the `setxkbmap` line in the i3 config to match:
```
exec --no-startup-id setxkbmap -layout us -option ctrl:nocaps,compose:ralt,terminate:ctrl_alt_bksp
```

| Option | Effect |
|---|---|
| `ctrl:nocaps` | Caps Lock becomes Ctrl — home-row Ctrl for all shortcuts |
| `compose:ralt` | Right Alt becomes Compose key — type accented chars (Compose → ' → e = é) |
| `terminate:ctrl_alt_bksp` | Ctrl+Alt+Backspace kills X server — emergency escape hatch |

**Sources:** [ArchWiki — Xorg/Keyboard](https://wiki.archlinux.org/title/Xorg/Keyboard_configuration), [xkeyboard-config(7)](https://manpages.ubuntu.com/manpages/noble/man7/xkeyboard-config.7.html)

### Verification

```bash
# Touchpad
xinput list-props "SYNA3133:00 06CB:CFE2 Touchpad" | grep -E "Tapping Enabled|Click Method|Natural Scrolling"
# Expected: Tapping Enabled: 1, Click Method Enabled: 0, 1, Natural Scrolling Enabled: 1

# Keyboard
setxkbmap -query | grep options
# Expected: ctrl:nocaps,compose:ralt,terminate:ctrl_alt_bksp
```

### Trackpad Gestures (libinput-gestures)

GNOME provides built-in 3/4-finger swipe gestures for workspace switching. On i3, install [`libinput-gestures`](https://github.com/bulletmark/libinput-gestures) to get similar functionality.

```bash
sudo apt install libinput-gestures libinput-tools xdotool wmctrl
sudo gpasswd -a $USER input  # required — log out/in after
```

Create `~/.config/libinput-gestures.conf`:
```conf
# i3 workspace switching — 3-finger swipes
gesture swipe left  3 i3-msg workspace next
gesture swipe right 3 i3-msg workspace prev
gesture swipe up    3 i3-msg fullscreen toggle
gesture swipe down  3 i3-msg floating toggle

# Move container to adjacent workspace — 4-finger swipes
gesture swipe left  4 i3-msg move container to workspace next, workspace next
gesture swipe right 4 i3-msg move container to workspace prev, workspace prev

# Pinch to zoom (browsers, terminals, etc.)
gesture pinch in    xdotool key ctrl+minus
gesture pinch out   xdotool key ctrl+plus
```

Enable and start:
```bash
libinput-gestures-setup autostart
libinput-gestures-setup start
```

Add to i3 config: `exec --no-startup-id libinput-gestures-setup start`

**Sources:** [libinput-gestures](https://github.com/bulletmark/libinput-gestures), [ArchWiki — libinput](https://wiki.archlinux.org/title/Libinput)

### i3 Desktop Services & Media Keys

GNOME's `gnome-settings-daemon` handles media keys (brightness, volume, mic mute, media player), screen locking, PolicyKit authentication, and DPI scaling automatically. In i3, each must be configured explicitly.

**i3 parser limitation:** i3 treats `;` and `,` as command separators ([i3/i3#2460](https://github.com/i3/i3/issues/2460)). Compound shell commands (using `;`, `if/then`, etc.) inside `exec` will break. The workaround is double-quoting with `\\"` escapes, but for anything non-trivial, use a helper script instead. The dotfiles use `~/.i3/media-keys.sh` for volume/brightness with OSD notifications via dunstify.

#### Brightness

The backlight device (`/sys/class/backlight/amdgpu_bl1/brightness`) is owned by `root:video` with `664` permissions. The user must be in the `video` group for `brightnessctl` to work without root.

```bash
sudo usermod -aG video $USER  # log out/in after
```

In i3 config (via `~/.i3/media-keys.sh` which adds OSD notifications):
```
bindsym XF86MonBrightnessUp exec --no-startup-id ~/.i3/media-keys.sh brightness-up
bindsym XF86MonBrightnessDown exec --no-startup-id ~/.i3/media-keys.sh brightness-down
```

Under the hood, the script runs `brightnessctl` then shows the current level via `dunstify`:
- `brightnessctl -c backlight set +5%` / `brightnessctl -c backlight --min-value=1 set 5%-`

| Flag | Purpose |
|---|---|
| `--no-startup-id` | Prevents 60-second busy cursor (CLI tools never send X11 startup notification) |
| `-c backlight` | Targets only backlight class; avoids LED devices; survives device name changes across kernels (`amdgpu_bl0` → `amdgpu_bl1`) |
| `--min-value=1` | Prevents setting brightness to 0 (completely black screen, unrecoverable without SSH) |

**Keyboard backlight (F5):** No sysfs LED is exposed (`/sys/class/leds/` has no `kbd_backlight`). The keyboard backlight toggle is handled entirely by firmware/EC — no i3 binding needed.

#### Volume & Mic Mute

In i3 config (via `~/.i3/media-keys.sh` which adds OSD notifications):
```
bindsym XF86AudioRaiseVolume exec --no-startup-id ~/.i3/media-keys.sh volume-up
bindsym XF86AudioLowerVolume exec --no-startup-id ~/.i3/media-keys.sh volume-down
bindsym XF86AudioMute exec --no-startup-id ~/.i3/media-keys.sh volume-mute
bindsym XF86AudioMicMute exec --no-startup-id ~/.i3/media-keys.sh mic-mute
```

Under the hood: `pamixer -i 5` / `pamixer -d 5` for volume, `pactl set-sink-mute @DEFAULT_SINK@ toggle` for mute, `pactl set-source-mute @DEFAULT_SOURCE@ toggle` for mic mute.

Ubuntu 24.04 uses PipeWire with PulseAudio compatibility. Both `pamixer` and `pactl` work via `pipewire-pulse`.

#### Media Player Controls

Use `playerctl` (the i3 community standard for MPRIS media controls). Works with any player (Spotify, Firefox, VLC, etc.):

```bash
sudo apt install playerctl
```

```
bindsym XF86AudioPlay exec --no-startup-id playerctl play-pause
bindsym XF86AudioStop exec --no-startup-id playerctl stop
bindsym XF86AudioPrev exec --no-startup-id playerctl previous
bindsym XF86AudioNext exec --no-startup-id playerctl next
```

#### Screen Lock (xss-lock)

Without `xss-lock`, the screen is NOT locked on suspend/lid close — a security hole. `xss-lock` intercepts systemd's "prepare for sleep" signal and launches i3lock before suspend completes.

```
exec --no-startup-id xss-lock --transfer-sleep-lock -- i3lock --nofork --color 475263
bindsym $mod+c exec --no-startup-id loginctl lock-session
```

`--transfer-sleep-lock` holds a systemd inhibitor so suspend waits until i3lock is ready. `--nofork` is required for xss-lock to track the i3lock process. The manual `$mod+c` binding uses `loginctl lock-session` which xss-lock intercepts, avoiding conflicting i3lock instances.

#### PolicyKit Authentication Agent

Without a polkit agent, GUI apps that need privilege escalation (mounting drives, managing printers, etc.) silently fail.

```bash
sudo apt install policykit-1-gnome
```

```
exec --no-startup-id /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1
```

#### DPI

GDM does not source `~/.xinitrc` — it launches i3 directly via `/usr/share/xsessions/i3.desktop`. Set DPI in i3 config instead:

```
exec --no-startup-id xrandr --dpi 96
```

#### Display Output Names

AMD amdgpu uses different output names than Intel:

| Intel (old) | AMD amdgpu (this laptop) |
|---|---|
| `eDP1` | `eDP` |
| `HDMI2` | `HDMI-A-0` |
| `DP1` | `DisplayPort-0` through `DisplayPort-6` |

Verify with `xrandr --query`. Update workspace assignments in i3 config accordingly.

**Sources:** [ArchWiki — i3](https://wiki.archlinux.org/title/I3), [ArchWiki — Backlight](https://wiki.archlinux.org/title/Backlight), [ArchWiki — Session lock](https://wiki.archlinux.org/title/Session_lock), [i3 FAQ — multimedia keys](https://faq.i3wm.org/question/3747/enabling-multimedia-keys.1.html), [playerctl](https://github.com/altdesktop/playerctl)

### What this does NOT fix

**Kinetic (momentum) scrolling** — GNOME/mutter implements this at the compositor level. libinput deliberately does not provide it. On i3/X11, scrolling stops immediately when fingers lift. This is the one remaining "feel" gap vs GNOME that cannot be fixed with input configuration.

---

## 15. Recommended Setup — Step by Step

### If your current HP OEM install works

```bash
# 1. Update to latest OEM kernel
sudo apt install linux-oem-24.04

# 2. Apply kernel parameters
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_pstate=active amd_iommu=off pcie_aspm=off amdgpu.dcdebugmask=0x410"/' /etc/default/grub
sudo update-grub

# 3. Update firmware
sudo fwupdmgr refresh
sudo fwupdmgr get-updates
sudo fwupdmgr update

# 4. WiFi suspend fix
sudo tee /etc/systemd/system/wifi-suspend-fix.service << 'EOF'
[Unit]
Description=Reload MT7925 WiFi after suspend
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe mt7925e
[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

sudo tee /etc/systemd/system/wifi-pre-suspend.service << 'EOF'
[Unit]
Description=Unload MT7925 WiFi before suspend
Before=sleep.target
[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe -r mt7925e
[Install]
WantedBy=sleep.target
EOF

sudo systemctl enable wifi-suspend-fix.service wifi-pre-suspend.service

# 5. Input device configuration (i3/X11 only — skip if using GNOME)
# See Section 14 for details
sudo tee /etc/X11/xorg.conf.d/30-touchpad.conf > /dev/null << 'EOF'
Section "InputClass"
    Identifier "touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
    Option "TappingButtonMap" "lrm"
    Option "TappingDragLock" "on"
    Option "NaturalScrolling" "off"
    Option "ClickMethod" "clickfinger"
EndSection
EOF

sudo sed -i 's/^XKBOPTIONS=.*/XKBOPTIONS="ctrl:nocaps,compose:ralt,terminate:ctrl_alt_bksp"/' /etc/default/keyboard
sudo dpkg-reconfigure -f noninteractive keyboard-configuration

# 6. i3 desktop services (i3/X11 only — skip if using GNOME)
# See Section 14 "i3 Desktop Services & Media Keys" for details
sudo apt install playerctl xss-lock policykit-1-gnome
sudo usermod -aG video "$USER"  # required for brightnessctl backlight access

# 7. Webcam (AMD ISP4 — requires libcamera with ISP4 pipeline handler)
sudo add-apt-repository -y ppa:amd-team/isp
sudo apt-get update
sudo apt-get install -y v4l-utils libcamera-tools libspa-0.2-libcamera \
  gstreamer1.0-libcamera gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-gl xdg-desktop-portal xdg-desktop-portal-gnome
# Verify: cam -l (should list ISP4 camera)
# Browser config:
#   Firefox: about:config → media.webrtc.camera.allow-pipewire = true
#   Brave:   brave://flags/#enable-webrtc-pipewire-camera → Enabled

# 8. Reboot
sudo reboot
```

### If you want a fresh start with FDE

1. **Download HP OEM ISO** from [HP Support](https://support.hp.com/us-en/drivers/hp-zbook-ultra-g1a-14-inch-mobile-workstation-pc/2102737532) — **keep a backup copy** (no recovery partition exists)
2. Or use stock Ubuntu 24.04 ISO and install `linux-oem-24.04` afterward
3. During install: select "Erase disk" → "Advanced features" → "Use LVM and encryption"
4. After install, apply steps 1-6 above
5. Optionally set up Clevis + TPM2 (see [Section 11.5](#115-clevis--tpm2-automatic-unlock-recommended-for-2404))

### BIOS tweaks (F10 at boot)

- **Disable "Motion Sensing Cooling Mode"** — reduces fan bursts
- **Add +3 fan offset** — quieter idle
- **Create custom boot entry** → `EFI\ubuntu\shimx64.efi` (if GRUB not detected)
- **Keep Secure Boot, RAM encryption, and Pluton ENABLED** — disabling any of these breaks suspend (see Section 9.3)
- **Disable webcam** (if you prioritize sleep over webcam)

### Do NOT

- Attempt a major version upgrade from 24.04 → 25.x (breaks OEM kernel track)
- Use a 65W USB-C charger (firmware-enforced minimum; won't charge)
- Disable Secure Boot, RAM encryption, or Pluton (all three must stay enabled — disabling any of them breaks suspend)
- Use `linux-image-oem-24.04c` — use `linux-oem-24.04` (the rolling meta-package) instead
- Use Ubuntu 24.04's experimental TPM FDE (incompatible with OEM kernel)

---

## 16. HP Wolf Security — Linux Compatibility and Reinstall Safety

HP Wolf Security is HP's enterprise security platform. Understanding what it does — and what it doesn't do — on Linux is critical before deciding whether to reinstall or tweak your setup.

### What Is HP Wolf Security?

HP Wolf Security is a **collection of hardware and software security features** layered across the firmware and OS. Some are hardware-level (built into the BIOS/firmware chip), others are software agents that run in the OS. The hardware components are **OS-independent and survive any disk wipe**. The software components are **Windows-only**.

### Component Matrix

| Component | Layer | Linux Compatible? | Notes |
|---|---|---|---|
| **Embedded Security Controller (ESC)** | Hardware (separate chip) | Yes — OS-independent | Provides tamper-resistant key storage, TPM 2.0 functionality |
| **Sure Start** | Firmware (BIOS) | Yes — OS-independent | BIOS self-healing: maintains a "golden copy" on a physically isolated SPI flash chip. Validates BIOS at every boot and auto-restores from golden copy if corruption detected ([HP Sure Start whitepaper](https://h20195.www2.hp.com/v2/getpdf.aspx/4AA5-4453ENW.pdf)) |
| **Sure Admin** | Firmware (BIOS) | Yes — OS-independent | Remote BIOS management via cryptographic signatures |
| **Runtime Intrusion Detection** | Firmware (SMM) | Yes — OS-independent | Monitors System Management Mode memory for attacks at runtime |
| **Sure Run** | Software (Windows agent) | **No** — Windows only | Monitors and restarts critical Windows security processes |
| **Sure Click** | Software (Windows agent) | **No** — Windows only | Micro-VM browser isolation (based on Bromium/Xen) |
| **Sure Sense** | Software (Windows agent) | **No** — Windows only | AI-based malware detection |
| **Sure Recover** | Firmware + Software | **Partial** — firmware is OS-independent, but recovery image is Windows only | Network-based OS recovery. The firmware component (which initiates network boot) works regardless of OS, but the recovery image it fetches is a Windows image. **There is no HP recovery partition on the Ubuntu variant.** |

### Key Finding: No HP Recovery Partition on Ubuntu

The Ubuntu variant of the ZBook Ultra G1a does **not** have an HP recovery partition. Sure Recover's network recovery fetches a Windows image. This means:

- **You cannot "break" an HP recovery partition by reinstalling** — there isn't one
- **To recover Ubuntu**, you need the HP OEM ISO: download it from [HP Support](https://support.hp.com/us-en/drivers/hp-zbook-ultra-g1a-14-inch-mobile-workstation-pc/2102737532) (select "Linux" as OS, filename: `stella-noble-oem-24.04b-20250422-107.iso`)
- **Keep a copy of this ISO** — it's your only recovery path for the OEM Ubuntu configuration

### Critical BIOS Setting: Sure Start Secure Boot Keys Protection

**This is the most important Wolf Security setting for Linux users.**

Sure Start includes a feature called **"Secure Boot Keys Protection"** that locks down the Secure Boot key database (db/dbx/KEK/PK). When enabled, it can **prevent Linux bootloaders from being enrolled** and cause **infinite boot loops** if the Secure Boot database is modified outside of HP's expected flow.

**Symptoms of this bug:**
- Boot loop after installing Linux or modifying Secure Boot keys
- GRUB/shim fails to boot despite being properly signed
- System cycles between BIOS and attempted boot endlessly

**Fix:**
1. Enter BIOS (F10 at boot)
2. Navigate to **Security → BIOS Sure Start** (not "Secure Boot Configuration" — these are separate subsections)
3. **Disable "Secure Boot Keys Protection"** (or "Protect Secure Boot Keys")
4. Save and exit
5. Now install/configure Linux normally
6. You can optionally re-enable it after confirming your bootloader works

**Note:** Disabling this setting does NOT disable Secure Boot itself — it only stops Sure Start from locking the key database. Secure Boot should remain **enabled** (needed for proper suspend behavior on this hardware).

Sources: [Level1Techs forum](https://forum.level1techs.com/t/the-ultimate-arch-secureboot-guide-for-ryzen-ai-max-ft-hp-g1a-128gb-8060s-monster-laptop/230652), [HP Support Community](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/HP-ZBook-Ultra-G1a-Linux-Secure-Boot/td-p/9375051)

### BIOS Golden Copy — Safe From Disk Operations

The Sure Start "golden copy" of the BIOS is stored on a **physically isolated 2 MiB SPI flash chip** that is:
- Completely separate from the NVMe storage
- Not accessible via any OS-level operation (dd, fdisk, etc.)
- Not affected by disk wiping, repartitioning, or OS installation
- Automatically validated and restored on every boot

This means **reinstalling the OS, wiping the disk, or changing partitions cannot damage your BIOS or firmware**. The golden copy is immune to any storage-level operation. ([HP Sure Start Technical Whitepaper](https://h20195.www2.hp.com/v2/getpdf.aspx/4AA5-4453ENW.pdf), [coreboot documentation on HP Sure Start](https://doc.coreboot.org/mainboard/hp/index.html))

### Is Reinstalling Safe? Summary

| Concern | Risk Level | Explanation |
|---|---|---|
| Breaking BIOS/firmware | **None** | BIOS on isolated SPI chip; unaffected by disk operations |
| Breaking Sure Start | **None** | Hardware feature, OS-independent |
| Breaking ESC/TPM | **None** | Hardware chip, OS-independent |
| Losing HP recovery partition | **N/A** | Ubuntu variant has no HP recovery partition |
| Breaking Sure Recover | **None** | Firmware component OS-independent; recovery image is Windows-only anyway |
| Breaking Secure Boot | **Low** | Disable "Secure Boot Keys Protection" in BIOS before installing. Keep Secure Boot itself enabled. |
| Voiding warranty | **None** | Installing Linux does not void HP hardware warranty |

### Pre-Reinstall Checklist

If you decide to reinstall (either from the HP OEM ISO or stock Ubuntu):

1. **Download and save the HP OEM ISO** from [HP Support](https://support.hp.com/us-en/drivers/hp-zbook-ultra-g1a-14-inch-mobile-workstation-pc/2102737532) — there is no recovery partition
2. **Enter BIOS (F10) and configure:**
   - Disable **"Secure Boot Keys Protection"** (Security → BIOS Sure Start) — prevents boot loops
   - Disable **"Save/Restore MBR of System Hard Drive"** and **"Save/Restore GPT of System Hard Drive"** if present (Security → BIOS Sure Start) — prevents Sure Start from reverting partition table changes. Disabled by default.
   - Keep **Secure Boot enabled** — needed for suspend; OEM kernel is signed
   - Keep **RAM encryption (TSME)** and **Pluton** enabled — disabling breaks suspend
3. **Back up the EFI partition** (optional but recommended):
   ```bash
   sudo cp -r /boot/efi/EFI/HP /path/to/backup/    # save any HP EFI tools
   ```
4. **Update firmware first** (before reinstalling, while current OS works):
   ```bash
   sudo fwupdmgr refresh && sudo fwupdmgr update    # includes BIOS + PD firmware
   ```
5. **Proceed with installation** — either HP OEM ISO or stock Ubuntu 24.04 + `sudo apt install linux-oem-24.04`

### Wolf Security Software Agents — Not Applicable on Linux

The following Windows-only components are **not installed on the Ubuntu variant** and do not need to be disabled, removed, or configured:

- **Sure Run** — Windows service monitor
- **Sure Click** — Bromium/Xen micro-VM browser isolation
- **Sure Sense** — AI endpoint protection (deep learning malware detection)
- **Wolf Pro Security** — managed endpoint protection service

These have **zero interaction with Linux**. If you see references to these in HP documentation or BIOS, they are irrelevant to your setup.

---

## 17. Support Channels

| Channel | What to expect |
|---|---|
| **HP phone support** | Officially covers the preinstalled OS — but agents are typically untrained on Linux. Hardware warranty applies regardless of OS. |
| **[HP Support Community forums](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Using-the-webcam-on-zbook-ultra-g1a-Linux-ubuntu-25-04/td-p/9375051)** | Active multi-page threads on ZBook Ultra G1a Linux issues — best HP resource |
| **[Canonical OEM team (Launchpad)](https://answers.launchpad.net/ubuntu-certification/+question/821742)** | Engineers actively respond to ZBook Ultra G1a bugs |
| **LVFS/fwupd** | BIOS + PD firmware updates work from Linux (`sudo fwupdmgr update`) |
| **[Phoronix](https://www.phoronix.com/review/hp-zbook-ultra-g1a)** | Definitive Linux review, tested 7 distros |
| **[Level1Techs](https://forum.level1techs.com/t/the-ultimate-arch-secureboot-guide-for-ryzen-ai-max-ft-hp-g1a-128gb-8060s-monster-laptop/230652)** | 11+ pages of active discussion, Arch+SecureBoot guide |
| **[Gentoo Wiki](https://wiki.gentoo.org/wiki/User:Owenwastaken/HP_ZBook_Ultra_G1a)** | Detailed hardware documentation |
| **[Framework Community](https://community.frame.work/)** | Same Strix Halo chip — shared bugs and stable configuration reports |

---

## 18. All Sources

### Official / Vendor

- [Ubuntu Certification — HP ZBook Ultra G1a Platform](https://ubuntu.com/certified/platforms/15242)
- [Ubuntu Certification — Ryzen AI Max+ PRO 395 (24.04 LTS)](https://ubuntu.com/certified/202411-36033/24.04%20LTS)
- [Ubuntu Certification — Ryzen AI Max 385 (24.04 LTS)](https://ubuntu.com/certified/202411-36043/24.04%20LTS)
- [Red Hat Certified — ZBook Ultra G1a](https://catalog.redhat.com/en/hardware/system/detail/282387)
- [HP Support — ZBook Ultra G1a Drivers](https://support.hp.com/us-en/drivers/hp-zbook-ultra-g1a-14-inch-mobile-workstation-pc/2102737532)
- [HP ZBook Ultra G1a QuickSpecs (PDF)](https://h20195.www2.hp.com/v2/GetDocument.aspx?docname=c09119722)
- [HP Official Product Page](https://www.hp.com/us-en/workstations/zbook-ultra.html)
- [HP Sure Start Technical Whitepaper (PDF)](https://h20195.www2.hp.com/v2/getpdf.aspx/4AA5-4453ENW.pdf)
- [HP Wolf Security Overview](https://www.hp.com/us-en/security/endpoint-security-solutions.html)
- [Canonical OEM Kernel Documentation](https://canonical-kernel-docs.readthedocs-hosted.com/latest/reference/oem-kernels/)
- [Canonical HWE Team PC OEM DKMS PPA](https://launchpad.net/~canonical-hwe-team/+archive/ubuntu/pc-oem-dkms)
- [AMD ROCm — Strix Halo Optimization](https://rocm.docs.amd.com/en/latest/how-to/system-optimization/strixhalo.html)
- [AMD Memory Encryption — Linux Kernel Docs](https://docs.kernel.org/arch/x86/amd-memory-encryption.html)
- [AMD NPU Kernel Documentation](https://docs.kernel.org/accel/amdxdna/amdnpu.html)
- [HP Sure Start Technical Whitepaper (PDF)](https://h10032.www1.hp.com/ctg/Manual/c06216928.pdf)

### Reviews and Journalism

- [Phoronix — HP ZBook Ultra G1a Linux Review](https://www.phoronix.com/review/hp-zbook-ultra-g1a/2)
- [Phoronix — AMD ISP4 Driver v9 Patches](https://lkml.org/lkml/2026/3/2/278)
- [Phoronix — AMD ISP4 Driver Still Pending Review](https://www.phoronix.com/news/AMD-ISP4-Driver-Pending-Review)
- [Phoronix — Linux 7.0 Media Updates, AMD ISP4 Still Missing](https://www.phoronix.com/news/Linux-7.0-Media)
- [Phoronix — Ubuntu 26.04 LTS Linux 7.0 Commitment](https://www.phoronix.com/news/Ubuntu-26.04-LTS-Linux-Commit)
- [Phoronix — Ubuntu 26.04 Snapshot 4](https://www.phoronix.com/news/Ubuntu-26.04-Snapshot-4)
- [Phoronix — Strix Halo Linux vs Windows](https://www.phoronix.com/review/amd-strix-halo-windows-linux/4)
- [Phoronix — Strix Halo Platform Profile Benchmarks](https://www.phoronix.com/review/amd-strix-halo-platform-profile)
- [Phoronix — Pluton TPM CRB Merged Into Linux 6.3](https://www.phoronix.com/news/Pluton-TPM-CRB-Merged-Linux-6.3)
- [PCWorld — ZBook Ultra G1a Review](https://www.pcworld.com/article/2944690/hp-zbook-ultra-g1a-review.html)
- [StorageReview — ZBook Ultra G1a Review](https://www.storagereview.com/review/hp-zbook-ultra-g1a-14-review-all-the-ai-hype-not-enough-payoff)
- [WindowsForum — Windows vs Ubuntu Benchmarks](https://windowsforum.com/threads/hp-zbook-ultra-g1a-review-windows-vs-ubuntu-on-amd-ryzen-ai-max-pro-390.370885/)

### Ubuntu 26.04 LTS

- [OMG! Ubuntu — Ubuntu 26.04 Release Schedule](https://www.omgubuntu.co.uk/2025/11/ubuntu-26-04-release-schedule)
- [LinuxConfig — Ubuntu 26.04 Features](https://linuxconfig.org/ubuntu-26-04-release-date-and-new-features-in-resolute-raccoon)
- [Ubuntu Discourse — 26.04 Roadmap](https://discourse.ubuntu.com/t/ubuntu-26-04-lts-the-roadmap/72740)
- [Ubuntu Discourse — 26.04 Kernel Announcement](https://discourse.ubuntu.com/t/announcing-6-20-kernel-for-ubuntu-26-04-resolute-raccoon/73874)
- [PBXScience — Ubuntu 26.04 TPM + Post-Quantum](https://pbxscience.com/ubuntu-26-04-lts-tpm-encryption-rust-core-and-post-quantum-security-arrive/)

### HP Support Community Forums

- [Webcam Thread (4+ pages)](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Using-the-webcam-on-zbook-ultra-g1a-Linux-ubuntu-25-04/td-p/9375051)
- [Charging Issues](https://h30434.www3.hp.com/t5/Notebook-Hardware-and-Upgrade-Questions/Zbook-Ultra-g1a-Ubuntu-not-charging-redux/td-p/9437876)
- [PD 3.1 Firmware](https://h30434.www3.hp.com/t5/Notebook-Hardware-and-Upgrade-Questions/hp-zbook-ultra-g1a-needs-more-stable-pd-3-1-charging/td-p/9465799)
- [65W Charging](https://h30434.www3.hp.com/t5/Notebook-Hardware-and-Upgrade-Questions/Charging-HP-Zbook-Ultra-G1A-with-65w/td-p/9538308)
- [Suspend/Thermal Issues](https://h30434.www3.hp.com/t5/Business-Notebooks/ZBook-Ultra-G1a-Ryzen-AI-Max-PRO-395-high-APU-PPT-and-broken/td-p/9491525)
- [Dock Disconnection](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Ultrabook-G1a-constantly-disconnecting-from-docks-any-docks/td-p/9521854)
- [Random Reboots](https://h30434.www3.hp.com/t5/Business-Notebooks/HP-ZBook-Ultra-14-G1a-randomly-reboots/td-p/9549358)
- [BSOD/Reliability](https://h30434.www3.hp.com/t5/Notebook-Hardware-and-Upgrade-Questions/HP-ZBook-Ultra-14-G1a-BSOD-Reliability/td-p/9402236/page/2)
- [S3 Sleep Missing](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/S3-sleep-option-missing-in-HP-ZBook-Ultra-Z1a/td-p/9420909)

### Kernel Panic Diagnosis

- [ROCm #5724 — MES 0x83 GPU Page Faults](https://github.com/ROCm/ROCm/issues/5724)
- [ROCm #5590 — CWSR MES Firmware Hang](https://github.com/ROCm/ROCm/issues/5590)
- [Ubuntu Bug #2033295 — External Display Increases amdgpu Freezes](https://bugs.launchpad.net/bugs/2033295)
- [Framework Community — Linux + ROCm Stable Configurations (January 2026)](https://community.frame.work/t/linux-rocm-january-2026-stable-configurations-update/79876)
- [Arch Wiki — Ryzen (processor.max_cstate limitations)](https://wiki.archlinux.org/title/Ryzen)
- [Linux Kernel dumpstack.c — oops_end() panic behavior](https://github.com/torvalds/linux/blob/master/arch/x86/kernel/dumpstack.c)

### Bug Trackers

- [Ubuntu Bug #2115969 — GUI Freeze](https://bugs.launchpad.net/ubuntu/+source/linux-oem-6.14/+bug/2115969)
- [Ubuntu Bug #2141198 — MT7925 Suspend/Resume](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2141198)
- [Ubuntu Bug #2118937 — MT7925 Intermittent Connection](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2118937)
- [Kernel Bug #220702 — ISP4 Blocks S2idle](https://bugzilla.kernel.org/show_bug.cgi?id=220702)
- [Launchpad — Camera Not Working](https://answers.launchpad.net/ubuntu-certification/+question/821742)

### Community Guides and Wikis

- [Level1Techs — Arch + Secure Boot Guide](https://forum.level1techs.com/t/the-ultimate-arch-secureboot-guide-for-ryzen-ai-max-ft-hp-g1a-128gb-8060s-monster-laptop/230652)
- [Level1Techs — Linux Setup Video](https://level1techs.com/node/3237)
- [Gentoo Wiki — HP ZBook Ultra G1a](https://wiki.gentoo.org/wiki/User:Owenwastaken/HP_ZBook_Ultra_G1a)
- [NixOS Discourse — ZBook Ultra G1a](https://discourse.nixos.org/t/hp-zbook-ultra-g1a/69595)
- [srhb/isp4-nixos — NixOS ISP4 Module](https://github.com/srhb/isp4-nixos)
- [iglooom/AMD-ISP4-kernel-patches — AUR Patches](https://github.com/iglooom/AMD-ISP4-kernel-patches)
- [AMD ISP Kernel Driver (GitHub)](https://github.com/amd/Linux_ISP_Kernel)
- [AMD ISP libcamera (GitHub)](https://github.com/amd/Linux_ISP_libcamera/tree/3.0)
- [Cool My Ryzen AI Max — GNOME Extension](https://github.com/AnnoyingTechnology/gnome-extension-cool-my-ryzen-ai-max)
- [geohot/ztop — Power Monitoring](https://github.com/geohot/ztop)
- [Debian on HP EliteBook 8 G1a (Same Platform)](https://blog.frehi.be/2025/12/30/debian-gnu-linux-on-a-hp-elitebook-hp-elitebook-8-g1a-14)
- [Strix Halo + ROCm 7.1 + Ubuntu 24.04 Guide](https://hakedev.substack.com/p/strix-halo-rocm-71-ubuntu-2404)
- [ROCm on Strix Halo (GitHub)](https://github.com/Shoresh613/rocm-strix-halo)
- [strixhalo.wiki — Comprehensive Strix Halo Community Wiki](https://strixhalo.wiki/)
- [Julien Arnaud — HP ZBook Ultra G1a Linux Setup Blog](https://blog.julienarnaud.fr/hp-zbook-ultra-g1a-ryzen-ai-max-395-linux.html)
- [geohot — Replacing My MacBook (Blog)](https://geohot.github.io/blog/jekyll/update/2025/11/28/replacing-my-macbook.html)
- [mt7925e-bt-heal — WiFi/BT Suspend Fix Scripts](https://github.com/moolooite/mt7925e-bt-heal/)
- [Framework Community — MT7925 WiFi DKMS Fixes](https://community.frame.work/t/mt7925-wifi-driver-fixes-now-available-as-dkms-package/79777)
- [Framework Community — linux-firmware-20251125 Breaks ROCm](https://community.frame.work/t/fyi-linux-firmware-amdgpu-20251125-breaks-rocm-on-ai-max-395-8060s/78554)

### Security Advisories

- [AMD Product Security Bulletins](https://www.amd.com/en/resources/product-security.html)
- [AMD-SB-6024 — Graphics Driver Security (February 2026)](https://www.amd.com/en/resources/product-security/bulletin/amd-sb-6024.html)
- [ROCm Issue #5590 — CWSR GPU Hangs](https://github.com/ROCm/ROCm/issues/5590)
- [ROCm Issue #5665 — Simultaneous Compute + Encode Hang](https://github.com/ROCm/ROCm/issues/5665)

### FDE / Encryption

- [Ubuntu Security — Full Disk Encryption](https://documentation.ubuntu.com/security/security-features/storage/encryption-full-disk/)
- [Ubuntu Desktop — TPM Disk Encryption](https://documentation.ubuntu.com/desktop/en/latest/how-to/encrypt-your-disk-with-tpm/)
- [Ubuntu Desktop — Hardware-Backed FDE (24.04)](https://documentation.ubuntu.com/desktop/en/24.04/explanation/hardware-backed-disk-encryption/)
- [Ubuntu Blog — TPM-Backed FDE Is Coming](https://ubuntu.com/blog/tpm-backed-full-disk-encryption-is-coming-to-ubuntu)
- [Ubuntu Discourse — State of TPM FDE](https://discourse.ubuntu.com/t/the-state-of-tpm-fde/43992)
- [TecMint — Encrypt Ubuntu 24.04 Installation](https://www.tecmint.com/encrypt-ubuntu-24-04-installation/)
- [Thomas Horsten — Ubuntu 24.04 LUKS+LVM Install](https://thomashorsten.substack.com/p/installing-ubuntu-2404-with-lukslvm)
- [Riku Block — Ubuntu Install on Encrypted LVM](https://rikublock.dev/docs/tutorials/ubuntu-install-lvm/)
- [Clevis — Automated Encryption Framework](https://github.com/latchset/clevis)
- [Cloudflare — Speeding Up Linux Disk Encryption](https://blog.cloudflare.com/speeding-up-linux-disk-encryption/)
- [Fedora Wiki — LUKS Sector Size Change](https://fedoraproject.org/wiki/Changes/LUKSEncryptionSectorSize)
- [cryptsetup-reencrypt Man Page](https://man7.org/linux/man-pages/man8/cryptsetup-reencrypt.8.html)
- [ArchWiki — dm-crypt Device Encryption](https://wiki.archlinux.org/title/Dm-crypt/Device_encryption)
- [Phoronix — AMD Memory Guard Performance Cost on Ryzen AI Max+ PRO 395](https://www.phoronix.com/review/amd-memory-guard-ram-encrypt)
- [Phoronix — AMD SME Genoa 256-bit AES-XTS](https://www.phoronix.com/review/amd-sme-genoa)
- [UAPI Group — Linux TPM PCR Registry](https://uapi-group.org/specifications/specs/linux_tpm_pcr_registry/)
- [systemd-cryptenroll Man Page](https://www.freedesktop.org/software/systemd/man/systemd-cryptenroll.html)

### Pareto Security

- [Pareto Security — Linux Checks](https://paretosecurity.com/linux/checks)
- [Pareto Security — Privacy Policy](https://paretosecurity.com/legal/privacy)
- [Pareto Security — FAQ](https://paretosecurity.com/docs/faq)
- [Pareto Security Agent — GitHub (GPL-3.0)](https://github.com/ParetoSecurity/agent)
- [Docker Rootless Mode — Official Docs](https://docs.docker.com/engine/security/rootless/)

### Hacker News Discussions

- [First Impressions (Dec 2025)](https://news.ycombinator.com/item?id=46320214)
- ["Smashes the work laptop paradigm" (Jun 2025)](https://news.ycombinator.com/item?id=44333765)
- [General Discussion (Sep 2025)](https://news.ycombinator.com/item?id=45256880)
- [Phoronix Review Discussion (Jun 2025)](https://news.ycombinator.com/item?id=44255848)

### Launchpad Packages

- [linux-oem-24.04b](https://launchpad.net/ubuntu/noble/amd64/linux-oem-24.04b)
- [linux-oem-24.04c](https://launchpad.net/ubuntu/noble/amd64/linux-oem-24.04c)
- [linux-oem-6.11 Source](https://launchpad.net/ubuntu/noble/+source/linux-oem-6.11)
- [oem-stella-sensei-meta](https://launchpad.net/ubuntu/noble/+source/oem-stella-sensei-meta)

---

## 19. Open Bugs & Workaround Tracking

Track these upstream bugs to know when workarounds can be removed.

| Workaround | Bug/Issue | Status | Remove when |
|---|---|---|---|
| `pcie_aspm=off` | [Ubuntu #2115969](https://bugs.launchpad.net/ubuntu/+source/linux-oem-6.14/+bug/2115969) — PCIe ASPM GUI freeze | Open | Fix Released in OEM kernel; test by removing and monitoring 48h |
| `amd_iommu=off` | [Kernel #220702](https://bugzilla.kernel.org/show_bug.cgi?id=220702) — ISP4 blocks s2idle | Open | ISP4 driver has proper suspend PM (kernel 7.1+ or OEM backport) |
| `amd_iommu=off` | [Ubuntu #2141198](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2141198) — MT7925 resume timeout | Open | mt7925e handles suspend/resume natively |
| `amdgpu.cwsr_enable=0` | [ROCm #5590](https://github.com/ROCm/ROCm/issues/5590) — MES CWSR hang | Open | New MES firmware without CWSR regression |
| `amdgpu.dcdebugmask=0x410` | [Ubuntu #2024774](https://bugs.launchpad.net/bugs/2024774) — PSR/Panel Replay GUI freeze on X11 | Open | amdgpu driver properly coordinates PSR with X11 damage tracking; or migrate to Wayland |
| linux-firmware ≥20260110 | [ROCm #5724](https://github.com/ROCm/ROCm/issues/5724) — MES 0x83 page faults | Resolved | Already fixed; don't downgrade below 20260110 |
| WiFi suspend services | [Ubuntu #2141198](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2141198) | Open | mt7925e handles suspend/resume natively |
| Webcam (OEM kernel) | [AMD ISP4 v9 patches](https://lkml.org/lkml/2026/3/2/278) | Under review | ISP4 merged into mainline (targeting 7.1+) |
| Random reboots | [HP #9549358](https://h30434.www3.hp.com/t5/Business-Notebooks/HP-ZBook-Ultra-14-G1a-randomly-reboots/td-p/9549358) | Hardware | BIOS update or motherboard replacement |
| Dock disconnect >90W | [HP #9521854](https://h30434.www3.hp.com/t5/Business-PCs-Workstations-and-Point-of-Sale-Systems/Ultrabook-G1a-constantly-disconnecting-from-docks-any-docks/td-p/9521854) | Open | PD firmware or BIOS fix |
| CrackArmor | [USN-8095-1](https://ubuntu.com/security/notices/USN-8095-1) — 9 AppArmor CVEs | Patching | Kernel update + USN-8091-1/8092-1 su/sudo patches |
| EntrySign | [AMD-SB-7033](https://www.amd.com/en/resources/product-security/bulletin/amd-sb-7033.html) — unsigned microcode on Zen 1-5 | Patching | AGESA ≥1.2.0.3C via fwupd BIOS update |

---

## 20. Pareto Security — Endpoint Compliance

Pareto Security is a **lightweight, read-only endpoint security auditing tool** installed per Brave company policy. It is NOT an MDM — it cannot control, access, or modify your device remotely. The agent is open source ([GPL-3.0, Go](https://github.com/ParetoSecurity/agent)). The cloud dashboard is proprietary SaaS.

### What It Does

Runs **15 security hygiene checks** every hour (when the timer is enabled) and reports **pass/fail status only** (not detail strings) to your Brave team's Pareto Cloud dashboard. Named after the Pareto principle: 20% of security tasks that prevent 80% of problems.

### What Data Leaves Your Machine

Verified by source code audit of every HTTP call in the agent ([`team/report.go`](https://github.com/ParetoSecurity/agent/blob/main/team/report.go)):

| Endpoint | Data Sent |
|---|---|
| `PATCH cloud.paretosecurity.com/api/v1/team/{teamID}/device` | Pass/fail per check UUID, device UUID, hostname, OS version, model name, agent version |
| `GET paretosecurity.com/api/updates` | Device UUID, agent version, OS version, platform |
| `POST cloud.paretosecurity.com/api/v1/team/enroll` | One-time enrollment (device info + invite ID) |

**Not collected:** file contents, browsing history, keystrokes, screenshots, process lists, network traffic, application usage. No Sentry/analytics SDK in the agent (Sentry is cloud-side only per [privacy policy](https://paretosecurity.com/legal/privacy)). Reporting times are randomized so admins cannot determine when you are online ([FAQ](https://paretosecurity.com/docs/faq)).

### Remote Control Capabilities

**None.** The API is strictly one-way (device → cloud). The response handler ([`report.go:123-128`](https://github.com/ParetoSecurity/agent/blob/main/team/report.go)) only checks HTTP status codes. The root helper ([`runner/root_runner.go`](https://github.com/ParetoSecurity/agent/blob/main/runner/root_runner.go)) only accepts check UUIDs from a local Unix socket. No WebSocket, polling, or command-execution mechanism exists in the codebase.

Your IT team **can** see pass/fail results and set alerts. They **cannot** run commands, install software, lock/wipe, access files, or push config changes.

### The 15 Checks

| Category | Check | Requires Root |
|---|---|---|
| System Integrity | Filesystem encryption enabled | Yes |
| System Integrity | SecureBoot enabled | No |
| System Integrity | Cloud receiving reports | No |
| Access Security | Docker restricted (rootless mode) | No |
| Access Security | Screen lock password required | No |
| Access Security | SSH keys have password protection | No |
| Access Security | SSH keys use strong encryption | No |
| Access Security | Automatic login disabled | No |
| Access Security | Password manager present | No |
| Firewall & Sharing | Firewall configured | Yes |
| Firewall & Sharing | Remote login disabled | No |
| Firewall & Sharing | Printer sharing off | No |
| Firewall & Sharing | File sharing disabled | No |
| Application Updates | Apps up to date | Yes |
| Application Updates | Pareto up to date | No |

Source: [`checks/linux/`](https://github.com/ParetoSecurity/agent/tree/main/checks/linux) + [`checks/shared/`](https://github.com/ParetoSecurity/agent/tree/main/checks/shared)

### Known Failures and Fixes on the ZBook Ultra G1a

**Failure 1: Docker — "Deprecated docker.io package installed via apt"**

This is a **false positive**. `docker.io` has dpkg status `un` (never fully installed) but `dpkg-query -W` returns exit 0 for packages merely in the database. The check at [`docker.go:41-47`](https://github.com/ParetoSecurity/agent/blob/main/checks/linux/docker.go) doesn't verify installation status. Known class of bug (same issue in [AWS SSM Agent](https://github.com/aws/amazon-ssm-agent/issues/421)).

After purging the residual entry, the check proceeds to verify Docker rootless mode ([`docker.go:57`](https://github.com/ParetoSecurity/agent/blob/main/checks/linux/docker.go)). Docker CE is installed in standard (root daemon) mode, so this will also fail. Rootless Docker is a significant operational change (different networking, storage location, no AppArmor — see [Docker rootless docs](https://docs.docker.com/engine/security/rootless/)).

```bash
# Fix the false positive (no side effects)
sudo dpkg --purge docker.io

# Rootless mode: either accept the failure, or disable the check:
paretosecurity config disable 25443ceb-c1ec-408c-b4f3-2328ea0c84e1
```

**Failure 2: Firewall — "Firewall is off"**

The check at [`firewall.go:186-191`](https://github.com/ParetoSecurity/agent/blob/main/checks/linux/firewall.go) runs `iptables -L INPUT` (falls back to `nft list ruleset`) and passes if it finds DROP/REJECT policy, explicit rules, or known firewall chains (`ufw*`, `nixos-fw*`, `firewalld*`). UFW is not enabled.

```bash
sudo ufw enable            # safe — existing connections preserved via conntrack RELATED,ESTABLISHED
# Outgoing SSH to remote servers always works (UFW defaults: deny incoming, allow outgoing).
# Only add 'sudo ufw allow OpenSSH' if others need to SSH INTO this laptop.
```

**Failure 3: App updates — "Updates available for: Snap"**

The check at [`application_updates.go:96-108`](https://github.com/ParetoSecurity/agent/blob/main/checks/linux/application_updates.go) runs `snap refresh --list`. Snaps auto-update 4×/day but can be delayed by holds or metered connections. **Note:** snap-store holds a lock on itself while running — `killall snap-store` is required before `snap refresh` will succeed ([Ubuntu Discourse](https://discourse.ubuntu.com/t/how-to-close-the-snap-store-to-allow-snapd-to-update-it/30627)).

```bash
killall snap-store 2>/dev/null; sudo snap refresh
```

### CLI Commands

```bash
paretosecurity check             # run all 15 checks
paretosecurity check --verbose   # detailed output
paretosecurity status            # cached results table
paretosecurity info              # device/system info
paretosecurity schema            # JSON check definitions
```

### Systemd Services

| Service | Purpose | Recommended Status |
|---|---|---|
| `paretosecurity.socket` (system) | Local Unix socket for root helper — sits idle, only activates when you manually run `paretosecurity check`. No automatic checks, no network activity. | **Enabled** (keep — needed for manual checks) |
| `paretosecurity.service` (system) | Root helper (socket-activated on demand) | On-demand |
| `paretosecurity-user.timer` (user) | Would run checks hourly if enabled | **Disabled** (leave disabled for manual-only mode) |
| `paretosecurity-trayicon.service` (user) | Desktop tray icon | **Disabled** (optional) |
