#!/usr/bin/env bash
# Rebuild EmulationStation with package-local keys.txt (ScreenScraper) and remake OTA images.
# keys.txt is gitignored — never commit it.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.log}"
PRIMARY="$PROJECT_DIR/output/sm8750"
IMG_DIR="$PRIMARY/images/batocera/images/sm8750"
KEYS="$PROJECT_DIR/package/batocera/emulationstation/batocera-emulationstation/keys.txt"
DIRECT_BUILD=
PARALLEL_BUILD=
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
mkdir -p "$PRIMARY" "$PRIMARY/tmp"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
: >"$LOG_FILE"
rm -f "$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.DONE" \
      "$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.FAILED"

run_pkg() {
  local pkg="$1" ec
  log ""; log ">>> make sm8750-pkg PKG=$pkg  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8750-pkg PKG="$pkg" DIRECT_BUILD="$DIRECT_BUILD" \
    PARALLEL_BUILD="$PARALLEL_BUILD" BATCH_MODE=1 \
    MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
    >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: $pkg ($ec)"
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.FAILED"
    exit "$ec"
  fi
  log "OK: $pkg"
}

run_cmd() {
  local cmd="$1" ec
  log ""; log ">>> make sm8750-build CMD=$cmd  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8750-build CMD="$cmd" DIRECT_BUILD="$DIRECT_BUILD" \
    PARALLEL_BUILD="$PARALLEL_BUILD" BATCH_MODE=1 \
    MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
    >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: CMD=$cmd ($ec)"
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

log "=== sm8750 ES ScreenScraper short OTA ==="
log "Date: $(date -Is) PID=$$"

if [ ! -f "$KEYS" ]; then
  log "FAIL: missing $KEYS (gitignored; restore before rebuild)"
  echo "FAILED missing-keys $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.FAILED"
  exit 1
fi
if ! grep -qE '^SCREENSCRAPER_DEV_LOGIN=devid=.+&devpassword=.+' "$KEYS"; then
  log "FAIL: SCREENSCRAPER_DEV_LOGIN empty/invalid in keys.txt"
  echo "FAILED bad-keys $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.FAILED"
  exit 1
fi
log "PASS keys.txt present (SCREENSCRAPER_DEV_LOGIN set)"

# Force full reconfigure so -DSCREENSCRAPER_DEV_LOGIN is picked up.
log ">>> wiping output/sm8750/build/batocera-emulationstation-*"
rm -rf "$PRIMARY"/build/batocera-emulationstation-*

run_pkg batocera-emulationstation-rebuild
run_pkg batocera-system-reinstall

ES_BIN="$PRIMARY/target/usr/bin/emulationstation"
if [ ! -x "$ES_BIN" ]; then
  log "FAIL: missing $ES_BIN"
  echo "FAILED missing-es $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.FAILED"
  exit 1
fi
# Prefer grep -aF on the binary: `strings | grep -q` trips pipefail (SIGPIPE→false FAIL).
if ! grep -aFq 'devid=' "$ES_BIN"; then
  log "FAIL: ES binary still has no devid= (ScreenScraper not compiled in)"
  echo "FAILED no-devid $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.FAILED"
  exit 1
fi
if ! grep -aFq 'jeuInfos.php' "$ES_BIN"; then
  log "FAIL: ES binary missing ScreenScraper code refs"
  echo "FAILED no-ss-refs $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.FAILED"
  exit 1
fi
log "PASS target ES has devid= + ScreenScraper refs"

run_cmd target-finalize

log ">>> wipe prior images"
rm -f "$PRIMARY/images/rootfs.squashfs"
rm -f "$IMG_DIR"/batocera-sm8750-*.img.gz
rm -f "$IMG_DIR"/boot.tar.xz

run_cmd all

{
  echo ""
  echo "=== Finished OK: $(date -Is) ==="
  ls -lh "$IMG_DIR"/batocera-sm8750-*.img.gz "$IMG_DIR"/boot.tar.xz "$IMG_DIR"/batocera.version 2>/dev/null || true
  cat "$IMG_DIR"/batocera.version 2>/dev/null || true
  # Confirm packaged squash still has devid (extract one file)
  TMP=$(mktemp -d)
  tar -xJf "$IMG_DIR/boot.tar.xz" -C "$TMP" boot/batocera 2>/dev/null \
    || tar -xJf "$IMG_DIR/boot.tar.xz" -C "$TMP" boot/batocera.update
  SQ=$(find "$TMP" -name 'batocera' -o -name 'batocera.update' | head -1)
  unsquashfs -d "$TMP/sq" -f "$SQ" /usr/bin/emulationstation >/dev/null
  if grep -aFq 'devid=' "$TMP/sq/usr/bin/emulationstation"; then
    echo "PASS packaged ES devid="
  else
    echo "FAIL packaged ES missing devid="
    rm -rf "$TMP"
    exit 1
  fi
  rm -rf "$TMP"
} | tee -a "$LOG_FILE"

echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.DONE"
log "DONE — next: ./scripts/dev/apply-sm8750-ota.sh && reboot device"
