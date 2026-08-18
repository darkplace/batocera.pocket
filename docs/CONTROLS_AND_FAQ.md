# Controls and FAQ (Odin 2 / Odin 3)

Quick reference for **real** AYN pad mappings on batocera.pocket (sm8550 /
sm8750). GUIDs and combos come from `es_input.cfg`, `evmapy/hotkeys.keys`, and
`hotkeygen` on device.

> **Home** = Guide / Mode button on the pad (physical home / logo).
> In Batocera this is `hotkey` (SDL button id **9**, code **316**).

Recognized devices:

| Name | GUID |
|------|------|
| AYN Odin2 Gamepad | `03000000202000000130000001000000` |
| AYN Odin3 Gamepad | `03000000202000000130000001000000` |

(Same GUID on both; ES mapping is identical.)

---

## Essential hotkeys (EmulationStation / emulators)

| Combo | Action |
|-------|--------|
| **Home + Start** | Exit emulator (clean exit) |
| **L1 + Select + Start** | Force quit (`batocera-es-swissknife --emukill`) |
| **L1 + R1 + Select + Start** | Force quit (same; harder to press by accident) |
| **R1 + Select + Start** | Toggle mouse mode |
| **Home + Start + Select** | Toggle mouse mode (via `hotkeygen`) |
| **Home + A** | Batocera Control Center / Control Deck |
| **Home + B** | Emulator / options menu |
| **Home + Touch** | On-screen keyboard (hold Home, tap the screen) |
| **Home + Y** | Save state |
| **Home + X** | Load state |
| **Home + ↑ / ↓** | Previous / next save slot |
| **Home + ← / →** | Rewind / fast-forward (if the core supports it) |
| **Home + L1** | Screenshot |
| **Back** (next to Home on Odin) | Brightness cycle (`brightness-cycle`) |

In **Steam** (GamepadUI), Back becomes `steam_chord` (not brightness).
On Steam exit / force-kill, `51-odin-brightness-hotkeys.sh` restores the ES
mapping so brightness works again.

---

## Steam GamepadUI + Batocera Control (decky-bcc)

Open the plugin from Steam **Quick Access (⋯) → Batocera Control**.

| Shortcut / UI | Action |
|---------------|--------|
| **⋯ → Performance → Performance Overlay** | Steam-native MangoHud / FPS overlay level |
| **M1 + M2** | Toggle MangoHud show/hide (`mangohudctl`), when bound in Batocera Control → Back Paddles (recommended default) |
| **⋯ → Batocera Control → Compatibility** | Proton default, per-game tweaks, env vars, **Re-apply** nice/affinity to a running game |
| **⋯ → Batocera Control → Power** | eco / balanced / performance (governor + fan on Qualcomm) |
| **⋯ → Batocera Control → LSFG** | Lossless Scaling VK (DLL at `/userdata/system/wine/lossless-scaling/Lossless.dll`) |
| **⋯ → Batocera Control → Settings → Sleep Mode** | `s2idle` / `deep` (persisted across reboot) |

MangoApp must be running inside gamescope for the overlay and paddle toggle to
work. Current ARM SteamOS / steam-direct sessions enable it by default; after
changing that, restart Steam once.

