#!/usr/bin/env bash
# Wait for sm8750 OSK/QAM/screensaver rebuild, then split + GitHub release.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"
LOG=/tmp/finish-sm8750-osk-qam-ss-release.log
DONE_BUILD="$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.DONE"
FAIL_BUILD="$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"
IMG="$PROJECT_DIR/output/sm8750/images/batocera/images/sm8750"
TAG=v44-sm8750-20260817
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
  if ! pgrep -f 'rebuild-sm8750-osk-qam-ss-ota.sh' >/dev/null \
     && ! pgrep -f 'make O=/sm8750.*all' >/dev/null \
     && ! pgrep -f 'sm8750-build|sm8750-pkg' >/dev/null; then
    if [ -f "$IMG/boot.tar.xz" ] && [ -f "$IMG/batocera.version" ] \
       && ls "$IMG"/batocera-sm8750-*.img.gz >/dev/null 2>&1; then
      echo "OK artifacts-present $(date -Is)" >"$DONE_BUILD"
      log "rebuild process gone but artifacts present — continuing"
      break
    fi
    log "rebuild process gone without DONE/artifacts — fail"
    echo "FAILED orphan $(date -Is)" >"$FAIL_BUILD"
    exit 1
  fi
  sleep 30
done

QAM="$PROJECT_DIR/output/sm8750/target/usr/bin/batocera-steam-qam"
grep -q 'OnQuickAccessButtonPressed' "$QAM"
log "PASS QAM in target"
VER=$(cat "$IMG/batocera.version")
log "version=$VER"
IMG_GZ=$(ls -1 "$IMG"/batocera-sm8750-*.img.gz | head -1)
log "img=$IMG_GZ"

./scripts/dev/split-release.sh --ota "$IMG/boot.tar.xz" | tee -a "$LOG"
./scripts/dev/split-release.sh --image "$IMG_GZ" | tee -a "$LOG"

if ! gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  BASE=$(basename "$IMG_GZ")
  STEM=${BASE%.img.gz}
  gh release create "$TAG" -R "$REPO" --target main --latest \
    --title "batocera.pocket SM8750 (Odin 3) — 2026-08-17 (OSK @ + QAM Back + screensaver)" \
    --notes "$(cat <<EOF
### Version
- Image: \`${STEM}\`
- System string: \`${VER}\`
- Board: **SM8750** / AYN Odin 3

> On top of Golden Rabbit \`v44-sm8750-20260816\`.

### What's new

<details>
<summary><b>Updates</b></summary>

- **Steam QAM:** physical **Back** opens Quick Access via CEF (\`batocera-steam-qam\` + \`batocera-steam-back-qam\`); Home stays native Steam menu.
- **OSK:** special/\`@\` keys emit Shift+digit (no more typing \`2\` instead of \`@\`).
- **EmulationStation:** dim/black screensaver fills the full rotated Wayland panel.

</details>

<details>
<summary><b>Fixes</b></summary>

- QAM keyboard chords unreliable under nested gamescope (Ctrl+2 / Ctrl+Shift+Tab fight).
- hotkeygen: string actions fire on keydown; init avoids duplicate daemons.
- OSK patches applied from package root (Buildroot does not recurse \`patches/\`).

</details>

Full notes: [docs/CHANGELOG.md](https://github.com/darkplace/batocera.pocket/blob/main/docs/CHANGELOG.md)

### In-device OTA
EmulationStation → **Updates**. Assets:
- \`batocera.version\`
- \`boot.tar.xz.md5\`
- \`boot.tar.xz.part01\` + \`part02\` + \`part03\`

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

for f in \
  "$IMG/boot.tar.xz.part01" \
  "$IMG/boot.tar.xz.part02" \
  "$IMG/boot.tar.xz.part03" \
  "$IMG"/batocera-sm8750-*.z01 \
  "$IMG"/batocera-sm8750-*.z02 \
  "$IMG"/batocera-sm8750-*.zip
do
  [ -f "$f" ] || continue
  log "upload $(basename "$f")"
  gh release upload "$TAG" -R "$REPO" --clobber "$f"
done

log "ALL DONE → https://github.com/${REPO}/releases/tag/${TAG}"
echo "OK $(date -Is)" >/tmp/finish-sm8750-osk-qam-ss-release.DONE
