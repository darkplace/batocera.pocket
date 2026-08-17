#!/usr/bin/env bash
# Rebuild sm8750 RC1 OTA image: refresh version + WiFi S09 + remake boot/img.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-rc1.log}"
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
: >"$LOG_FILE"
rm -f "$PROJECT_DIR/rebuild-sm8750-rc1.DONE" "$PROJECT_DIR/rebuild-sm8750-rc1.FAILED"

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
    log "FAILED: $pkg ($ec)"; echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-rc1.FAILED"; exit "$ec"
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
    log "FAILED: CMD=$cmd ($ec)"; echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-rc1.FAILED"; exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

log "=== sm8750 RC1 rebuild ==="
log "Date: $(date -Is) PID=$$"

run_pkg batocera-system-reinstall
run_pkg batocera-scripts-reinstall

TARGET="$PRIMARY/target"
install -m 0755 \
  "$PROJECT_DIR/board/batocera/qualcomm/sm8750/fsoverlay/etc/init.d/S09sm8750-wifi-resilience" \
  "$TARGET/etc/init.d/S09sm8750-wifi-resilience"
install -m 0755 \
  "$PROJECT_DIR/board/batocera/qualcomm/sm8750/fsoverlay/usr/bin/sm8750-wifi-resilience" \
  "$TARGET/usr/bin/sm8750-wifi-resilience" 2>/dev/null || true
rm -f "$TARGET/etc/init.d/S06qcom-fan"
install -m 0755 \
  "$PROJECT_DIR/board/batocera/qualcomm/sm8750/fsoverlay/etc/init.d/S12qcom-fan" \
  "$TARGET/etc/init.d/S12qcom-fan"

# Greps
fail=0
grep -q 'dead-air' "$TARGET/etc/init.d/S09sm8750-wifi-resilience" && log "PASS wifi_dead_air" || { log "FAIL wifi"; fail=1; }
grep -q '44-dev-pocket-rc1' "$TARGET/usr/share/batocera/batocera.version" && log "PASS version_rc1 ($(cat "$TARGET/usr/share/batocera/batocera.version"))" || { log "FAIL version ($(cat "$TARGET/usr/share/batocera/batocera.version" 2>/dev/null))"; fail=1; }
[ -x "$TARGET/etc/init.d/S12qcom-fan" ] && log "PASS S12_fan" || { log "FAIL S12"; fail=1; }
[ "$fail" -eq 0 ] || exit 1

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
echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-rc1.DONE"
