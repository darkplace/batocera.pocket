# Changelog — batocera.pocket

Notes for **GitHub Releases** and the README. Each version uses `<details>`
blocks so the page stays readable: **Updates** and **Fixes**.

When you publish a tag, copy the matching section into the Release body.

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
