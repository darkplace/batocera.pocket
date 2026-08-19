#!/usr/bin/env bash
# Split + GitHub release v44-sm8550-20260819-2 (Pokémon Recomp + pocket parity).
# Release notes: no in-device OTA part-file instructions (confuses downloaders).
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"
LOG=/tmp/finish-sm8550-ports-proton-release.log
DONE_BUILD="$PROJECT_DIR/rebuild-sm8550-full-fixes-ota.DONE"
FAIL_BUILD="$PROJECT_DIR/rebuild-sm8550-full-fixes-ota.FAILED"
IMG="$PROJECT_DIR/output/sm8550/images/batocera/images/sm8550"
TAG=v44-sm8550-20260819-2
REPO=darkplace/batocera.pocket
: >"$LOG"
log() { printf '%s\n' "[$(date -Is)] $*" | tee -a "$LOG"; }

log "waiting for rebuild DONE/FAILED…"
while true; do
  if [ -f "$FAIL_BUILD" ]; then
    log "BUILD FAILED: $(cat "$FAIL_BUILD")"
    exit 1
  fi
  if [ -f "$DONE_BUILD" ]; then
    log "rebuild DONE: $(cat "$DONE_BUILD")"
    break
  fi
  if ! pgrep -f 'rebuild-sm8550-full-fixes-ota' >/dev/null \
     && ! pgrep -f 'sm8550-build|sm8550-pkg' >/dev/null; then
    if [ -f "$IMG/boot.tar.xz" ] && [ -f "$IMG/batocera.version" ] \
       && ls "$IMG"/batocera-sm8550-*.img.gz >/dev/null 2>&1; then
      echo "OK artifacts $(date -Is)" >"$DONE_BUILD"
      log "artifacts present — continuing"
      break
    fi
    log "rebuild gone without DONE/artifacts"
    echo "FAILED orphan $(date -Is)" >"$FAIL_BUILD"
    exit 1
  fi
  sleep 45
done

./scripts/dev/verify-sm8550-must-ship.sh target | tee -a "$LOG"
VER=$(cat "$IMG/batocera.version")
IMG_GZ=$(ls -1 "$IMG"/batocera-sm8550-*.img.gz | head -1)
log "version=$VER img=$IMG_GZ"

./scripts/dev/split-release.sh --ota "$IMG/boot.tar.xz" | tee -a "$LOG"
./scripts/dev/split-release.sh --image "$IMG_GZ" | tee -a "$LOG"

BASE=$(basename "$IMG_GZ")
STEM=${BASE%.img.gz}
if ! gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" -R "$REPO" --target main \
    --title "batocera.pocket SM8550 (Odin 2 Portal) — 2026-08-19 (Pokémon Recomp + pocket parity)" \
    --notes "$(cat <<EOF
### Version
- Image: \`${STEM}\`
- System string: \`${VER}\`
- Board: **SM8550** / AYN Odin 2 / Odin 2 Portal

> Shared pocket features with the Odin 3 cut — without OLED Care and without the Odin 3 Wi-Fi / UFS tickets.

### What's new

<details>
<summary><b>Updates</b></summary>

- **Pokémon Recomp** is its own system (pokéball art, not a second Game Boy). Put dumps in **\`roms/pkmnrecomp/\`** — not in \`gb\` / \`gbc\`.
  - **Red / Blue** → \`.gb\` · **Yellow / Gold / Silver / Crystal** → \`.gbc\`
  - Gen 1 vs Gen 2 is chosen automatically from the ROM.
  - Mods: \`roms/pkmnrecomp/mods/gen1/\` and \`…/mods/gen2/\`
  - Options: **Tools → Configure Gen1Recomp** / **Configure Gen2Recomp**
  - Saves: \`saves/apps/pkmnrecomp-gen1/\` and \`…/pkmnrecomp-gen2/\`
  - Share: \`\\\\BATOCERA\\share\\roms\\pkmnrecomp\\\`
- **Pad:** **Home + Start** exits. **A / B / Start / Select** and the D-pad work in-game. Extra options live in those Configure tools.
- **Steam Proton tips:** Valve ARM64, CachyOS, GE, and Experimental (x86 · Rockstar) with \`★ Recommended\` / \`★ Rockstar\`; already-installed tips are not re-downloaded. After you leave Steam, pads still work in native emulators.
- **M2** toggles mouse mode. **Lutris** shows Epic/GOG covers again.
- **Ports X86 Translator:** Tools + **Advanced Options → PORTS TRANSLATOR** (Box64 ↔ FEX).
- **On-screen keyboard:** \`@\` and special keys emit Shift+digit. Discord (Vesktop) is lifted above the keys. **EmulationStation** dim/black screensaver covers the full rotated Wayland panel.
- **xenia-edge** is the default Xbox 360 core.

</details>

<details>
<summary><b>Fixes</b></summary>

- Pokémon Recomp no longer hides as a duplicate Game Boy entry.
- Steam no longer re-downloads Proton tools that are already installed.
- Steam can be opened again after **Return to Desktop**.
- Lutris Epic/GOG cover art (cairo / pixbuf).
- OSK no longer types \`2\` instead of \`@\`.

</details>

Full notes: [docs/CHANGELOG.md](https://github.com/darkplace/batocera.pocket/blob/main/docs/CHANGELOG.md) · ROM paths: [docs/ADDING_ROMS.md](https://github.com/darkplace/batocera.pocket/blob/main/docs/ADDING_ROMS.md)

### Fresh install (Windows)
1. Download **ALL** volumes: \`${STEM}.zip\` + \`.z01\` + \`.z02\` (same folder, do not rename).
2. Open the \`.zip\` with 7-Zip / WinZip → extract \`${BASE}\`.
3. Optional verify: \`${BASE}.md5\`.
4. Flash with balenaEtcher / Rufus / Raspberry Pi Imager.

> Requires the [ROCKNIX ABL](https://github.com/ROCKNIX/abl) on the boot partition before flashing.

### Support
**@lukemotion** on Discord
EOF
)" \
    "$IMG/batocera.version" \
    "$IMG/boot.tar.xz.md5" \
    "${IMG_GZ}.md5"
  log "release created"
else
  log "release already exists"
fi

shopt -s nullglob
for f in \
  "$IMG/boot.tar.xz.part01" \
  "$IMG/boot.tar.xz.part02" \
  "$IMG/boot.tar.xz.part03" \
  "$IMG"/batocera-sm8550-*.z01 \
  "$IMG"/batocera-sm8550-*.z02 \
  "$IMG"/batocera-sm8550-*.zip
do
  [ -f "$f" ] || continue
  log "upload $(basename "$f")"
  gh release upload "$TAG" -R "$REPO" --clobber "$f"
done

log "ALL DONE → https://github.com/${REPO}/releases/tag/${TAG}"
echo "OK $(date -Is)" >/tmp/finish-sm8550-ports-proton-release.DONE
