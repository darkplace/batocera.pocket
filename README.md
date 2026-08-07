<p align="center">
  <img src="media/batocera.pocket-logo.png" alt="batocera.pocket" width="420">
</p>

# batocera.pocket

Community Batocera images for Qualcomm Snapdragon handhelds. Continues the Qualcomm Batocera work started by **suckbluefrog**.

Built on [Batocera.linux](https://batocera.org/) / [Buildroot](https://buildroot.org/). On top of the normal Batocera stack: Steam GamepadUI (SteamOS-style session via gamescope), FEX with a Fedora rootfs squashfs for x86_64 Proton/Windows titles, and LXC desktops where the board supports them.

**Repo:** [github.com/darkplace/batocera.pocket](https://github.com/darkplace/batocera.pocket)  
**Maintainer:** lukemotion (GitHub: [darkplace](https://github.com/darkplace))

---

## First launch & hotkeys

The first start of **Steam** and of the **Arch / Ubuntu Plasma LXC** containers can take a while (downloads, rootfs setup, first boot). That is normal — let them finish.

| Combo | Action |
|-------|--------|
| **Home + A** | Batocera menu (utilities) |
| **Home + B** | Emulator / Steam options menu (Decky and related tools) |
| **Home + Touch** | Toggle on-screen keyboard |
| **Home + Select + Start** | Toggle built-in mouse |
| **Home + L1 + R1** | Force quit and return to Batocera |

**Home** can be remapped; it uses Batocera’s standard hotkey mapping.

---

## Devices & builds

Images are per SoC. Every build also includes the usual Batocera systems (RetroArch cores, Wine/Proton tooling, etc.). Headline ports and extras are listed under each build. **AYN Odin 3** is the only device smoke-tested on this tree so far.

### SM8750 — `batocera-sm8750`

| Device | Tested |
|--------|--------|
| AYN Odin 3 | ✅ |

Emulators / extras:

- Steam (GamepadUI / gamescope)
- FEX + Fedora squashfs
- Arch Plasma LXC
- Ubuntu Plasma LXC
- Lutris
- Eden
- Yuzu
- Ryujinx
- Dolphin
- RPCS3
- shadPS4 (FEX)
- AetherSX2 / ARMSX2
- PCSX2
- Play!
- Cemu
- Vita3K
- Xemu
- Xenia Canary / Edge
- BigPemu
- + the rest of the Batocera set for this board

Not included:

- Waydroid (disabled on Odin 3 / SM8750)

### SM8550 — `batocera-sm8550`

Devices: AYN Odin 2 / Mini / Portal, AYN Thor, AYANEO Pocket ACE / DS / DMG / EVO / S2K, Retroid Pocket 6 (+ TOP-DPAD DTB).

Emulators / extras:

- Steam (GamepadUI / gamescope)
- FEX + Fedora squashfs
- Arch Plasma LXC
- Ubuntu Plasma LXC
- Lutris
- Waydroid
- Eden
- Yuzu
- Ryujinx
- Dolphin
- RPCS3
- shadPS4 (FEX)
- AetherSX2 / ARMSX2
- PCSX2
- Play!
- Cemu
- Vita3K
- Xemu
- Xenia Canary / Edge
- BigPemu
- + the rest of the Batocera set for this board

### SM8250 — `batocera-sm8250`

Devices: Retroid Pocket 5, Mini, Mini V2, Flip 2.

Emulators / extras:

- Steam (GamepadUI / gamescope)
- FEX + Fedora squashfs
- Eden
- Yuzu
- Ryujinx
- Dolphin
- RPCS3
- AetherSX2 / ARMSX2
- Cemu
- Vita3K
- Xemu
- Xenia Edge
- + the rest of the Batocera set for this board

Not included:

- Waydroid
- Arch / Ubuntu Plasma LXC
- Lutris
- shadPS4
- PCSX2 / Play!

### Other (best-effort)

AYN Odin 1 (SD845), Radxa Dragon Q6A (QCS6490) — in-tree, not a focus of current builds.

---

## Extras

- [decky-bcc](https://github.com/darkplace/decky-bcc) — Decky Loader install helper for Steam

---

## Download & flash

1. Get the latest [GitHub Release](https://github.com/darkplace/batocera.pocket/releases/latest).
2. Download every volume for your SoC (`.zip` + `.z01`, `.z02`, …). Keep them in the same folder; do not rename.
3. Extract the `.zip` with 7-Zip or WinZip → one `.img.gz`.
4. Write that `.img.gz` to a microSD with balenaEtcher, Rufus, or Raspberry Pi Imager.

Boot from the card on the device (same flow as other Batocera Qualcomm builds).

---

## Support

Bugs and feedback: **@lukemotion** on Discord (device + image version + logs under `/userdata/system/logs/` help a lot).

---

## Credits

- Qualcomm Batocera groundwork: **suckbluefrog**
- Upstream: [Batocera.linux](https://batocera.org/)
- Maintainer: **lukemotion**

## License

batocera.pocket is licensed under the **GNU General Public License v2.0 (GPLv2)**, same as [Batocera.linux](https://github.com/batocera-linux/batocera.linux). See [LICENSE](LICENSE) for the full text. Individual packages may carry additional licenses; see each package directory.
