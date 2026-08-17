#!/usr/bin/env bash
# Resume after FAILED qam: force steam-aarch64 reinstall + package images.
# Does NOT upload to GitHub — apply locally with scripts/dev/apply-sm8750-ota.sh
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.log}"
PRIMARY="$PROJECT_DIR/output/sm8750"
IMG_DIR="$PRIMARY/images/batocera/images/sm8750"
DIRECT_BUILD=
PARALLEL_BUILD=
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
mkdir -p "$PRIMARY" "$PRIMARY/tmp"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
rm -f "$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.DONE" \
      "$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"

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
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"
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
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

log "=== RESUME sm8750 OSK+QAM+SS (no GitHub upload) ==="
log "Date: $(date -Is) PID=$$"

run_pkg hotkeygen-reinstall || run_pkg hotkeygen
run_pkg batocera-steam-aarch64-dirclean || true
run_pkg batocera-steam-aarch64
run_pkg batocera-system-reinstall || run_pkg batocera-system

QAM="$PRIMARY/target/usr/bin/batocera-steam-qam"
BACK="$PRIMARY/target/usr/bin/batocera-steam-back-qam"
[ -x "$QAM" ] && grep -q 'OnQuickAccessButtonPressed' "$QAM" \
  || { log "FAIL: $QAM"; echo "FAILED qam $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"; exit 1; }
[ -x "$BACK" ] || { log "FAIL: $BACK"; echo "FAILED back-qam $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"; exit 1; }
log "PASS QAM binaries in target"

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
} | tee -a "$LOG_FILE"

echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.DONE"
log "DONE — test with: ./scripts/dev/apply-sm8750-ota.sh (no GitHub upload)"
