#!/usr/bin/env bash
# Rebuild sm8550 kernel (GROUP_MULTICOLOR + rsinput ranges) + LED userspace, remake OTA.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8550-led-rsinput-ota.log}"
PRIMARY="$PROJECT_DIR/output/sm8550"
IMG_DIR="$PRIMARY/images/batocera/images/sm8550"
DIRECT_BUILD=
PARALLEL_BUILD=
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
mkdir -p "$PRIMARY" "$PRIMARY/tmp"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
: >"$LOG_FILE"
rm -f "$PROJECT_DIR/rebuild-sm8550-led-rsinput-ota.DONE" \
      "$PROJECT_DIR/rebuild-sm8550-led-rsinput-ota.FAILED"

run_pkg() {
  local pkg="$1" ec
  log ""; log ">>> make sm8550-pkg PKG=$pkg  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8550-pkg PKG="$pkg" DIRECT_BUILD="$DIRECT_BUILD" \
    PARALLEL_BUILD="$PARALLEL_BUILD" BATCH_MODE=1 \
    MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
    >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: $pkg ($ec)"
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8550-led-rsinput-ota.FAILED"
    exit "$ec"
  fi
  log "OK: $pkg"
}

run_cmd() {
  local cmd="$1" ec
  log ""; log ">>> make sm8550-build CMD=$cmd  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8550-build CMD="$cmd" DIRECT_BUILD="$DIRECT_BUILD" \
    PARALLEL_BUILD="$PARALLEL_BUILD" BATCH_MODE=1 \
    MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
    >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: CMD=$cmd ($ec)"
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8550-led-rsinput-ota.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

log "=== sm8550 stick LEDs (GROUP_MULTICOLOR) + rsinput deadzone OTA ==="
log "Date: $(date -Is) PID=$$"

grep -q '^CONFIG_LEDS_GROUP_MULTICOLOR=y' \
  board/batocera/qualcomm/sm8550/linux_sm8550-defconfig.config \
  || { log "FAIL: GROUP_MULTICOLOR not enabled"; exit 1; }
[ -f board/batocera/qualcomm/sm8550/linux_patches/1300-input-rsinput-ranges.patch ] \
  || { log "FAIL: missing 1300 rsinput ranges patch"; exit 1; }
grep -q 'stick_group_led_paths' \
  package/batocera/utils/batocera-led-handheld/batoled.py \
  || { log "FAIL: batoled missing stick_group_led_paths"; exit 1; }

# Force kernel reconfigure/rebuild so defconfig + 1300 patch apply.
run_pkg linux-dirclean || true
run_pkg linux
run_pkg batocera-led-handheld-rebuild || run_pkg batocera-led-handheld
run_pkg batocera-system-reinstall

# Sanity: patched source in build tree
if ! grep -q 'axis_leftx_deadzone=70' "$PRIMARY"/build/linux-*/drivers/input/joystick/rsinput.c 2>/dev/null; then
  log "FAIL: rsinput deadzone=70 not in built linux tree"
  echo "FAILED no-rsinput-dz $(date -Is)" >"$PROJECT_DIR/rebuild-sm8550-led-rsinput-ota.FAILED"
  exit 1
fi
log "PASS rsinput deadzone in linux tree"
if ! grep -q 'CONFIG_LEDS_GROUP_MULTICOLOR=y' "$PRIMARY"/.config 2>/dev/null \
   && ! grep -q 'CONFIG_LEDS_GROUP_MULTICOLOR=y' "$PRIMARY"/build/linux-*/.config 2>/dev/null; then
  log "WARN: could not confirm GROUP_MULTICOLOR in .config (continuing)"
else
  log "PASS LEDS_GROUP_MULTICOLOR in config"
fi

run_cmd target-finalize

log ">>> wipe prior images"
rm -f "$PRIMARY/images/rootfs.squashfs"
rm -f "$IMG_DIR"/batocera-sm8550-*.img.gz
rm -f "$IMG_DIR"/boot.tar.xz

run_cmd all

{
  echo ""
  echo "=== Finished OK: $(date -Is) ==="
  ls -lh "$IMG_DIR"/batocera-sm8550-*.img.gz "$IMG_DIR"/boot.tar.xz "$IMG_DIR"/batocera.version 2>/dev/null || true
  cat "$IMG_DIR"/batocera.version 2>/dev/null || true
} | tee -a "$LOG_FILE"

echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8550-led-rsinput-ota.DONE"
log "DONE — next: split-release + gh release v44-sm8550-20260817"