Full plugin docs: [darkplace/decky-bcc](https://github.com/darkplace/decky-bcc).

---

## Ports X86 Translator (Box64 ↔ FEX)

On **aarch64** (Odin 2 / Odin 3), x86/x86_64 **Ports** binaries need a binfmt
translator. Only one should own ELF launch at a time (same idea as **Windows
Translator** for Wine).

| Where | What it does |
|-------|----------------|
| **Tools → Ports X86 Translator** | Cycles **Box64 ↔ FEX**, saves `ports.ports_translator`, and applies binfmt now (icon + description like other Tools scrapes). |
| **Ports game → Advanced Options → PORTS TRANSLATOR** | Per-game / system choice (`box64` or `fex`). Applied again when the port launches (`shGenerator` → `batocera-ports-translator`). |

- **Box64 (default):** stops FEX binfmt; Box64 handles x86/x86_64.
- **FEX-Emu:** stops Box64 binfmt; FEX handles them (needs `fex-emu` + rootfs).

After an OTA on a device that already had a Tools folder: if the launcher is
missing, copy `Ports_X86_Translator.sh` (+ `.keys`, `images/windows-translator.png`)
and the gamelist entry from `/usr/share/batocera/datainit/roms/emulator/` into
`/userdata/roms/emulator/`, then refresh Tools.

---

## Batocera logical name ↔ physical button

| Batocera name | Typical Odin button |
|---------------|---------------------|
| `hotkey` | Home / Guide / Mode |
| `pageup` | L1 |
| `pagedown` | R1 |
| `l2` / `r2` | L2 / R2 (analog axes) |
| `l3` / `r3` | Stick clicks |
| `select` / `start` | Select / Start |
| `a` `b` `x` `y` | Face buttons (Xbox layout: A bottom, B right, …) |

---

<details>
<summary><b>FAQ — Controls and input</b></summary>

### Brightness button “dies” after Steam or a force quit

After Steam or `L1+R1+Select+Start`, the `.mapping.steam` profile can stick, or
`hotkeygen` may not come back. Recent builds restore the map via
`/userdata/system/scripts/51-odin-brightness-hotkeys.sh` on `gameStop` /
forcekill. If it stays dead: restart ES or the device; confirm the script
exists under `/userdata/system/scripts/`.

### Mouse mode will not turn off / cursor stuck

Press **R1 + Select + Start** (or **Home + Start + Select**) again.
If that fails: `batocera-mouse-mode disable` over SSH.

### Force quit does not close Wine / Steam / an emulator

Use **L1 + R1 + Select + Start** (not only Home+Start). Home+Start is a polite
exit; force kill runs `emukill`.

### Can I remap Home?

Yes — EmulationStation → Controllers. If you change the `hotkey` button, **all**
Home+… combos move with it.

</details>

<details>
<summary><b>FAQ — ROMs, paths, and systems</b></summary>

### A system does not show up in ES

Only systems with **at least one game** (valid extension) are listed. A lone
`_info.txt` does not count. After copying: update gamelist / restart ES.
Guide: [ADDING_ROMS.md](ADDING_ROMS.md).

### GameCube cannot find the game

Official folder is `/userdata/roms/gamecube/` (not `gc`).

### Where do Windows / Steam / Heroic / Lutris go?

| Platform | Path |
|----------|------|
| Wine / `.pc` | `/userdata/roms/windows/` |
| Steam | `/userdata/roms/steam/` |
| Heroic | `/userdata/roms/heroic/` |
| Lutris | `/userdata/roms/lutris/` |
| Discord (Vesktop) | **Apps** — `/userdata/roms/apps/Discord.sh` |

Details and extensions: [ADDING_ROMS.md](ADDING_ROMS.md).

### Discord (Apps)

Vesktop installs/updates from Flathub in the background (the Batocera launcher,
OSK shift, and quit hotkeys stay in `/usr/bin` — a Discord/Vesktop update does
not overwrite them). While Discord is open, **Home + Start** or **Hotkey + B**
quits, with mouse-mode on or off. Scale is `--force-device-scale-factor`
(default **1.35×**); override with `/userdata/system/configs/apps-hotfix/vesktop-ui-scale`.
The on-screen keyboard lifts Discord once to sit above the keys.

### BIOS

`/userdata/bios/` — **Settings → System → Check BIOS** or the
[Batocera wiki](https://wiki.batocera.org/batocera-os:add_games_bios#bios).

</details>

<details>
<summary><b>FAQ — WiFi, fan, boot</b></summary>

### WiFi “connected” but no Internet (Odin 3 / sm8750)

The `S09sm8750-wifi-resilience` watchdog detects association without usable
IPv4, no gateway path (“dead-air”), and weak signal; it forces reassociation or
a `batocera-wifi` toggle. Logs: `/userdata/system/logs/wifi/`.
If it persists after a recent OTA: toggle WiFi in Settings or reboot.

### Fan does not start / stuck on manual PWM

On August 2026+ builds, auto-fan starts at boot. **Mode** (Silent / Auto /
Aggressive / Off) is set via **Home + A → Control Center → Fan Mode** and
persists in `fan.state`. Fan +/- in that same panel is a manual override.
Curve *points* for Silent / Auto / Aggressive can be edited in Batocera
Control → **Fans**; that does not change the current mode.

### First Steam or Plasma LXC launch takes a long time

Normal (downloads / rootfs / first boot). In containers: keyboard mode and press
`Enter` repeatedly to walk through initialization.

### Splash / ES does not start after a hotfix

S31 fail-closed boot (P01+ builds): if splash/ES fails, the system still
continues; check `/userdata/system/logs/` and avoid custom generators that block
ES startup.

</details>

<details>
<summary><b>FAQ — Updates and support</b></summary>

### OTA offers an older build / I see no updates

Use only tags for **your SoC** (`v44-sm8750-…`, `v44-sm8550-…`, …). See
[UPDATES.md](UPDATES.md). Older images that still used `/releases/latest` need
the per-board prep (HOTPATCH).

### What to send when asking for help

Device + image tag + logs under `/userdata/system/logs/`
(Discord: **@lukemotion**).

</details>

---

## References

- [ADDING_ROMS.md](ADDING_ROMS.md) — ROMs and PC platforms  
- [INSTALL.md](INSTALL.md) — Flashing  
- [UPDATES.md](UPDATES.md) — OTA  
- [CHANGELOG.md](CHANGELOG.md) — Per-release Updates / Fixes (collapsible)
