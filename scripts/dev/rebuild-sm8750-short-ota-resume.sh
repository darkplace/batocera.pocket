#!/bin/bash
# Resume short OTA after finalize: controlcenter temp fix + greps + all
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-short-ota.log}"
REVIEW_LOG="$PROJECT_DIR/output/upstream-review/rebuild-sm8750-short-ota.log"
PRIMARY="$PROJECT_DIR/output/sm8750"
DIRECT_BUILD=
PARALLEL_BUILD=
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
mkdir -p "$TMPDIR"
export CMAKE_POLICY_VERSION_MINIMUM=3.5
IMG_DIR="$PRIMARY/images/batocera/images/sm8750"

log() { printf '%s\n' "$@" >>"$LOG_FILE"; }

{
  echo ""
  echo "=== RESUME short OTA (controlcenter + all) $(date -Is) PID=$$ ==="
} >>"$LOG_FILE"
ln -sfn "$LOG_FILE" "$REVIEW_LOG"
rm -f "$PROJECT_DIR/rebuild-sm8750-short-ota.FAILED" "$PROJECT_DIR/rebuild-sm8750-short-ota.DONE"

run_pkg() {
  local pkg="$1" ec
  log ""
  log ">>> make sm8750-pkg PKG=$pkg  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8750-pkg \
      PKG="$pkg" DIRECT_BUILD="$DIRECT_BUILD" PARALLEL_BUILD="$PARALLEL_BUILD" \
      BATCH_MODE=1 MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
      >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: $pkg (exit $ec) at $(date -Is)"
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-short-ota.FAILED"
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
      CMD="$cmd" DIRECT_BUILD="$DIRECT_BUILD" PARALLEL_BUILD="$PARALLEL_BUILD" \
      BATCH_MODE=1 MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
      >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: CMD=$cmd (exit $ec) at $(date -Is)"
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-short-ota.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

run_pkg batocera-controlcenter-reinstall
run_cmd target-finalize

TARGET="$PRIMARY/target"
rm -f "$TARGET/etc/init.d/S06qcom-fan"
install -m 0755 \
  "$PROJECT_DIR/board/batocera/qualcomm/sm8750/fsoverlay/etc/init.d/S12qcom-fan" \
  "$TARGET/etc/init.d/S12qcom-fan"

log ""
log ">>> Short-OTA target greps"
fail=0
set +e

if grep -qE '^CHECK_INTERVAL = 2' "$TARGET/usr/bin/qcom-fan" \
   && grep -q 'wait_userdata' "$TARGET/usr/bin/qcom-fan"; then
  log "PASS qcom-fan_fast_poll_userdata"
else
  log "FAIL qcom-fan_fast_poll_userdata"; fail=1
fi

if grep -q 'batocera-temp --cpu' \
     "$TARGET/usr/share/batocera/controlcenter/controlcenter.xml" 2>/dev/null; then
  log "PASS controlcenter_temp_cpu"
else
  log "FAIL controlcenter_temp_cpu"; fail=1
fi

if [ -x "$TARGET/etc/init.d/S12qcom-fan" ] && [ ! -e "$TARGET/etc/init.d/S06qcom-fan" ]; then
  log "PASS S12qcom_fan_no_S06"
else
  log "FAIL S12qcom_fan_no_S06"; fail=1
fi

if grep -q '11.0-20260703-slr' "$TARGET/usr/bin/batocera-steam" 2>/dev/null; then
  log "PASS cachy_20260703_steam"
else
  log "FAIL cachy_20260703_steam"; fail=1
fi

if grep -q '11.0-20260703-slr' "$TARGET/usr/bin/batocera-wine-tools" 2>/dev/null; then
  log "PASS cachy_20260703_wine_tools"
else
  log "FAIL cachy_20260703_wine_tools"; fail=1
fi

if grep -q 'vulkan_mid_frame_submission_draws' \
     "$TARGET/usr/lib/python"*/site-packages/configgen/generators/xenia_edge/xenia_edgeGenerator.py \
     2>/dev/null; then
  log "PASS xenia_mid_frame_configgen"
else
  log "FAIL xenia_mid_frame_configgen"; fail=1
fi

if [ -f "$TARGET/usr/share/xenia-edge/config/4D5307F1.config.toml" ] \
   && [ -f "$TARGET/usr/share/xenia-edge/config/544307D5.config.toml" ]; then
  log "PASS xenia_edge_toml_configs"
else
  log "FAIL xenia_edge_toml_configs"; fail=1
fi

if grep -q 'batocera-ui-scale' \
     "$TARGET/usr/share/batocera/datainit/roms/emulator/Start_Arch_Plasma_LXC.sh" 2>/dev/null; then
  log "PASS start_arch_ui_scale"
else
  log "FAIL start_arch_ui_scale"; fail=1
fi

VER="$TARGET/usr/share/batocera/batocera.version"
if [ -f "$VER" ] && ! grep -q '2026/08/09' "$VER"; then
  log "PASS batocera_version_refreshed ($(tr -d '\n' <"$VER"))"
else
  log "FAIL batocera_version_refreshed ($(cat "$VER" 2>/dev/null | tr -d '\n'))"; fail=1
fi

if grep -q 'system.cpu.governor=ondemand' \
     "$TARGET/usr/share/batocera/sysconfigs/batocera.conf.AYN_Odin_3" 2>/dev/null; then
  log "PASS odin3_ondemand_sysconfig"
else
  log "FAIL odin3_ondemand_sysconfig"; fail=1
fi

set -e
log "short prechecks fail=$fail"
[ "$fail" -eq 0 ] || exit 1

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
echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-short-ota.DONE"
ln -sfn "$LOG_FILE" "$REVIEW_LOG"
