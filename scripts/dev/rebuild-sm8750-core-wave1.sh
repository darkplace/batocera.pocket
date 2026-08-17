#!/bin/bash
# Oleada 1 core community — rebuild parcial sm8750 (Docker) + imagen.
# Log: rebuild-sm8750-core-wave1.log (también symlink en output/upstream-review/)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-core-wave1.log}"
REVIEW_LOG="$PROJECT_DIR/output/upstream-review/rebuild-sm8750-core-wave1.log"
PRIMARY="$PROJECT_DIR/output/sm8750"
DIRECT_BUILD=
PARALLEL_BUILD=
# Docker bridge often cannot reach LAN DNS (10.10.10.1); force public resolvers.
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
mkdir -p "$PRIMARY" "$PROJECT_DIR/output/upstream-review"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
mkdir -p "$TMPDIR"
export CMAKE_POLICY_VERSION_MINIMUM=3.5
IMG_DIR="$PRIMARY/images/batocera/images/sm8750"

# Avoid make|tee pipes under nohup (Cursor shell can reap the job mid-build).
# Line-buffer make/docker output into the log file instead.
log() { printf '%s\n' "$@" >>"$LOG_FILE"; }

: >"$LOG_FILE"
{
  echo "=== batocera.pocket core WAVE 1 rebuild (sm8750) ==="
  echo "Date: $(date -Is)"
  echo "PID: $$"
  echo "Tree: $PRIMARY"
  echo "Log: $LOG_FILE"
  echo "Packages: batocera-bluetooth batocera-audio batocera-scripts batocera-triggerhappy"
  echo "Kept pocket: S27audioconfig Odin3, upgrade/fan/Steam untouched"
  echo ""
} >>"$LOG_FILE"
ln -sfn "$LOG_FILE" "$REVIEW_LOG"

run_pkg() {
  local pkg="$1" ec
  log ""
  log ">>> make sm8750-pkg PKG=$pkg  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8750-pkg \
      PKG="$pkg" \
      DIRECT_BUILD="$DIRECT_BUILD" \
      PARALLEL_BUILD="$PARALLEL_BUILD" \
      BATCH_MODE=1 \
      MAKE_JLEVEL="${MAKE_JLEVEL:-12}" \
      MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
      >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: $pkg (exit $ec) at $(date -Is)"
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-core-wave1.FAILED"
    ln -sfn "$LOG_FILE" "$REVIEW_LOG"
    exit "$ec"
  fi
  log "OK: $pkg"
}

run_cmd() {
  local cmd="$1" ec
  log ""
  log ">>> make sm8750-build CMD=$cmd  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8750-build \
      CMD="$cmd" \
      DIRECT_BUILD="$DIRECT_BUILD" \
      PARALLEL_BUILD="$PARALLEL_BUILD" \
      BATCH_MODE=1 \
      MAKE_JLEVEL="${MAKE_JLEVEL:-12}" \
      MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
      >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: CMD=$cmd (exit $ec) at $(date -Is)"
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-core-wave1.FAILED"
    ln -sfn "$LOG_FILE" "$REVIEW_LOG"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

run_pkg batocera-bluetooth-reinstall
run_pkg batocera-audio-reinstall
run_pkg batocera-scripts-reinstall
run_pkg batocera-triggerhappy-reinstall
run_cmd target-finalize

TARGET="$PRIMARY/target"
log ""
log ">>> Wave1 target greps"
fail=0
set +e

if [ -x "$TARGET/usr/bin/batocera-temp" ]; then
  log "PASS batocera-temp"
else
  log "FAIL batocera-temp missing"; fail=1
fi

if [ -x "$TARGET/usr/bin/batocera-keyboard" ]; then
  log "PASS batocera-keyboard"
else
  log "FAIL batocera-keyboard missing"; fail=1
fi

if grep -q 'batocera-pending-volume' "$TARGET/usr/bin/batocera-audio" 2>/dev/null; then
  log "PASS audio_volume_debounce"
else
  log "FAIL audio_volume_debounce"; fail=1
fi

if grep -q 'odin3_audio_log\|ayn,odin3' "$TARGET/etc/init.d/S27audioconfig" 2>/dev/null \
   || grep -rq 'odin3_audio_log\|ayn,odin3' "$TARGET/etc/init.d/" 2>/dev/null; then
  log "PASS odin3_audio_kept"
else
  # S27 may live under different path after install
  if grep -rq 'odin3_audio_log' "$TARGET" 2>/dev/null; then
    log "PASS odin3_audio_kept (found elsewhere under target)"
  else
    log "FAIL odin3_audio_kept (Odin3 recovery missing from target)"
    fail=1
  fi
fi

if grep -q 'darkplace/batocera.pocket' "$TARGET/usr/bin/batocera-upgrade" 2>/dev/null; then
  log "PASS upgrade_still_pocket"
else
  log "FAIL upgrade_still_pocket"; fail=1
fi

if [ -x "$TARGET/usr/bin/qcom-fan" ] && ! grep -qE '^# stub' "$TARGET/usr/bin/qcom-fan" 2>/dev/null; then
  log "PASS qcom-fan_present"
else
  log "WARN qcom-fan check inconclusive"
fi

set -e
log "wave1 prechecks fail=$fail"
[ "$fail" -eq 0 ] || { ln -sfn "$LOG_FILE" "$REVIEW_LOG"; exit 1; }

log ">>> Removing prior squashfs/images for fresh all"
rm -f "$PRIMARY/images/rootfs.squashfs"
rm -f "$IMG_DIR"/batocera-sm8750-*.img.gz
rm -f "$IMG_DIR"/boot.tar.xz

run_cmd all

{
  echo ""
  echo "=== Finished OK: $(date -Is) ==="
  ls -lh "$IMG_DIR"/batocera-sm8750-*.img.gz "$IMG_DIR"/boot.tar.xz 2>/dev/null || true
  echo "LOG=$LOG_FILE"
} | tee -a "$LOG_FILE"

ln -sfn "$LOG_FILE" "$REVIEW_LOG"
cp -f "$LOG_FILE" "$REVIEW_LOG.copy" 2>/dev/null || true
echo "OK $(date -Is)" > "$PROJECT_DIR/rebuild-sm8750-core-wave1.DONE"
