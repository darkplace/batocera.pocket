#!/bin/bash
# Short OTA rebuild sm8750 — fan/CC/Cachy/splash + fix configgen/Start_Arch.
# Uses -rebuild for packages whose extract/build must refresh local sources.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-short-ota.log}"
REVIEW_LOG="$PROJECT_DIR/output/upstream-review/rebuild-sm8750-short-ota.log"
PRIMARY="$PROJECT_DIR/output/sm8750"
DIRECT_BUILD=
PARALLEL_BUILD=
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
mkdir -p "$PRIMARY" "$PROJECT_DIR/output/upstream-review"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
mkdir -p "$TMPDIR"
export CMAKE_POLICY_VERSION_MINIMUM=3.5
IMG_DIR="$PRIMARY/images/batocera/images/sm8750"

log() { printf '%s\n' "$@" >>"$LOG_FILE"; }

: >"$LOG_FILE"
{
  echo "=== batocera.pocket SHORT OTA rebuild (sm8750) ==="
  echo "Date: $(date -Is)"
  echo "PID: $$"
  echo "Tree: $PRIMARY"
  echo "Log: $LOG_FILE"
  echo "Focus: fan safety, Control Deck selected, Cachy 20260703, splash/version,"
  echo "       xenia TOMLs/mid_frame, Start_Arch ui-scale (NOT full emu/mesa wave)"
  echo ""
} >>"$LOG_FILE"
ln -sfn "$LOG_FILE" "$REVIEW_LOG"
rm -f "$PROJECT_DIR/rebuild-sm8750-short-ota.DONE" "$PROJECT_DIR/rebuild-sm8750-short-ota.FAILED"

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
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-short-ota.FAILED"
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
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-short-ota.FAILED"
    ln -sfn "$LOG_FILE" "$REVIEW_LOG"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

# -rebuild: re-extract/rsync local sources (configgen, es-system roms, CC patches).
run_pkg batocera-scripts-rebuild
run_pkg batocera-system-reinstall
# Generic splash first, then Odin 3 branding (must reinstall after batocera-splash).
run_pkg batocera-splash-reinstall
run_pkg batocera-splash-odin3-reinstall
run_pkg batocera-steam-aarch64-reinstall
run_pkg batocera-wine-reinstall
run_pkg batocera-configgen-rebuild
run_pkg xenia-edge-reinstall
run_pkg batocera-es-system-rebuild
run_pkg batocera-controlcenter-rebuild
run_cmd target-finalize

TARGET="$PRIMARY/target"

# Belt-and-suspenders: force Odin 3 splash over generic batocera-splash.
SPLASH_ODIN3="$PROJECT_DIR/package/batocera/core/batocera-splash-odin3"
install -m 0755 "$SPLASH_ODIN3/images/logo.png" \
  "$TARGET/usr/share/batocera/splash/boot-logo.png"
install -m 0755 "$SPLASH_ODIN3/images/logo-480p.png" \
  "$TARGET/usr/share/batocera/splash/boot-logo-4x3.png"
install -m 0755 "$SPLASH_ODIN3/videos/splash.mp4" \
  "$TARGET/usr/share/batocera/splash/splash.mp4"

# Belt-and-suspenders: force latest critical files into target (incremental trees).
install -m 0755 \
  "$PROJECT_DIR/package/batocera/core/batocera-scripts/scripts/qcom-fan" \
  "$TARGET/usr/bin/qcom-fan"
rm -f "$TARGET/etc/init.d/S06qcom-fan"
install -m 0755 \
  "$PROJECT_DIR/board/batocera/qualcomm/sm8750/fsoverlay/etc/init.d/S12qcom-fan" \
  "$TARGET/etc/init.d/S12qcom-fan"
install -m 0755 \
  "$PROJECT_DIR/package/batocera/core/batocera-controlcenter/controlcenter.xml" \
  "$TARGET/usr/share/batocera/controlcenter/controlcenter.xml"
install -m 0755 \
  "$PROJECT_DIR/package/batocera/emulationstation/batocera-es-system/roms/emulator/Start_Arch_Plasma_LXC.sh" \
  "$TARGET/usr/share/batocera/datainit/roms/emulator/Start_Arch_Plasma_LXC.sh"
