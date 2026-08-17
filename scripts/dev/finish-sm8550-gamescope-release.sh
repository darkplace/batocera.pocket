#!/usr/bin/env bash
# Wait for sm8550 gamescope/OSK rebuild, then commit/push docs, split, GitHub release.
# Durable: run under setsid; survives agent disconnect.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"
LOG=/tmp/finish-sm8550-gamescope-release.log
DONE_BUILD="$PROJECT_DIR/rebuild-sm8550-gamescope-osk-ota.DONE"
FAIL_BUILD="$PROJECT_DIR/rebuild-sm8550-gamescope-osk-ota.FAILED"
IMG="$PROJECT_DIR/output/sm8550/images/batocera/images/sm8550"
TAG=v44-sm8550-20260816
REPO=darkplace/batocera.pocket
: >"$LOG"
log() { printf '%s\n' "[$(date -Is)] $*" | tee -a "$LOG"; }

log "waiting for rebuild DONE/FAILED…"
while true; do
  if [ -f "$FAIL_BUILD" ]; then
    log "BUILD FAILED: $(cat "$FAIL_BUILD")"
    # If packages OK but packaging killed (143), resume docker make all once
    if grep -qE 'CMD=all|Terminated|143' "$PROJECT_DIR/rebuild-sm8550-gamescope-osk-ota.log" 2>/dev/null \
       && [ -x "$PROJECT_DIR/output/sm8550/target/usr/bin/gamescope" ] \
       && grep -q 'simple,special' "$PROJECT_DIR/output/sm8550/target/usr/bin/onscreen-keyboard" 2>/dev/null; then
      log "attempting packaging resume via docker make all"
      rm -f "$FAIL_BUILD"
      docker run --init --rm \
        -e HOME \
        -v "$PROJECT_DIR:/build" \
        -v "$PROJECT_DIR/dl:/build/buildroot/dl" \
        -v "$PROJECT_DIR/output/sm8550:/sm8550" \
        -v "$PROJECT_DIR/output/sm8550:$PROJECT_DIR/output/sm8550" \
        -v "$PROJECT_DIR/buildroot-ccache:/home/lukemotion/.buildroot-ccache" \
        -w /sm8550 \
        -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro \
        -u "$(id -u):$(id -g)" \
        batoceralinux/batocera.linux-build \
        sh -c 'if [ -d /sm8550/host/lib ]; then unset LD_LIBRARY_PATH; fi; exec make O=/sm8550 BR2_EXTERNAL=/build -C /build/buildroot all' \
        >>"$PROJECT_DIR/rebuild-sm8550-gamescope-osk-ota.log" 2>&1
      if [ -f "$IMG/boot.tar.xz" ] && [ -f "$IMG/batocera.version" ] && ls "$IMG"/batocera-sm8550-*.img.gz >/dev/null 2>&1; then
        echo "OK resume $(date -Is)" >"$DONE_BUILD"
        log "resume packaging OK"
      else
        log "resume packaging did not produce artifacts"
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
  # Still alive?
  if ! pgrep -f 'rebuild-sm8550-gamescope-osk-ota.sh' >/dev/null \
     && ! pgrep -f 'make O=/sm8550.*all' >/dev/null \
     && ! pgrep -f 'sm8550-build|sm8550-pkg' >/dev/null; then
    # Process gone without DONE — check artifacts
    if [ -f "$IMG/boot.tar.xz" ] && [ -f "$IMG/batocera.version" ] && ls "$IMG"/batocera-sm8550-*.img.gz >/dev/null 2>&1; then
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

# Sanity: wl_touch / OSK in target
GS="$PROJECT_DIR/output/sm8550/target/usr/bin/gamescope"
OSK="$PROJECT_DIR/output/sm8550/target/usr/bin/onscreen-keyboard"
grep -q 'simple,special' "$OSK"
log "PASS OSK layers in target"
VER=$(cat "$IMG/batocera.version")
log "version=$VER"
IMG_GZ=$(ls -1 "$IMG"/batocera-sm8550-*.img.gz | head -1)
log "img=$IMG_GZ"

# Commit + push docs/script if dirty
if ! git diff --quiet -- scripts/dev/rebuild-sm8550-gamescope-osk-ota.sh docs/CHANGELOG.md docs/UPDATES.md README.md \
   || [ -n "$(git ls-files --others --exclude-standard scripts/dev/rebuild-sm8550-gamescope-osk-ota.sh)" ]; then
  git add scripts/dev/rebuild-sm8550-gamescope-osk-ota.sh docs/CHANGELOG.md docs/UPDATES.md README.md
  git commit -m "$(cat <<'EOF'
sm8550: rebuild script + docs for gamescope wl_touch / OSK OTA.

EOF
)"
  git push origin HEAD:main
  log "committed+pushed"
else
  log "docs/script already committed"
fi

# Split
./scripts/dev/split-release.sh --ota "$IMG/boot.tar.xz" | tee -a "$LOG"
./scripts/dev/split-release.sh --image "$IMG_GZ" | tee -a "$LOG"

# Release: create if missing, then upload
if ! gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  BASE=$(basename "$IMG_GZ")
  STEM=${BASE%.img.gz}
  gh release create "$TAG" -R "$REPO" --target main --latest \
    --title "batocera.pocket SM8550 (Odin 2 Portal) — 2026-08-16 (Steam touch + OSK)" \
    --notes "$(cat <<EOF
### Version
- Image: \`${STEM}\`
- System string: \`${VER}\`
- Board: **SM8550** / AYN Odin 2 Portal (and other SM8550 devices)

> Same gamescope Wayland \`wl_touch\` + system OSK symbol layers as sm8750 \`v44-sm8750-20260815\`.

### What's new

<details>
<summary><b>Updates</b></summary>

- **gamescope:** Wayland \`wl_touch\` for nested Steam GamepadUI.
- **On-screen keyboard:** wvkbd \`simple,special\` + landscape special layers (\`123\` / \`@\`).

</details>

<details>
<summary><b>Fixes</b></summary>

- Steam / gamescope: OSK disappearing when typing.
- System OSK: missing special characters (no \`@\`) after Batocera base refresh.
- Does **not** enable gamescope \`--default-touch-mode\` passthrough.

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

# Upload large assets
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
echo "OK $(date -Is)" >/tmp/finish-sm8550-gamescope-release.DONE
