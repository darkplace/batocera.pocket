# Changelog — batocera.pocket

Notes for **GitHub Releases** and the README. Each version uses `<details>`
blocks so the page stays readable: **Updates** and **Fixes**.

When you publish a tag, copy the matching section into the Release body.

---

## `v44-sm8750-20260818` — Odin 3 (Discord / Vesktop + OSK sway shift)

> On top of `v44-sm8750-20260817` (OSK `@` + QAM Back + screensaver).

<details>
<summary><b>Updates</b></summary>

- **Apps → Discord:** Vesktop Flatpak from Flathub, auto-installed/updated at boot.
  UI scale via Chromium `--force-device-scale-factor` (default **1.35×**, not Sway output scale).
- **Quit Discord:** **Home + Start** (or **Hotkey + B**) with mouse-mode on or off.
- **On-screen keyboard:** one-shot Sway shift to the workspace exclusive zone
  (~250px on Odin) so Discord sits flush above the keyboard without wobble.

</details>

<details>
<summary><b>Fixes</b></summary>

- Vesktop launch on Sway: valid Flatpak sockets, Chromium flags after the app ID,
  `XDG_RUNTIME_DIR=/run/user/0`, and `--no-sandbox` when running as root.
- Flatpak gamelist hook maps Vesktop/Vencord icons to the bundled Discord artwork.
- Mouse-mode exclusive grab no longer swallows Home+Start (emukill works after ungrab).
- OSK no longer re-applies window geometry in a loop (Electron CSD fight / wobble).

</details>

---

## `v44-sm8750-20260819` / `v44-sm8550-20260819` — Ports translator + Proton tips

> Builds on OSK/QAM/screensaver (sm8750) and Golden Rabbit Steam ARM (both boards).

<details>
<summary><b>Updates</b></summary>

- **Ports X86 Translator:** Tools → `Ports_X86_Translator` toggles **Box64 ↔ FEX**
  binfmt (mutual exclusion, same idea as Windows Translator). Also set per-game /
  system under EmulationStation **Advanced Options → PORTS TRANSLATOR**.
  See [CONTROLS_AND_FAQ.md](CONTROLS_AND_FAQ.md).
- **Steam Proton tips:** Valve ARM64, CachyOS tip, GE-Proton tip, and Proton
  Experimental (x86 · FEX/SLR · Rockstar) use `★ Recommended` / `★ Rockstar`
  display names; tip folders `proton_cachyos_arm64` / `proton_ge_arm64` so Steam’s
  picker lists them with `proton11_arm64` / `proton_experimental_x86`.
- **xenia-edge:** XenDroid FIFO + SPIR-V bits; sm8750 (and sm8550) default
  Xbox 360 core → `xenia-edge`.

</details>

<details>
<summary><b>Fixes</b></summary>

- GE / CachyOS no longer hide at the bottom of Steam’s compatibility list solely
  because of long `GE-Proton*` / `proton-cachyos-*` folder names.
- After OTA, if Tools does not show Ports Translator yet, copy from
  `/usr/share/batocera/datainit/roms/emulator/` into `/userdata/roms/emulator/`
  (userdata Tools is not overwritten on upgrade).

</details>

---

## `v44-sm8750-20260817` — Odin 3 (OSK `@` + QAM Back + screensaver)

> On top of Golden Rabbit `v44-sm8750-20260816`.

<details>
<summary><b>Updates</b></summary>

- **Steam QAM:** physical **Back** opens Quick Access via CEF (`batocera-steam-qam` +
  `batocera-steam-back-qam`); Home stays the native Steam left menu.
- **On-screen keyboard:** special / `@` keys emit Shift+digit (no more typing `2`
  instead of `@`).
- **EmulationStation:** dim/black screensaver covers the full rotated Wayland panel
  (Odin 3).

</details>

<details>
<summary><b>Fixes</b></summary>

