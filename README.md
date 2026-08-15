<p align="center">
  <img src="media/batocera.pocket-logo.png" alt="batocera.pocket" width="640">
</p>

<h1 align="center">batocera.pocket</h1>

<p align="center">
  <img src="https://img.shields.io/badge/Batocera-v44-5b2be7" alt="Batocera v44">
  <img src="https://img.shields.io/badge/SoC-SM8750%20%C2%B7%20SM8550%20%C2%B7%20SM8250-0a9fb0" alt="SoCs">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPLv2-blue" alt="License GPLv2"></a>
</p>

<p align="center">
  <!-- Per-board tags only — never /releases/latest (OTA is SoC-scoped). -->
  <a href="https://github.com/darkplace/batocera.pocket/releases/tag/v44-sm8750-20260815"><img src="https://img.shields.io/github/v/release/darkplace/batocera.pocket?filter=v44-sm8750-*&amp;label=SM8750&amp;color=2ea043" alt="SM8750 release"></a>
  <a href="https://github.com/darkplace/batocera.pocket/releases/tag/v44-sm8550-20260818"><img src="https://img.shields.io/github/v/release/darkplace/batocera.pocket?filter=v44-sm8550-*&amp;label=SM8550&amp;color=2ea043" alt="SM8550 release"></a>
  <a href="https://github.com/darkplace/batocera.pocket/releases/tag/v44-sm8250-20260811"><img src="https://img.shields.io/github/v/release/darkplace/batocera.pocket?filter=v44-sm8250-*&amp;label=SM8250&amp;color=c69026" alt="SM8250 release"></a>
</p>

<p align="center">
  Community <b>Batocera</b> images for <b>Qualcomm Snapdragon</b> handhelds — continuing the Qualcomm Batocera work started by <b>suckbluefrog</b>.
</p>