PY_GEN=$(echo "$TARGET"/usr/lib/python*/site-packages/configgen/generators/xenia_edge/xenia_edgeGenerator.py)
if [ -f "$PY_GEN" ]; then
  install -m 0644 \
    "$PROJECT_DIR/package/batocera/core/batocera-configgen/configgen/configgen/generators/xenia_edge/xenia_edgeGenerator.py" \
    "$PY_GEN"
fi
# Ensure CC ui_core has selected= support even if patch order raced.
if [ -f "$TARGET/usr/share/batocera/controlcenter/ui_core.py" ] \
   && ! grep -q 'initial_choice' "$TARGET/usr/share/batocera/controlcenter/ui_core.py"; then
  log "WARN: ui_core missing initial_choice after rebuild — applying /tmp patch if present"
  if [ -f /tmp/ui_core.py.after ]; then
    install -m 0755 /tmp/ui_core.py.after "$TARGET/usr/share/batocera/controlcenter/ui_core.py"
  fi
  if [ -f /tmp/xml_utils.py.after ]; then
    install -m 0755 /tmp/xml_utils.py.after "$TARGET/usr/share/batocera/controlcenter/xml_utils.py"
  fi
fi

log ""
log ">>> Short-OTA target greps"
fail=0
set +e

if grep -qE '^CHECK_INTERVAL = 1' "$TARGET/usr/bin/qcom-fan" \
   && grep -q 'TempTracker' "$TARGET/usr/bin/qcom-fan" \
   && grep -q 'wait_userdata' "$TARGET/usr/bin/qcom-fan" \
   && grep -q '60=75' "$TARGET/usr/bin/qcom-fan"; then
  log "PASS qcom-fan_thermal_safety"
else
  log "FAIL qcom-fan_thermal_safety"; fail=1
fi

if [ -x "$TARGET/etc/init.d/S12qcom-fan" ] && [ ! -e "$TARGET/etc/init.d/S06qcom-fan" ]; then
  log "PASS S12qcom-fan_no_S06"
else
  log "FAIL S12qcom-fan_no_S06"; fail=1
fi

if grep -q 'batocera-temp --cpu' \
     "$TARGET/usr/share/batocera/controlcenter/controlcenter.xml" 2>/dev/null \
   && grep -q 'selected=' "$TARGET/usr/share/batocera/controlcenter/controlcenter.xml" 2>/dev/null \
   && ! grep -q '<!-- Prefer batocera-temp' \
        "$TARGET/usr/share/batocera/controlcenter/controlcenter.xml" 2>/dev/null; then
  log "PASS controlcenter_xml_fan_temp"
else
  log "FAIL controlcenter_xml_fan_temp"; fail=1
fi

if grep -q 'initial_choice' \
     "$TARGET/usr/share/batocera/controlcenter/ui_core.py" 2>/dev/null; then
  log "PASS controlcenter_choice_selected"
else
  log "FAIL controlcenter_choice_selected"; fail=1
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

if [ -x "$TARGET/usr/bin/batocera-temp" ] && [ -x "$TARGET/usr/bin/batocera-keyboard" ] \
   && grep -q 'batocera-pending-volume' "$TARGET/usr/bin/batocera-audio" 2>/dev/null; then
  log "PASS wave1_scripts_audio"
else
  log "FAIL wave1_scripts_audio"; fail=1
fi

# Pocket splash must survive batocera-splash reinstall (Odin 3 package / copy).
if md5sum "$TARGET/usr/share/batocera/splash/boot-logo.png" 2>/dev/null \
     | grep -q a03a62aca4944202625f2bed25f38c30; then
  log "PASS splash_odin3_branding"
else
  log "FAIL splash_odin3_branding ($(md5sum "$TARGET/usr/share/batocera/splash/boot-logo.png" 2>/dev/null))"
  fail=1
fi

set -e
log "short prechecks fail=$fail"
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
echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-short-ota.DONE"
ln -sfn "$LOG_FILE" "$REVIEW_LOG"
