#!/usr/bin/env bash
# Resume after ES was already rebuilt with ScreenScraper: finalize + package images only.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.log}"
PRIMARY="$PROJECT_DIR/output/sm8750"
IMG_DIR="$PRIMARY/images/batocera/images/sm8750"
ES_BIN="$PRIMARY/target/usr/bin/emulationstation"
DIRECT_BUILD=
PARALLEL_BUILD=
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
mkdir -p "$PRIMARY" "$PRIMARY/tmp"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
rm -f "$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.DONE" \
      "$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.FAILED"

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

{
  echo ""
  echo "=== RESUME package after ES ScreenScraper rebuild ($(date -Is)) ==="
} >>"$LOG_FILE"

if [ ! -x "$ES_BIN" ] || ! grep -aFq 'devid=' "$ES_BIN" || ! grep -aFq 'jeuInfos.php' "$ES_BIN"; then
  log "FAIL: target ES missing ScreenScraper (devid=/jeuInfos)"
  echo "FAILED no-ss $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-es-screenscraper-ota.FAILED"
  exit 1
fi
log "PASS target ES has ScreenScraper"

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
