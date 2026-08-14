# Adding ROMs and games (sm8550 / sm8750)

Single guide for batocera.pocket Qualcomm devices (sm8550 and sm8750: Odin 2 /
Pocket / Odin 3, etc.). ROM layout and PC platforms are the same on both boards.

Table style inspired by [ROCKNIX — Supported emulators and cores](https://github.com/ROCKNIX/distribution/blob/20260801/documentation/PER_DEVICE_DOCUMENTATION/SM8550/SUPPORTED_EMULATORS_AND_CORES.md).

## Where files go

| Path | Contents |
|------|----------|
| `/userdata/roms/<system>/` | Games / ROMs for that system |
| `/userdata/bios/` | BIOS / firmware (when the emulator needs it) |
| `/userdata/saves/` | Saves and states (managed by Batocera) |
| `/userdata/system/configs/` | Emulator configuration |

`<system>` is the **Games Path** from the table below (e.g. `psx`, `windows`, `heroic`).

### How to copy

1. Put the device on the network (or USB) and open the Samba share `SHARE` / `userdata`, **or**
2. Use SSH/SFTP (`root` / `linux` by default), **or**
3. Copy onto a microSD under `batocera/roms/...` and assign it as storage under **Settings → System → Storage** (optional).

After copying: in EmulationStation, **update the game list** (or restart ES).

> Systems with **no games** (only `_info.txt`) do not appear in ES-DE. That is normal.

<details>
<summary><b>Quick hotkeys (Odin) — so you are not hunting for combos</b></summary>

| Combo | Action |
|-------|--------|
| **Home + Start** | Exit emulator |
| **L1 + R1 + Select + Start** | Force quit |
| **R1 + Select + Start** | Mouse mode |
| **Home + A** | Control Center |
| **Back** | Brightness (in ES) |

Full FAQ + pad GUID: [CONTROLS_AND_FAQ.md](CONTROLS_AND_FAQ.md).

</details>

### BIOS

Many systems need BIOS files under `/userdata/bios/`. Use **Settings → System → Check BIOS** or the official wiki: [batocera.org — BIOS](https://wiki.batocera.org/batocera-os:add_games_bios#bios).

---

## PC platforms (Windows / Steam / Heroic / Lutris)

Recommended paths for “PC” games. Same on sm8550 and sm8750.

### Windows (Wine) — `/userdata/roms/windows/`

Extensions: `.pc` · `.exe` · `.wine` · `.wsquashfs` · `.wtgz`

**Option A — already-installed folder (best for dumps / portable games)**

1. Copy the game directory to `/userdata/roms/windows/MyGame.pc/`
2. Make sure the main executable is inside (e.g. `Game.exe`)
3. Create `autorun.cmd` in that folder:

```text
CMD=Game.exe
DIR=
```

4. Update the game list in ES → **Windows** system.

**Option B — installer**

1. Place the `.exe` / `.msi` / `.iso` in `/userdata/roms/windows_installers/`
2. Launch it from ES (**Install a new Windows game**)
3. Follow the Wine installer; Batocera may create the `.wine` prefix / `autorun`

Useful tools (F1 / Tools): `Wine Tools`, `batocera-wine`.

More detail: [wiki — Windows](https://wiki.batocera.org/systems:windows).

### Steam — `/userdata/roms/steam/`

Extensions: `.steam`

1. Open **Steam** from ES (e.g. *Steam GamepadUI* / *Steam Desktop*)
2. Sign in and install games in Steam
3. Generate / refresh shortcuts:

```bash
batocera-steam-update
```

(This can also run when updating gamelists.)

The `.steam` files in that folder are **launchers**; client data lives under `/userdata/system/` (and any Steam library paths you configure).

### Heroic (Epic / GOG / Amazon) — `/userdata/roms/heroic/`

Extensions: `.sh`

1. Open **Configure Heroic** (Tools / Emulators) or the **Heroic** system
2. Sign in and install games in Heroic
3. Generate ES shortcuts:

```bash
batocera-heroic-update
```

`.sh` scripts appear under `/userdata/roms/heroic/`. With no games/shortcuts, the Heroic system may stay hidden.

### Lutris — `/userdata/roms/lutris/`

Extensions: `.sh`

1. Open **Configure Lutris** and install / import games
2. Generate shortcuts:

```bash
batocera-lutris-update
```

Resulting `.sh` files go to `/userdata/roms/lutris/`.

> **Do not** hand-copy hundreds of junk `.sh` files — let Lutris/Heroic/Steam generate shortcuts via the scripts above.

### PC performance tips

- Prefer **fast internal storage (UFS)** for Windows / Steam / Wine prefixes when the title is heavy.
- microSD is fine for classic ROMs and large libraries; for PC, random I/O is often the bottleneck.
- LSFG (Lossless Scaling) is wired into several native Vulkan emulators; **do not** use it on experimental FEX/shadPS4 paths unless you know what you are doing.

---

## Systems and emulators (summary)

Paths are relative to `/userdata/roms/`. The default emulator depends on the board; on sm8550/sm8750 the usual defaults are in **bold**.

| Manufacturer | System | Games Path | Supported Extensions | Emulator / Core |
|--------------|--------|------------|----------------------|-----------------|
| System | Apps | `apps` | `.sh` | scripts / desktop apps |
| System | Tools / Emulators | `emulator` | `.sh` | Configure_* / Start_* |
| Ports | Ports | `ports` | `.sh` … | PortMaster / scripts |
| Capcom / Arcade | FinalBurn Neo | `fbneo` | `.zip` `.7z` | **libretro:** fbneo |
| SNK | Neo Geo | `neogeo` | `.zip` `.7z` `.neo` | **libretro:** fbneo |
| Sammy | Atomiswave | `atomiswave` | `.zip` `.7z` `.bin` … | **flycast** / libretro flycast |
| Sega | Naomi / Naomi 2 | `naomi` / `naomi2` | `.zip` `.7z` `.bin` … | **flycast** |
| Sega | Dreamcast | `dreamcast` | `.cdi` `.gdi` `.chd` `.cue` `.m3u` | **flycast** |
| Sega | Saturn | `saturn` | `.cue` `.chd` `.iso` … | **ymir** / libretro yabasanshiro / beetle |
| Sega | Mega Drive / Genesis | `megadrive` | `.bin` `.gen` `.md` `.smd` `.zip` `.7z` | **libretro:** genesis_plus_gx |
| Nintendo | NES | `nes` | `.nes` `.zip` `.7z` | **libretro:** nestopia / fceumm / mesen |
| Nintendo | SNES | `snes` | `.sfc` `.smc` `.zip` `.7z` | **libretro:** snes9x |
| Nintendo | Game Boy / Color | `gb` / `gbc` | `.gb` `.gbc` `.zip` `.7z` | **libretro:** gambatte / mgba |
| Nintendo | GBA | `gba` | `.gba` `.zip` `.7z` | **libretro:** mgba |
| Nintendo | N64 | `n64` | `.z64` `.n64` `.v64` `.zip` `.7z` | **libretro:** mupen64plus-next |
| Nintendo | DS | `nds` | `.nds` `.zip` `.7z` | **libretro:** melonds / melonDS SA |
| Nintendo | 3DS | `3ds` | `.cci` `.cia` `.3ds` … | **azahar** |
| Nintendo | GameCube | `gamecube` | `.gcm` `.iso` `.ciso` `.gcz` `.rvz` `.m3u` | **dolphin** |
| Nintendo | Wii | `wii` | `.iso` `.wbfs` `.rvz` `.wad` … | **dolphin** |
| Nintendo | Wii U | `wiiu` | `.wua` `.wud` `.wux` `.rpx` … | **cemu** |
| Nintendo | Switch | `switch` | `.xci` `.nsp` | **eden** / ryujinx / yuzu |
| Nintendo / Arcade | Triforce | `triforce` | `.iso` `.rvz` | **dolphin** |
| Sony | PlayStation | `psx` | `.cue` `.bin` `.chd` `.pbp` `.m3u` … | **duckstation** / libretro |
| Sony | PlayStation 2 | `ps2` | `.iso` `.chd` `.cso` … | **aethersx2** / armsx2 |
| Sony | PlayStation 3 | `ps3` | `.ps3` `.psn` `.iso` `.squashfs` | **rpcs3** |
| Sony | PlayStation 4 | `ps4` | `.ps4` | **shadps4** (FEX on aarch64) |
| Sony | PSP | `psp` | `.iso` `.cso` `.pbp` `.chd` | **PPSSPP** |
| Sony | PS Vita | `psvita` | `.psvita` `.pkg` `.zip` | **vita3k** |
| Microsoft | Xbox | `xbox` | `.iso` | **xemu** |
| Microsoft | Xbox 360 | `xbox360` | `.iso` `.xex` `.xbox360` `.zar` | **xenia-canary** / **xenia-edge** |
| Microsoft | Windows | `windows` | `.pc` `.exe` `.wine` `.wsquashfs` `.wtgz` | **wine-tkg** |
| Microsoft | Windows installers | `windows_installers` | `.exe` `.iso` `.msi` | **wine-tkg** |
| Valve | Steam | `steam` | `.steam` | **steam** (gamepadui / desktop) |
| Heroic | Heroic | `heroic` | `.sh` | **heroic** |
| Lutris | Lutris | `lutris` | `.sh` | **lutris** |

The full Batocera system list (hundreds of platforms) follows the [systems wiki](https://wiki.batocera.org/systems_list) and `es_systems.yml` in the tree.

---

## Per-system notes (pocket)

### PlayStation 4 (`ps4`)

1. Extract the PKG off-device (PKG Extractor / your own dump).
2. Copy the game folder to `/userdata/roms/ps4/`.
3. Rename the folder to `Name.ps4` **or** leave an `something.ps4` file inside / next to the dump so ES sees it.

Example: `/userdata/roms/ps4/Bloodborne.ps4/` (folder with `eboot.bin`, etc.).

On sm8550/sm8750 the default shadPS4 resolution is **1280×720**.

### PlayStation 3 (`ps3`)

- Folders renamed to `Game.ps3`, **or** an `.iso` image.
- Install PS3 firmware once from RPCS3 (F1 → Applications → rpcs3-config).

### Switch (`switch`)

- `.nsp` / `.xci` (often inside folders; ES scans extensions).
- Default emulator: **Eden**. Keys/firmware per emulator requirements.

### Wii U (`wiiu`)

- Folder dump with `code/` / `content/` / `meta/`, or `.wua` / `.wux`, etc.
- Emulator: **Cemu**.

### Xbox 360 (`xbox360`)

- On aarch64: **Xenia Canary** / **Xenia Edge** (native Vulkan).
- ISOs / dumps compatible with Xenia.

### GameCube

- Official path: `/userdata/roms/gamecube/` (not `gc`, unless you created a symlink on purpose).

---

## After copying

1. **ES-DE → update gamelist** (or restart EmulationStation).
2. If the system does not appear: ensure there is at least one file with a valid extension (not only `_info.txt`).
3. If a game fails to start: check `/userdata/system/logs/` and the matching emulator log.

## References

- [Controls and FAQ (Odin mappings)](CONTROLS_AND_FAQ.md)
- [Installing the image](INSTALL.md)
- [OTA updates](UPDATES.md)
- [Changelog (Updates / Fixes)](CHANGELOG.md)
- [Wiki Batocera — Add games & BIOS](https://wiki.batocera.org/add_games_bios)
- [Wiki Batocera — Windows](https://wiki.batocera.org/systems:windows)
