# Adding ROMs and games (sm8550 / sm8750)

Single guide for batocera.pocket Qualcomm devices (sm8550 and sm8750: Odin 2 /
Pocket / Odin 3, etc.). ROM layout and PC platforms are the same on both boards.

Table style inspired by [ROCKNIX — Supported emulators and cores](https://github.com/ROCKNIX/distribution/blob/20260801/documentation/PER_DEVICE_DOCUMENTATION/SM8550/SUPPORTED_EMULATORS_AND_CORES.md).

## Where files go

| Path | Contents |
|------|----------|
| `/userdata/roms/<system>/` | Games / ROMs for that system |
| `/userdata/roms/pkmnrecomp/` | Pokémon Recomp dumps + `mods/gen1` / `mods/gen2` (see below) |
| `/userdata/bios/` | BIOS / firmware / console keys (when the emulator needs it) |
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
| **Home + Touch** | On-screen keyboard |
| **Back** | Brightness (in ES); Steam QAM in GamepadUI |

Full FAQ + pad GUID: [CONTROLS_AND_FAQ.md](CONTROLS_AND_FAQ.md).

</details>

### BIOS and other extra data

Many systems need more than a ROM: BIOS, encryption keys, firmware `.nca`, or
mod ZIPs. Generic BIOS still goes under `/userdata/bios/` — use **Settings →
System → Check BIOS** or the wiki:
[batocera.org — BIOS](https://wiki.batocera.org/batocera-os:add_games_bios#bios).

Systems that use **extra folders** (not a single file in `bios/`) are listed in
[Per-system notes](#per-system-notes-pocket). Quick map:

| Extra data | Path |
|------------|------|
| Pokémon Recomp mods (Gen 1) | `/userdata/roms/pkmnrecomp/mods/gen1/` |
| Pokémon Recomp mods (Gen 2) | `/userdata/roms/pkmnrecomp/mods/gen2/` |
| Switch keys | `/userdata/bios/switch/keys/` (`prod.keys`, optional `title.keys`) |
| Switch firmware | `/userdata/bios/switch/firmware/` or `…/registered/` (`.nca`) |
| Wii U keys | `/userdata/bios/cemu/keys.txt` |
| PS2 BIOS | `/userdata/bios/ps2/` |
| PS3 firmware | `/userdata/bios/PS3UPDAT.PUP` (installed on first launch) |
| Xbox boot ROM / MCPX | `/userdata/bios/mcpx_1.0.bin` + flash (`cerbios.bin` or `Complex_4627.bin`) |
| Dreamcast | `/userdata/bios/dc/` (`dc_boot.bin`, …) |
| DS / DSi | `/userdata/bios/` (`bios7.bin`, `bios9.bin`, `firmware.bin`, `dsi_nand.bin`, …) |
| 3DS keys (Azahar) | `/userdata/saves/3ds/azahar-emu/sysdata/aes_keys.txt` |
| ScummVM extras | `/userdata/bios/scummvm/extra/` |

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
| Nintendo | Pokémon Recomp | `pkmnrecomp` | `.gb` `.gbc` (US dumps, **not zip**) | **pkmnrecomp:** gen1recomp / gen2recomp |
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

### Pokémon Recomp (`pkmnrecomp`) — Gen 1 / Gen 2

Native LÖVE recreations (**gen1recomp** / **gen2recomp**). Nothing is bundled:
you supply your own **canonical US** dumps. The system stays hidden in ES until
at least one `.gb` / `.gbc` is present.

| What | Path |
|------|------|
| ROMs (game list) | `/userdata/roms/pkmnrecomp/` |
| Gen 1 mods | `/userdata/roms/pkmnrecomp/mods/gen1/` |
| Gen 2 mods | `/userdata/roms/pkmnrecomp/mods/gen2/` |
| Optional mods (not auto-loaded) | `/userdata/roms/pkmnrecomp/mods/optional/` |
| Saves / options (Gen 1) | `/userdata/saves/apps/pkmnrecomp-gen1/` |
| Saves / options (Gen 2) | `/userdata/saves/apps/pkmnrecomp-gen2/` |
| AppImage override (optional) | `/userdata/system/pkmnrecomp/` |

Samba: `\\BATOCERA\share\roms\pkmnrecomp\`

**Dumps** — unzipped `.gb` / `.gbc` only. SHA-1 picks the core automatically
(Red/Blue/Yellow → gen1, Gold/Silver/Crystal → gen2). Gold can run on both;
Silver/Crystal need gen2.

| Game | SHA-1 (US) |
|------|------------|
| Red | `ea9bcae617fdf159b045185467ae58b2e4a48b9a` |
| Blue | `d7037c83e1ae5b39bde3c30787637ba1d4c48ce2` |
| Yellow | `cc7d03262ebfaf2f06772c1a480c7d9d5f4a38e1` |
| Gold | `d8b8a3600a465308c9953dfa04f0081c05bdcb94` |
| Silver | `49b163f7e57702bc939d642a18f591de55d92dae` |
| Crystal Rev 1 | `f2f52230b536214ef7c9924f483392993e226cfb` |
| Crystal Rev 0 | `f4cd194bdee0d04ca4eac29e09b8e4e9d818c133` |

**Mods** — ZIP or a folder with `manifest.json`. On launch the wrapper unpacks
ZIPs into `mods/<id>/`. Drop Gen 1 packs in `mods/gen1/` (e.g. potato_voxel)
and Gen 2 packs in `mods/gen2/` (e.g. DRAMATIC_SHAPE). Files in `mods/optional/`
(Nuzlocke, …) stay idle until you copy them into `gen1/` or `gen2/`.

First Gen 2 import can take a couple of minutes (no file picker). Vanilla
options/controls: **Tools → Configure Gen1Recomp / Configure Gen2Recomp**.
On the Odin pad, **Home + Start** exits like any other emulator; **A / B /
Start / Select** and the D-pad are the in-game buttons.

### PlayStation 4 (`ps4`)

1. Extract the PKG off-device (PKG Extractor / your own dump).
2. Copy the game folder to `/userdata/roms/ps4/`.
3. Rename the folder to `Name.ps4` **or** leave an `something.ps4` file inside / next to the dump so ES sees it.

Example: `/userdata/roms/ps4/Bloodborne.ps4/` (folder with `eboot.bin`, etc.).

On sm8550/sm8750 the default shadPS4 resolution is **1280×720**.

### PlayStation 3 (`ps3`)

- Folders renamed to `Game.ps3`, **or** an `.iso` image.
- Firmware: copy `PS3UPDAT.PUP` to `/userdata/bios/`. First game launch (or
  **Tools → rpcs3-config**) installs it.

### PlayStation 2 (`ps2`)

- BIOS dumps in `/userdata/bios/ps2/` (`.bin` / `.rom`). Aethersx2 / ArmSX2
  pick them from that folder.

### PlayStation Vita (`psvita`)

- Games: `/userdata/roms/psvita/` (`.psvita` / `.pkg` / `.zip`).
- Firmware is installed once from **Tools → vita3k-config** (not a drop-in ROM
  folder). Saves live under `/userdata/saves/psvita/`.

### Switch (`switch`)

- Games: `.nsp` / `.xci` under `/userdata/roms/switch/`.
- Default emulator: **Eden**. Extra data (shared with Yuzu/Ryujinx):

| File | Path |
|------|------|
| `prod.keys` | `/userdata/bios/switch/keys/prod.keys` (also accepted in `…/switch/prod.keys`) |
| `title.keys` | `/userdata/bios/switch/keys/title.keys` (optional) |
| Firmware `.nca` | `/userdata/bios/switch/firmware/` or `/userdata/bios/switch/registered/` |

### Wii U (`wiiu`)

- Folder dump with `code/` / `content/` / `meta/`, or `.wua` / `.wux`, etc.
- Emulator: **Cemu**. Title keys: `/userdata/bios/cemu/keys.txt`.

### 3DS (`3ds`)

- Games: `/userdata/roms/3ds/` (`.cci` / `.cia` / `.3ds`, …). Emulator: **Azahar**.
- Encryption keys (needed for many dumps):  
  `/userdata/saves/3ds/azahar-emu/sysdata/aes_keys.txt`

### Xbox (`xbox`)

- Games: `/userdata/roms/xbox/` (`.iso`). Emulator: **xemu**.
- Extra: `/userdata/bios/mcpx_1.0.bin` plus flash ROM (`cerbios.bin` or
  `Complex_4627.bin`). HDD image is created under `/userdata/saves/xbox/`.

### Xbox 360 (`xbox360`)

- On aarch64: **Xenia Canary** / **Xenia Edge** (native Vulkan).
- ISOs / dumps compatible with Xenia. No separate keys folder.

### Nintendo DS (`nds`)

- Games: `/userdata/roms/nds/`.
- BIOS / firmware in `/userdata/bios/`: `bios7.bin`, `bios9.bin`, `firmware.bin`;
  DSi also wants `dsi_firmware.bin` and `dsi_nand.bin`.

### Dreamcast / Naomi / Atomiswave

- BIOS: `/userdata/bios/dc/` (at least `dc_boot.bin`). Flycast uses this path
  for Dreamcast, Naomi, and Atomiswave.

### GameCube

- Official path: `/userdata/roms/gamecube/` (not `gc`, unless you created a symlink on purpose).

### ScummVM / Ports

- ScummVM extras (fonts, …): `/userdata/bios/scummvm/extra/`.
- PortMaster / script ports: `/userdata/roms/ports/` (`.sh` and the game data
  the script expects next to it).

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
