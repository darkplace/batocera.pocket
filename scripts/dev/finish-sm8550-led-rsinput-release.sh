#!/usr/bin/env bash
# Wait for sm8550 LED/rsinput rebuild, then split + GitHub release v44-sm8550-20260817.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"
LOG=/tmp/finish-sm8550-led-rsinput-release.log
DONE_BUILD="$PROJECT_DIR/rebuild-sm8550-led-rsinput-ota.DONE"
FAIL_BUILD="$PROJECT_DIR/rebuild-sm8550-led-rsinput-ota.FAILED"
IMG="$PROJECT_DIR/output/sm8550/images/batocera/images/sm8550"
TAG=v44-sm8550-20260817
REPO=darkplace/batocera.pocket
: >"$LOG"
log() { printf '%s\n' "[$(date -Is)] $*" | tee -a "$LOG"; }

log "waiting for rebuild DONE/FAILED…"
while true; do
  if [ -f "$FAIL_BUILD" ]; then
    log "BUILD FAILED: $(cat "$FAIL_BUILD")"
    if grep -qE 'CMD=all|Terminated|143' "$PROJECT_DIR/rebuild-sm8550-led-rsinput-ota.log" 2>/dev/null; then
      log "attempting packaging resume via docker make all"
      rm -f "$FAIL_BUILD"
      docker run --init --rm -e HOME \
        -v "$PROJECT_DIR:/build" \
        -v "$PROJECT_DIR/dl:/build/buildroot/dl" \
        -v "$PROJECT_DIR/output/sm8550:/sm8550" \
        -v "$PROJECT_DIR/output/sm8550:$PROJECT_DIR/output/sm8550" \
        -v "$PROJECT_DIR/buildroot-ccache:/home/lukemotion/.buildroot-ccache" \
        -w /sm8550 -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro \
        -u "$(id -u):$(id -g)" batoceralinux/batocera.linux-build \
        sh -c 'if [ -d /sm8550/host/lib ]; then unset LD_LIBRARY_PATH; fi; exec make O=/sm8550 BR2_EXTERNAL=/build -C /build/buildroot all' \
        >>"$PROJECT_DIR/rebuild-sm8550-led-rsinput-ota.log" 2>&1
      if [ -f "$IMG/boot.tar.xz" ] && [ -f "$IMG/batocera.version" ] && ls "$IMG"/batocera-sm8550-*.img.gz >/dev/null 2>&1; then
        echo "OK resume $(date -Is)" >"$DONE_BUILD"
      else
        echo "FAILED resume $(date -Is)" >"$FAIL_BUILD"
        exit 1
      fi
    else
      exit 1
    fi
  fi
  if [ -f "$DONE_BUILD" ]; then
    log "rebuild DONE: $(cat "$DONE_BUILD")"
    break
  fi
  if ! pgrep -f 'rebuild-sm8550-led-rsinput-ota.sh' >/dev/null \
     && ! pgrep -f 'make O=/sm8550' >/dev/null \
     && ! pgrep -f 'sm8550-build|sm8550-pkg' >/dev/null; then
    if [ -f "$IMG/boot.tar.xz" ] && [ -f "$IMG/batocera.version" ] && ls "$IMG"/batocera-sm8550-*.img.gz >/dev/null 2>&1; then
      echo "OK artifacts $(date -Is)" >"$DONE_BUILD"
      break
    fi
    log "rebuild gone without artifacts"
    echo "FAILED orphan $(date -Is)" >"$FAIL_BUILD"
    exit 1
  fi
  sleep 45
done

VER=$(cat "$IMG/batocera.version")
IMG_GZ=$(ls -1 "$IMG"/batocera-sm8550-*.img.gz | head -1)
log "version=$VER img=$IMG_GZ"

./scripts/dev/split-release.sh --ota "$IMG/boot.tar.xz" | tee -a "$LOG"
./scripts/dev/split-release.sh --image "$IMG_GZ" | tee -a "$LOG"

BASE=$(basename "$IMG_GZ")
STEM=${BASE%.img.gz}
if ! gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" -R "$REPO" --target main --latest \
    --title "batocera.pocket SM8550 (Odin 2 Portal) — 2026-08-17 (stick LEDs + analog DZ)" \
    --notes "$(cat <<EOF
### Version
- Image: \`${STEM}\`
- System string: \`${VER}\`
- Board: **SM8550** / AYN Odin 2 Portal

> Stick RGB groups (ROCKNIX-aligned) + rsinput deadzone like sm8750.

### What's new
- **Kernel:** \`CONFIG_LEDS_GROUP_MULTICOLOR=y\` → \`rgb:l*\` / \`rgb:r*\`
- **batocera-led-handheld:** prefers stick groups over bare power-led
- **rsinput:** ±1024 ranges, deadzone 70

### Fixes
- Stick LED only lit power LED
- Left analog constant left/down (deadzone 0)

### In-device OTA
\`batocera.version\` + \`boot.tar.xz.md5\` + \`boot.tar.xz.part01..03\`

### Fresh install (Windows)
Download all of \`${STEM}.zip\` + \`.z01\` + \`.z02\`, extract with 7-Zip, flash \`.img.gz\`.

### Support
**@lukemotion** on Discord
EOF
)" \
    "$IMG/batocera.version" \
    "$IMG/boot.tar.xz.md5" \
    "${IMG_GZ}.md5"
  log "release created"
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
echo "OK $(date -Is)" >/tmp/finish-sm8550-led-rsinput-release.DONE