- QAM keyboard chords unreliable under nested gamescope (Ctrl+2 / Ctrl+Shift+Tab fight).
- hotkeygen: string actions fire on keydown; init avoids duplicate `--permanent` daemons.
- OSK patches applied from package root (Buildroot does not recurse `patches/`).

</details>

---

## Template (copy for the next release)

```markdown
## v44-<soc>-YYYYMMDD — <short title>

<details>
<summary><b>Updates</b></summary>

- …

</details>

<details>
<summary><b>Fixes</b></summary>

- …

</details>
```

---

## `v44-sm8550-20260818` — **Golden Rabbit** (Odin 2 Portal)

> Same **Golden Rabbit** Steam ARM cut as sm8750 `v44-sm8750-20260816`, on top of
> the Portal stick LED + rsinput baseline (`v44-sm8550-20260817`).

<details>
<summary><b>Updates</b></summary>

- **Codename:** `44-dev-pocket-golden-rabbit-<commit>` (public name **Golden Rabbit**).
- **Proton 11.0 (ARM64) ★ recommended:** pure custom compatibility tool (no
  Steam AppID merge with depot 4628740 / missing SLR 4185400).
- **MangoApp:** on by default on ARM SteamOS / steam-direct.
- **Docs:** Steam + Batocera Control shortcuts in
  [CONTROLS_AND_FAQ.md](CONTROLS_AND_FAQ.md).
- Expects **decky-bcc ≥ 0.2.18**.

</details>

<details>
<summary><b>Fixes</b></summary>

- Proton 11 custom registration no longer symlink-merges into
  `steamapps/common` (AppError_51 / SLR 4185400).
- Steam direct session no longer defaults MangoApp off on ARM.

</details>

---

## `v44-sm8750-20260816` — **Golden Rabbit** (Odin 3)

> Public codename: **Golden Rabbit**. Steam ARM Proton / Batocera Control / MangoApp
> wave after Silksong smoke (Proton 11 ★, decky-bcc 0.2.18, LSFG per-game).

<details>
<summary><b>Updates</b></summary>

- **Codename:** `44-dev-pocket-golden-rabbit-<commit>` (public name **Golden Rabbit**).
- **Proton 11.0 (ARM64) ★ recommended:** register as a pure custom compatibility
  tool (no Steam AppID merge with depot 4628740 / missing SLR 4185400).
- **MangoApp:** enable by default on ARM SteamOS / steam-direct so QAM Performance
  Overlay and `mangohudctl` / Decky paddle toggles work.
- **Docs:** Steam + Batocera Control shortcuts in
  [CONTROLS_AND_FAQ.md](CONTROLS_AND_FAQ.md) (QAM overlay, M1+M2 MangoHud, Power,
  LSFG, Sleep).
- Expects **decky-bcc ≥ 0.2.18** (Non-Steam signed/unsigned AppIDs, LSFG, env,
  Performance Re-apply).

</details>

<details>
<summary><b>Fixes</b></summary>

- Official Proton 11 custom registration no longer symlink-merges into
  `steamapps/common` (that forced AppError_51 / SLR 4185400).
- Steam direct session defaulted MangoApp off on ARM, so the HUD never appeared.

</details>

---

## `v44-sm8750-20260815` — Odin 3 (Steam touch + OSK)

> OTA cut after `v44-sm8750-20260814`. Steam GamepadUI on-screen keyboard /
> touch via gamescope Wayland `wl_touch`, plus system OSK symbol layers (`@`).
> Smoke-tested on AYN Odin 3 (maintainer + **The Janitor**).

<details>
<summary><b>Updates</b></summary>

- **gamescope:** wire Wayland `wl_touch` for nested Steam GamepadUI (Odin 3).
- **On-screen keyboard:** start wvkbd with `simple,special` + landscape special
  layers so `123` reaches digits / `@`.
- Credits: beta tester **The Janitor** (Odin 3).

</details>

<details>
<summary><b>Fixes</b></summary>

