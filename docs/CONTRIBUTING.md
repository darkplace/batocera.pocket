# Contributing

Thanks for helping with batocera.pocket.

## Language

- **Project documentation** (README, `docs/`, issue/PR templates): English.
- Day-to-day chat with maintainers may use other languages.

## Workflow

1. Fork / branch from `main`.
2. Prefer small, focused commits.
3. Test on real hardware when changing Steam, gamescope, LEDs, or LXC.
4. Open a PR against `https://github.com/darkplace/batocera.pocket`.

## Coding notes

- Do not casually disable packages to “make the build pass”.
- Odin 3 Steam must use **gamescope Wayland** nested backend (DRM exclusive causes a black screen on this panel).
- Touch in Steam requires the gamescope Wayland `wl_touch` patch (`package/batocera/utils/gamescope/001-rocknix-wayland-touch.patch`).
- OTA must keep working with GitHub’s 2 GB asset limit (`boot.tar.xz.part*` + multi-volume ZIP for images).

## Credits

Please keep attribution to suckbluefrog and Batocera.linux where appropriate.
