# .dot

Dotfiles and system management scripts for Ubuntu 24.04 LTS.

## Setup

```bash
git clone <repo> ~/.dot
cd ~/.dot
./install.sh
```

## Scripts

### install.sh

Creates symlinks for dotfiles into `$HOME`. Run once on a fresh machine.

### update.sh

Builds/updates development tools (Neovim, Rust, Python, Node.js, etc.)
from version-locked definitions in `lock.sh`.

### backup.sh

Encrypted incremental backup using [restic](https://restic.net).
Backs up home directory and system configuration paths.

```bash
# First run (initializes encrypted repo)
export RESTIC_PASSWORD="..."   # or use RESTIC_PASSWORD_FILE
./backup.sh /mnt/external/backup -i

# Subsequent runs
./backup.sh /mnt/external/backup

# With pre-backup cleanup of build artifacts
./backup.sh /mnt/external/backup -c

# Dry run
./backup.sh /mnt/external/backup -n
```

**What gets backed up:**

| Snapshot | Paths | Tag |
|---|---|---|
| Home | `~/` (excluding caches, trash, Steam, flatpak, Vagrant boxes) | `home` |
| System | `/usr/local/bin/`, `/etc/default/grub`, `/etc/apt/{sources.list.d,keyrings}/`, `/etc/{sysctl.d,udev/rules.d,modprobe.d,netplan}/`, `/etc/hosts` + conditional: `/etc/tlp.conf`, `/etc/crypttab`, WiFi suspend services, `/boot/efi/EFI/HP/`, `/etc/X11/xorg.conf.d/` | `system` |

Package lists are exported to `~/.dot/backup/` before each backup:

- `apt-manual.txt` — explicitly installed apt packages
- `snap-packages.txt` — snap package names (system snaps filtered out)
- `flatpak-apps.txt` — flatpak application IDs

### restore.sh

Restore from a restic backup. Restores to a staging directory (`~/.dot/restore/`) by default — use `-t /` to restore in-place.

```bash
# List available snapshots
./restore.sh /mnt/external/backup --list

# Restore to staging directory (~/.dot/restore/)
./restore.sh /mnt/external/backup

# Restore in-place (overwrites live system)
./restore.sh /mnt/external/backup -t /

# Restore home only
./restore.sh /mnt/external/backup --home-only

# Restore a specific snapshot
./restore.sh /mnt/external/backup -s abc123

# Restore and reinstall packages
./restore.sh /mnt/external/backup -t / --packages

# Dry run
./restore.sh /mnt/external/backup -n
```

**Post-restore steps:**

- `sudo update-grub` — apply restored GRUB config (kernel params)
- `sudo netplan apply` — activate restored WiFi connections
- `sudo systemctl enable wifi-suspend-fix.service wifi-pre-suspend.service` — if WiFi suspend services restored
- Verify `~/.ssh/` permissions (700 for dir, 600 for private keys)
- Re-establish GPG trust if needed: `gpg --edit-key <ID>` then `trust`
- Re-bind Clevis TPM2 if using FDE: `sudo clevis luks bind -d /dev/<part> tpm2 '{...}'`
- Run `./install.sh` to symlink dotfiles
- Run `./update.sh` to build dev tools

### cleanup.sh

Pre-backup cleanup: removes regenerable build artifacts (Rust targets,
node\_modules, Python venvs, caches) from dev repositories.

```bash
./cleanup.sh                      # default: ~/dev/repositories
./cleanup.sh -d ~/projects        # custom directory
./cleanup.sh -s                   # also clean system caches (~/.cache/pip, etc.)
./cleanup.sh -g                   # run git gc --prune=now on all repos
./cleanup.sh -a                   # --system-caches + --git-gc
./cleanup.sh -n                   # dry run
```

### archive.sh

Compress directories to `.tar.zst` archives with integrity verification.

```bash
./archive.sh ~/old-project                    # archive a directory
./archive.sh ~/old-project -k                 # keep original after archiving
./archive.sh ~/old-project -l 15              # zstd level 1-19 (default: 9)
./archive.sh ~/old-project --no-cleanup       # skip artifact cleanup step
./archive.sh old-backup.tar.bz2              # re-compress to zstd
./archive.sh --recompress-all ~/archives/    # batch re-compress all archives
./archive.sh ~/old-project -n                # dry run
```

## Migration to a New Laptop

1. **On the current machine:**

   ```bash
   export RESTIC_PASSWORD="your-strong-passphrase"  # save in password manager
   ./backup.sh /mnt/external/backup -i -c           # init + cleanup + backup
   ```

2. **On the new machine:**

   ```bash
   # Fresh install Ubuntu 24.04 with LUKS2 full disk encryption
   sudo apt install restic git
   git clone <repo> ~/.dot
   cd ~/.dot
   export RESTIC_PASSWORD="your-strong-passphrase"
   ./restore.sh /mnt/external/backup -t / --packages  # restore in-place + reinstall packages
   ./install.sh                                        # symlink dotfiles
   ./update.sh                                         # build dev tools
   sudo update-grub                                    # apply restored kernel params
   sudo netplan apply                                  # activate WiFi
   ```

## Backup Architecture

- **Tool:** [restic](https://restic.net) — encrypted, deduplicated, incremental
- **Encryption:** AES-256-CTR + Poly1305 (formally audited, fixed scheme)
- **Compression:** zstd via `--compression auto`
- **Deduplication:** content-defined chunking (unchanged files cost ~0 on incrementals)
- **Repository:** any restic-compatible backend (local path, SFTP, S3, Backblaze B2, etc.)

## Directory Structure

```
.dot/
├── install.sh          # symlink dotfiles
├── update.sh           # build/update dev tools
├── backup.sh           # encrypted incremental backup
├── restore.sh          # restore from backup
├── cleanup.sh          # pre-backup artifact cleanup
├── archive.sh          # directory compression
├── lock.sh             # tool version locks
├── zshrc               # shell config
├── gitconfig           # git config
├── vimrc               # vim config
├── ssh_config          # SSH config
├── nuggets/            # modular tool installers
│   ├── rust/
│   ├── python/
│   ├── javascript/
│   ├── docker/
│   ├── go/
│   └── utilities/
├── vim/                # vim plugins and config
├── fonts/              # terminal fonts
├── backup/             # exported package lists (gitignored)
└── logs/               # script logs (gitignored)
```
