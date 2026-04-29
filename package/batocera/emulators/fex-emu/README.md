# FEX-Emu for Batocera

## Overview

FEX-Emu enables transparent x86/x86_64 binary execution on AArch64 (ARM64) Linux systems. This package integrates FEX-Emu into Batocera with automatic Steam setup via the Ports menu.

## Package Structure

```
buildroot/package/batocera/emulators/fex-emu/
├── Config.in                  # Buildroot package configuration
├── fex-emu.mk                 # Build rules and install targets
├── S30fex-emu                 # Init script (binfmt_misc registration)
├── S31fex-welcome             # First-boot welcome notification
├── fex-emu.service            # systemd service (optional)
├── README.md                  # This file
└── scripts/
    ├── fex-setup.sh           # RootFS configuration helper
    ├── fex-steam.sh           # Steam launcher wrapper
    ├── fex-install-steam.sh   # Steam CLI installer
    ├── fex-install-steam-xterm.sh  # Steam installer (visual/xterm)
    ├── fex-complete-setup.sh  # All-in-one setup wizard
    ├── fex-setup-ports.sh     # Ports menu installer
    └── Steam (FEX).sh         # Batocera port launcher
```

## Installation (Build System)

1. Copy the `fex-emu/` folder to:
   ```
   buildroot/package/batocera/emulators/fex-emu/
   ```

2. Add to the parent `Config.in` (e.g., `emulators/Config.in`):
   ```
   source "$BR2_EXTERNAL_BATOCERA_PATH/package/batocera/emulators/fex-emu/Config.in"
   ```

3. Enable in your defconfig or `make menuconfig`:
   ```
   BR2_PACKAGE_FEX_EMU=y
   ```

4. Build:
   ```
   make fex-emu-rebuild
   ```

## What Gets Installed Where

| File | Target Location | Purpose |
|------|----------------|---------|
| S30fex-emu | `/etc/init.d/S30fex-emu` | binfmt_misc at boot |
| S31fex-welcome | `/etc/init.d/S31fex-welcome` | One-time welcome message |
| fex-emu.service | `/usr/lib/systemd/system/` | systemd alternative |
| fex-setup | `/usr/bin/fex-setup` | RootFS config helper |
| fex-steam | `/usr/bin/fex-steam` | Steam launcher CLI |
| fex-install-steam | `/usr/bin/fex-install-steam` | Steam installer CLI |
| fex-install-steam-xterm | `/usr/bin/fex-install-steam-xterm` | Steam installer visual |
| fex-complete-setup | `/usr/bin/fex-complete-setup` | All-in-one wizard |
| fex-setup-ports | `/usr/bin/fex-setup-ports` | Ports menu installer |
| Steam (FEX).sh | `/userdata/roms/ports/` | ES port launcher |
| Steam (FEX).sh | `/usr/share/fex-emu/ports/` | Port template backup |

## User Experience (Post-Flash)

1. Boot Batocera → One-time "FEX-Emu is ready!" notification appears
2. Navigate to **Ports → Steam (FEX)** in EmulationStation
3. First launch opens an xterm window that:
   - Downloads x86_64 RootFS (~3-5 GB, ~5-10 min)
   - Installs Steam (~5-10 min)
   - All progress visible in the terminal
4. Steam launches in Big Picture mode
5. Subsequent launches skip setup and go straight to Steam

## Init Script Numbering

- **S30fex-emu** — Runs after networking (S07) and before EmulationStation (S31)
- **S31fex-welcome** — Runs just before/alongside EmulationStation to show notification
- Does NOT conflict with S99custom or S99userservices

## Manual Commands (via SSH/Terminal)

```bash
# Full setup wizard (recommended for first time)
fex-complete-setup

# Individual steps
fex-setup              # Configure RootFS only
fex-install-steam      # Install Steam only (CLI)
fex-install-steam-xterm # Install Steam (visual)
fex-setup-ports        # Add ports to ES menu

# Launch Steam
fex-steam

# Test FEX-Emu
FEXBash
uname -m               # Should show: x86_64
exit

# Service management
/etc/init.d/S30fex-emu status
/etc/init.d/S30fex-emu restart
```

## Troubleshooting

**binfmt_misc not working:**
```bash
/etc/init.d/S30fex-emu status
/etc/init.d/S30fex-emu restart
```

**Steam won't install:**
```bash
# Check logs
cat /userdata/system/logs/fex-steam-install.log
# Try manual install
fex-install-steam
```

**RootFS issues:**
```bash
# Re-download rootfs
rm -rf ~/.fex-emu/RootFS
fex-setup
```

**Port not showing in EmulationStation:**
```bash
fex-setup-ports
batocera-es-swissknife --restart
```

## Requirements

- AArch64 (ARM64) platform
- ~5 GB free space for RootFS
- ~2 GB additional for Steam
- Internet connection for first-time setup
