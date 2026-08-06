# batocera.pocket

Community Batocera builds for Qualcomm handhelds (AYN Odin 3 / SM8750 and related boards), continuing the work started by suckbluefrog under a new maintainer.

**Repository:** [github.com/darkplace/batocera.pocket](https://github.com/darkplace/batocera.pocket)

---

## Supported devices

| Device | SoC | Board id | Status |
|--------|-----|----------|--------|
| AYN Odin 3 | SM8750 | `cq8725s` | Primary target |
| Other Qualcomm boards in-tree | SM8550 / SM8250 / … | varies | Best-effort |

---

## Download & flash (Windows)

1. Open the latest [GitHub Release](https://github.com/darkplace/batocera.pocket/releases/latest).
2. Download **all** volumes of the image set, for example:
   - `batocera-sm8750-….zip`
   - `batocera-sm8750-….z01`
   - `batocera-sm8750-….z02`
   - (and any further `.z0N` files)
3. Keep every volume in the **same folder**. Do not rename them.
4. Open the `.zip` with **7-Zip** or **WinZip** and extract. You get a single `.img.gz`.
5. Flash that `.img.gz` to a microSD card with **balenaEtcher**, **Rufus**, or **Raspberry Pi Imager**.

No shell scripts are required on Windows.

---

## Updates (on device)

batocera.pocket uses **GitHub Releases** for OTA updates (`updates.url` → this repository).

- **stable** and **butterfly** resolve to the **same** latest release. There is no separate development channel.
- The device downloads `boot.tar.xz` (or split `boot.tar.xz.part01…N` when the archive exceeds GitHub’s 2 GB limit) and applies it like stock Batocera.

---

## Features (highlights)

- Steam / SteamOS-like GamepadUI via gamescope (Wayland nested on Odin 3)
- Touchscreen support in Steam (gamescope wl_touch)
- Arch Plasma LXC (desktop + Plasma Mobile switch)
- LED policy: accent RGB vs battery/status LED
- FEX / Proton path for Windows titles on aarch64
- decky-bcc installable from Steam/Wine Tools ([darkplace/decky-bcc](https://github.com/darkplace/decky-bcc))

---

## Documentation

| Doc | Description |
|-----|-------------|
| [docs/INSTALL.md](docs/INSTALL.md) | Flash & first boot |
| [docs/UPDATES.md](docs/UPDATES.md) | OTA / GitHub Releases layout |
| [docs/BUILD.md](docs/BUILD.md) | Build from source (Docker) |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | How to contribute |
| [docs/HOTPATCH.md](docs/HOTPATCH.md) | Live device hotpatch (dev, no reflash) |

---

## Credits

- Original Qualcomm Batocera work: **suckbluefrog**
- Upstream: [Batocera.linux](https://batocera.org/)
- Maintainer: **darkplace** / batocera.pocket community

## License

Same as upstream Batocera / Buildroot package licenses unless noted otherwise in individual package files.