- Steam / gamescope: OSK disappearing when typing (e.g. Minecraft Legends /
  Microsoft login) — touch was dropped on the nested Wayland backend.
- System OSK: missing special characters (no `@`) after Batocera base refresh.
- Does **not** enable gamescope `--default-touch-mode` passthrough (that path
  scrambled the Odin gamepad previously).

</details>

---

## `v44-sm8750-20260814` — Odin 3 (OTA RC1)

> First sm8750 **OTA-capable** public release after the 20260809 flash-only
> baseline. Smoke-tested on AYN Odin 3.

<details>
<summary><b>Updates</b></summary>

- **OTA payload** on GitHub (`boot.tar.xz.part01…` + `boot.tar.xz.md5` +
  `batocera.version`) so **Updates** in EmulationStation works for SM8750.
- **WiFi (sm8750):** stronger resilience watchdog (dead-air / no IPv4 / weak
  signal), faster recovery toggle, udev hook alignment.
- **Fan:** boot init renamed/ordered as `S12qcom-fan` (auto mode at boot).
- **Docs:** [ADDING_ROMS.md](ADDING_ROMS.md), [CONTROLS_AND_FAQ.md](CONTROLS_AND_FAQ.md),
  this CHANGELOG (collapsible Updates/Fixes).
- **Desktop helpers:** Configure Heroic / Lutris entries for Apps & Tools.
- Version string: `44-dev-pocket-rc1-<commit>` (this build:
  `44-dev-pocket-rc1-261f86cd80 2026/08/14 18:51`).

</details>

<details>
<summary><b>Fixes</b></summary>

- Fixed Screenscraper support (scraper source available again in EmulationStation).
- WiFi “connected but no Internet” zombie state on Odin 3.
- **AetherSX2 / configgen:** `TypeError: option values must be strings` —
  use `get_str(...)` for PS2 options.
- **RPCS3 / configgen:** expose `RPCS3_PATCH_YML` path constant used by the
  generator (patch.yml under userdata configs).
- OTA false-positive / per-board resolution (carried from August baselines).
- Brightness **Back** button after Steam / force-kill (hotkeygen restore).
- Charge-limit helper hardening on Qualcomm boards.

</details>

---

## `v44-sm8550-20260817` — Odin 2 Portal (stick LEDs + analog deadzone)

> OTA cut after `v44-sm8550-20260816`. Align Portal stick RGB with ROCKNIX
> (`LEDS_GROUP_MULTICOLOR`) and apply rsinput ranges/deadzone like sm8750.

<details>
<summary><b>Updates</b></summary>

- **Kernel sm8550:** `CONFIG_LEDS_GROUP_MULTICOLOR=y` so Portal/Thor
  `rgb:l*` / `rgb:r*` stick zones appear (HTR3212 groups).
- **batocera-led-handheld:** prefer stick group LEDs over bare `power-led`.
- **rsinput:** port `1300-input-rsinput-ranges.patch` (±1024, deadzone 70).

</details>

<details>
<summary><b>Fixes</b></summary>

- Stick LED enable only lit the power LED (colors on PMIC, rings dark).
- Left analog constant left/down with deadzone 0 (also visible in Windows).

</details>

---

## `v44-sm8550-20260816` — Odin 2 Portal (Steam touch + OSK)

> OTA cut after `v44-sm8550-20260815`. Same gamescope Wayland `wl_touch` +
> system OSK symbol layers as the sm8750 `20260815` cut (shared packages).

<details>
<summary><b>Updates</b></summary>

- **gamescope:** wire Wayland `wl_touch` for nested Steam GamepadUI.
- **On-screen keyboard:** start wvkbd with `simple,special` + landscape special
  layers so `123` reaches digits / `@`.

</details>

<details>
<summary><b>Fixes</b></summary>

- Steam / gamescope: OSK disappearing when typing (touch dropped on nested
  Wayland backend).
- System OSK: missing special characters (no `@`) after Batocera base refresh.
- Does **not** enable gamescope `--default-touch-mode` passthrough.