Built on [Batocera.linux](https://batocera.org/) / [Buildroot](https://buildroot.org/). On top of the normal Batocera stack: Steam GamepadUI (SteamOS-style session via gamescope), FEX with a Fedora rootfs squashfs for x86_64 Proton/Windows titles, and LXC desktops where the board supports them.

---

### ⚠️ Important Note on Bootloader
This Batocera build **requires** the [ROCKNIX ABL](https://github.com/ROCKNIX/abl). Make sure your device's boot partition is updated with the ROCKNIX ABL before flashing this image.

---

## Devices & builds

Images are per SoC. Every build ships the full Batocera stack (RetroArch cores, Wine/Proton tooling, etc.); the lists below highlight the headline ports and extras.

> **Testing status** — **AYN Odin 3 (SM8750)** and **AYN Odin 2 Portal (SM8550)** are smoke-tested via community beta testers. Other SM8550 devices and **SM8250** remain community / limited testing: flash at your own risk and please report back.

### SM8750 — `batocera-sm8750` &nbsp;·&nbsp; ✅ Smoke-tested

| Device | Status | Beta tester |
|--------|--------|-------------|
| AYN Odin 3 | ✅ Tested | **b_bloodcart99x**, **The Janitor** |

> Official build: [`v44-sm8750-20260815`](https://github.com/darkplace/batocera.pocket/releases/tag/v44-sm8750-20260815) (**OTA + flash**). Previous: `v44-sm8750-20260814`.

<details>
<summary><b>Emulators &amp; extras</b></summary>

- Steam (GamepadUI / gamescope)
- FEX + Fedora squashfs
- Arch Plasma LXC · Ubuntu Plasma LXC
- Lutris
- Eden · Yuzu · Ryujinx
- Dolphin · RPCS3
- shadPS4 (FEX)
- AetherSX2 / ARMSX2 · PCSX2 · Play!
- Cemu · Vita3K · Xemu
- Xenia Canary / Edge
- *+ the rest of the Batocera set for this board*

**Not included:** Waydroid (disabled on Odin 3 / SM8750)
</details>

### SM8550 — `batocera-sm8550` &nbsp;·&nbsp; ✅ Tested (Odin 2 Portal)

| Device | Status | Beta tester |
|--------|--------|-------------|
| AYN Odin 2 Portal | ✅ Tested | **Colt45RPM**, **Jordanius** |
| AYN Odin 2 / Mini | Community | — |
| AYN Thor | Community | — |
| AYANEO Pocket ACE / DS / DMG / EVO / S2K | Community | — |
| Retroid Pocket 6 (+ TOP-DPAD DTB) | Community | — |

> Deep sleep (S2RAM) is intentionally left off; the board uses the working s2idle path. Official build: [`v44-sm8550-20260818`](https://github.com/darkplace/batocera.pocket/releases/tag/v44-sm8550-20260818) (**OTA + flash**, **Golden Rabbit**). Previous: `v44-sm8550-20260817` (stick LEDs + analog DZ).

<details>
<summary><b>Emulators &amp; extras</b></summary>

- Steam (GamepadUI / gamescope)
- FEX + Fedora squashfs
- Arch Plasma LXC · Ubuntu Plasma LXC
- Lutris · Waydroid
- Eden · Yuzu · Ryujinx
- Dolphin · RPCS3
- shadPS4 (FEX)
- AetherSX2 / ARMSX2 · PCSX2 · Play!
- Cemu · Vita3K · Xemu
- Xenia Canary / Edge
- *+ the rest of the Batocera set for this board*
</details>

### SM8250 — `batocera-sm8250` &nbsp;·&nbsp; ⚠️ Untested

**Devices:** Retroid Pocket 5 · Mini · Mini V2 · Flip 2.

> No SM8250 hardware is available to the maintainer, so this image is **untested**. Flash at your own risk and please report back.

<details>
<summary><b>Emulators &amp; extras</b></summary>

- Steam (GamepadUI / gamescope)
- FEX + Fedora squashfs
- Eden · Yuzu · Ryujinx
- Dolphin · RPCS3
- AetherSX2 / ARMSX2
- Cemu · Vita3K · Xemu
- Xenia Edge
- *+ the rest of the Batocera set for this board*

**Not included:** Waydroid · Arch / Ubuntu Plasma LXC · Lutris · shadPS4 · PCSX2 / Play!
</details>

### Other (best-effort)

AYN Odin 1 (SD845), Radxa Dragon Q6A (QCS6490) — in-tree, not a focus of current builds.

---

## Preview

In-device footage ([@lukemotionYT](https://www.youtube.com/@lukemotionYT)) — performance examples, no commentary required:

<p align="center">
  <a href="https://www.youtube.com/watch?v=vI6bw7iIS5s"><img src="https://img.youtube.com/vi/vI6bw7iIS5s/hqdefault.jpg" alt="Gameplay preview 1" width="32%"></a>
  <a href="https://www.youtube.com/watch?v=XKcJsCEH1OY"><img src="https://img.youtube.com/vi/XKcJsCEH1OY/hqdefault.jpg" alt="Gameplay preview 2" width="32%"></a>
  <a href="https://www.youtube.com/watch?v=qwIUdKckz4w"><img src="https://img.youtube.com/vi/qwIUdKckz4w/hqdefault.jpg" alt="Gameplay preview 3" width="32%"></a>
</p>

---

## What's new — August 2026

Per-board GitHub tags so OTA only matches the device SoC. Full history with collapsible **Updates** / **Fixes**: [docs/CHANGELOG.md](docs/CHANGELOG.md).

| Tag | Board | Status |
|-----|--------|--------|
| `v44-sm8750-20260816` | SM8750 (Odin 3) | ✅ Tested — **OTA + flash** (**Golden Rabbit**) |
| `v44-sm8750-20260815` | SM8750 (Odin 3) | ✅ Tested — **OTA + flash** (Steam touch / OSK) |
| `v44-sm8750-20260814` | SM8750 (Odin 3) | OTA RC1 |
| `v44-sm8550-20260818` | SM8550 (Odin 2 Portal) | 🔨 **Golden Rabbit** (building) |
| `v44-sm8550-20260817` | SM8550 (Odin 2 Portal) | ✅ Tested — **OTA + flash** (stick LEDs + analog DZ) |
| `v44-sm8550-20260816` | SM8550 (Odin 2 Portal) | OTA (Steam touch / OSK) |
| `v44-sm8550-20260815` | SM8550 (Odin 2 Portal) | OTA (Waydroid / WiFi / Screenscraper) |
| `v44-sm8550-20260813` | SM8550 (Odin 2 Portal) | Flash baseline |
| `v44-sm8250-20260811` | SM8250 | ⚠️ Untested |
| `v44-sm8750-20260809` | SM8750 (Odin 3) | Flash baseline (superseded for OTA) |

### Since `v44-sm8550-20260817` (Odin 2 Portal) — `v44-sm8550-20260818` **Golden Rabbit**

<details>
<summary><b>Updates</b></summary>

- Same **Golden Rabbit** Steam ARM cut as sm8750 (`Proton 11 ★`, MangoApp ARM default, decky-bcc ≥ 0.2.18 docs).
- Keeps Portal stick LED groups + rsinput deadzone from `20260817`.

</details>

<details>
<summary><b>Fixes</b></summary>

- Proton 11 AppError_51 / SLR 4185400 from AppID symlink registration.
- MangoHud never appearing in steam-direct on ARM.

</details>

### Since `v44-sm8750-20260815` (Odin 3) — `v44-sm8750-20260816` **Golden Rabbit**

<details>
<summary><b>Updates</b></summary>

- Public codename **Golden Rabbit** (`44-dev-pocket-golden-rabbit`).
- Proton 11 ★ as custom tool (no SLR 4185400 merge); MangoApp on by default on ARM Steam.
- Batocera Control / decky-bcc 0.2.18 shortcuts documented (QAM overlay, M1+M2, Power, LSFG).

</details>

<details>
<summary><b>Fixes</b></summary>

- Proton 11 AppError_51 from AppID/symlink registration.
- MangoHud never appearing in steam-direct (MangoApp defaulted off).

</details>

### Since `v44-sm8750-20260814` (Odin 3) — `v44-sm8750-20260815`

<details>
<summary><b>Updates</b></summary>

- **gamescope** Wayland `wl_touch` for Steam GamepadUI on Odin 3.
- System **OSK** symbol layers (`123` / `@`).

</details>

<details>
<summary><b>Fixes</b></summary>

- Steam OSK vanishing while typing (Minecraft / MS login).
- System OSK missing `@` / specials after base refresh.

</details>

### Since `v44-sm8550-20260816` (Odin 2 Portal) — `v44-sm8550-20260817`

<details>
<summary><b>Updates</b></summary>

- Stick RGB groups (`LEDS_GROUP_MULTICOLOR`) + LED userspace prefers `rgb:l*`/`rgb:r*`.
- rsinput ranges/deadzone (±1024, DZ 70) like sm8750.

</details>

<details>
<summary><b>Fixes</b></summary>

- Stick LED only drove power LED.
- Left analog constant left/down (deadzone 0).

</details>

### Since `v44-sm8550-20260815` (Odin 2 Portal) — `v44-sm8550-20260816`

<details>
<summary><b>Updates</b></summary>

- **gamescope** Wayland `wl_touch` for Steam GamepadUI.
- System **OSK** symbol layers (`123` / `@`).

</details>

<details>
<summary><b>Fixes</b></summary>

- Steam OSK vanishing while typing.
- System OSK missing `@` / specials after base refresh.

</details>

### Since `v44-sm8550-20260813` (Odin 2 Portal) — `v44-sm8550-20260815`

<details>
<summary><b>Updates</b></summary>

- **In-device OTA** for SM8550 (`boot.tar.xz` parts on the Release).
- **Waydroid** 1.6.3.
- **WiFi resilience** (dead-air / IPv4LL / country stamp) aligned with sm8750.

</details>

<details>
<summary><b>Fixes</b></summary>

- Fixed Screenscraper support.
- **AetherSX2 / RPCS3** configgen fixes.
- WiFi zombie “connected but no Internet” recovery.

</details>

### Since `v44-sm8750-20260809` (Odin 3) — `v44-sm8750-20260814`

<details>
<summary><b>Updates</b></summary>

- **In-device OTA** for SM8750 (`boot.tar.xz` parts on the Release) — use **Updates** in EmulationStation after this build (or flash once from the ZIP set).
- **WiFi resilience** on Odin 3 (dead-air / no IPv4 / weak-signal recovery).
- **Docs pack:** ROMs, controls/FAQ, changelog — see [Docs](#docs) below.
- **Configure Heroic / Lutris** helpers under Apps & Tools.
- Fan init ordering (`S12qcom-fan`).

</details>

<details>
<summary><b>Fixes</b></summary>

- Fixed Screenscraper support in EmulationStation.
- WiFi “connected but no Internet” zombie on Odin 3.
- **AetherSX2:** configgen crash (`option values must be strings` → `get_str`).
- **RPCS3:** configgen patch path (`RPCS3_PATCH_YML` / `patch.yml`).
- Brightness **Back** after Steam / force-kill; charge-limit helper hardening.

</details>

<details>
<summary><b>Earlier August baselines (all boards)</b></summary>

- **Fan modes** in Control Deck (**Home + A → Fan Mode**): Silent, Auto, Aggressive, Off — persist across reboots.
- Default CPU governor **`ondemand`** on Qualcomm boards.
- **OTA** per-board tags (`v44-<soc>-YYYYMMDD`).
- **UI scaling** for Apps/Tools and Arch/Ubuntu Plasma LXC.
- Wine / `wine64` runner normalization + WoW64 fallback.
- Fan auto at boot; updater false-positives; force quit (`L1 + R1 + Select + Start`).

</details>

---

## First launch & hotkeys

The first start of **Steam** and of the **Arch / Ubuntu Plasma LXC** containers can take a while (downloads, rootfs setup, first boot). That is normal — let them finish.

**Container initialization:** first time in a container, switch to keyboard mode and press `Enter` repeatedly to progress.

**Home** = physical Guide / Mode button on the pad (`hotkey` in Batocera, SDL button id **9**).  
Same mapping on **Odin 2** and **Odin 3** (GUID `03000000202000000130000001000000`).

Verified against `hotkeys.keys` + Odin `hotkeygen` mappings (see [docs/CONTROLS_AND_FAQ.md](docs/CONTROLS_AND_FAQ.md) for the full FAQ):

| Combo | Action |
|-------|--------|
| **Home + Start** | Exit emulator (clean) |
| **L1 + Select + Start** | Force quit (`emukill`) |
| **L1 + R1 + Select + Start** | Force quit (same; harder by accident) |
| **R1 + Select + Start** | Toggle mouse mode (evmapy) |
| **Home + Start + Select** | Toggle mouse mode (`hotkeygen`) — *not* Home+Select+Start |
| **Home + A** | Batocera Control Center / Control Deck |
| **Home + B** | Emulator / options menu |
| **Home + Touch** | On-screen keyboard (hold Home, tap the screen) |
| **Home + Y** | Save state |
| **Home + X** | Load state |
| **Home + ↑ / ↓** | Previous / next save slot |
| **Home + ← / →** | Rewind / fast-forward (if the core supports it) |
| **Home + L1** | Screenshot |
| **Back** (next to Home on Odin) | Brightness cycle in ES |

In **Steam** (GamepadUI), **Back** becomes the Steam chord (not brightness). After Steam exit / force-kill, brightness is restored automatically.

Steam + **Batocera Control** (decky-bcc) shortcuts: **⋯ → Performance Overlay** (MangoHud), **M1+M2** toggle HUD, plugin tabs for Power / Compatibility / LSFG — see [docs/CONTROLS_AND_FAQ.md](docs/CONTROLS_AND_FAQ.md#steam-gamepadui--batocera-control-decky-bcc).

### Mini FAQ (start here)

| Question | Doc |
|----------|-----|
| How do I flash / first boot? | [docs/INSTALL.md](docs/INSTALL.md) |
| Where do ROMs / Windows / Steam / Heroic / Lutris go? | [docs/ADDING_ROMS.md](docs/ADDING_ROMS.md) |
| Hotkeys, brightness after Steam, GameCube folder, WiFi dead-air… | [docs/CONTROLS_AND_FAQ.md](docs/CONTROLS_AND_FAQ.md) |
| How do in-device Updates (OTA) work? | [docs/UPDATES.md](docs/UPDATES.md) |
| What changed in each release? | [docs/CHANGELOG.md](docs/CHANGELOG.md) |
| Build from source? | [docs/BUILD.md](docs/BUILD.md) |

---

## Docs

| Doc | Content |
|-----|---------|
| [docs/INSTALL.md](docs/INSTALL.md) | Flash / first boot |
| [docs/ADDING_ROMS.md](docs/ADDING_ROMS.md) | ROM paths (consoles + PC platforms) |
| [docs/CONTROLS_AND_FAQ.md](docs/CONTROLS_AND_FAQ.md) | Odin mappings + FAQ |
| [docs/UPDATES.md](docs/UPDATES.md) | OTA from GitHub Releases |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | Per-release Updates / Fixes (collapsible) |
| [docs/BUILD.md](docs/BUILD.md) | Building from source |

---

## Extras

- [decky-bcc](https://github.com/darkplace/decky-bcc) — Decky Loader install helper for Steam

---

## Download & flash

1. Open [Releases](https://github.com/darkplace/batocera.pocket/releases) and pick the tag for **your SoC** (`v44-sm8750-…`, `v44-sm8550-…`, or `v44-sm8250-…`). Do not install another board’s image.
2. **Fresh install (Windows):** download every volume (`.zip` + `.z01`, `.z02`, …). Keep them in the same folder; do not rename. Extract the `.zip` with 7-Zip or WinZip → one `.img.gz`. Write that `.img.gz` to a microSD with balenaEtcher, Rufus, or Raspberry Pi Imager.
3. **In-device OTA (already on batocera.pocket):** EmulationStation → Updates. Releases that ship OTA include `batocera.version`, `boot.tar.xz.md5`, and `boot.tar.xz.part01…` (see [docs/UPDATES.md](docs/UPDATES.md)). A device only sees tags for its SoC.

Boot from the card on the device (same flow as other Batocera Qualcomm builds).

---

## Support

Bugs and feedback: **@lukemotion** on Discord (device + image version + logs under `/userdata/system/logs/` help a lot). Check [docs/CONTROLS_AND_FAQ.md](docs/CONTROLS_AND_FAQ.md) before opening a duplicate issue.

---

## Credits

- Batocera groundwork: [suckbluefrog](https://github.com/suckbluefrog)
- Upstream: [Batocera.linux](https://batocera.org/)
- ABL (Bootloader): [ROCKNIX](https://rocknix.org/)
- **Beta testers**
  - **Colt45RPM** — SM8550 (AYN Odin 2 Portal)
  - **Jordanius** — SM8550 (AYN Odin 2 Portal)
  - **b_bloodcart99x** — SM8750 (AYN Odin 3)
  - **The Janitor** — SM8750 (AYN Odin 3)

## License

batocera.pocket is licensed under the **GNU General Public License v2.0 (GPLv2)**, same as [Batocera.linux](https://github.com/batocera-linux/batocera.linux). See [LICENSE](LICENSE) for the full text. Individual packages may carry additional licenses; see each package directory.
