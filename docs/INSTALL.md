# Installing batocera.pocket

## Requirements

- microSD card (64 GB+ recommended)
- Card reader
- On Windows: [7-Zip](https://www.7-zip.org/) or WinZip, and [balenaEtcher](https://etcher.balena.io/)

## Steps (Windows)

1. Download the **complete** multi-volume ZIP set from the [latest release](https://github.com/darkplace/batocera.pocket/releases/latest) (`.zip` + `.z01` + `.z02` + …).
2. Place all volumes in one folder.
3. Open the `.zip` in 7-Zip / WinZip → **Extract**.
4. Flash the extracted `.img.gz` with balenaEtcher to the microSD card.
5. Insert the card into the device and power on.

## First boot

- The first boot may take several minutes (filesystem resize / datainit).
- Default SSH: user `root`, password `linux` (change it if the device is on a shared network).
- How to add ROMs (consoles + Windows / Steam / Heroic / Lutris): see [ADDING_ROMS.md](ADDING_ROMS.md) (same for sm8550 and sm8750).
- Hotkeys / FAQ (Odin 2 & 3 mappings): see [CONTROLS_AND_FAQ.md](CONTROLS_AND_FAQ.md).
- Release notes (collapsible Updates / Fixes): see [CHANGELOG.md](CHANGELOG.md).

## Linux / macOS

You can also concatenate raw `.part*` OTA files or use `unzip` on a multi-volume ZIP (Info-ZIP / 7-Zip). For flashing, `dd` or balenaEtcher both work after you have a single `.img.gz` / `.img`.