</details>

---

## `v44-sm8550-20260815` — Odin 2 Portal (OTA)

> First sm8550 **OTA-capable** public cut after the 20260813 flash-only
> baseline. Includes Screenscraper, Waydroid 1.6.3, and Wi-Fi resilience parity
> with the sm8750 watchdog. Intended as a single update for Portal testers.

<details>
<summary><b>Updates</b></summary>

- **OTA payload** (`boot.tar.xz.part01…` + `boot.tar.xz.md5` + `batocera.version`).
- **Waydroid** 1.6.2 → **1.6.3**.
- **WiFi (sm8550):** dead-air / IPv4LL recovery, country stamp (no churn), PS-off verify — aligned with sm8750.
- Version string: `44-dev-pocket-rc1-f065cf6fca 2026/08/14 21:55`.

</details>

<details>
<summary><b>Fixes</b></summary>

- Fixed Screenscraper support.
- **AetherSX2 / configgen:** `get_str(...)` for PS2 options.
- **RPCS3 / configgen:** `RPCS3_PATCH_YML` / patch.yml path.
- WiFi “connected but no Internet” zombie recovery improvements.

</details>

---

## `v44-sm8550-20260813` — Odin 2 Portal (baseline)

<details>
<summary><b>Updates</b></summary>

- Official sm8550 flash baseline (toolchain nosve / `sgdisk` SIGILL fix).
- Deep sleep (S2RAM) intentionally off; working s2idle path.
- Fan modes in Control Deck (**Home + A → Fan Mode**): Silent / Auto / Aggressive / Off; persists across reboots.
- Default CPU governor `ondemand` on Qualcomm boards (cooler idle).
- UI scaling for Apps/Tools and Plasma LXC desktops.
- Per-board OTA tags (`v44-sm8550-…`).

</details>

<details>
<summary><b>Fixes</b></summary>

- Automatic fan did not start at boot (stale manual PWM).
- Updater could offer an older build as “update available”.
- Per-board release resolution (devices blind to updates).
- Wine / `wine64` runner + WoW64 fallback for unified Wine builds.
- More reliable force quit with Wine.

</details>

---

## `v44-sm8750-20260809` — Odin 3 (baseline)

<details>
<summary><b>Updates</b></summary>

- sm8750 flash baseline, smoke-tested (Odin 3).
- Same Qualcomm extras package (Steam GamepadUI, FEX, Plasma LXC, Lutris, Eden, …). Waydroid not included on sm8750.
- Fan modes + gentler default curve.
- OTA tags `v44-sm8750-…` for this SoC only.

</details>

<details>
<summary><b>Fixes</b></summary>

- Fan auto at boot + mode persistence.
- OTA false-positive / per-board resolution (same as sm8550).
- Force-quit input and Odin brightness helpers (BTN_BACK) aligned with hotkeygen.

</details>

---

## `v44-sm8250-20260811` — Retroid Pocket 5 family (untested)

<details>
<summary><b>Updates</b></summary>

- sm8250 image published for the community (no maintainer hardware).

</details>

<details>
<summary><b>Fixes</b></summary>

- N/A — please report issues from real devices.

</details>

---

## August 2026 — cross-board summary (README)

<details>
<summary><b>Updates (Qualcomm boards in this cycle)</b></summary>

- Fan control in Control Deck + persistence.
- Default governor `ondemand`.
- Per-board OTA tags.
- UI scaling for Apps/Tools + Plasma LXC.
- Wine runner normalization.
- SM8750: first public OTA after flash baseline; WiFi resilience; docs pack.

</details>

<details>
<summary><b>Fixes (Qualcomm boards in this cycle)</b></summary>

- Fan did not start at boot.
- Updater offered older / cross-SoC builds.
- Force quit (including Wine).
- SM8750: WiFi dead-air; AetherSX2/RPCS3 configgen crashes.

</details>
