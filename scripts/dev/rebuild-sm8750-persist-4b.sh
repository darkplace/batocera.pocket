#!/bin/bash
# Persist oleada 4b: configgen (dolphin/rpcs3Paths/xenia + keep 4a) + splash-odin3 + image.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"
LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-persist-4b.log}"
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
CG_SRC="$PROJECT_DIR/package/batocera/core/batocera-configgen/configgen/configgen/generators"

log() { printf '%s\n' "$@" >>"$LOG_FILE"; }
: >"$LOG_FILE"
{
  echo "=== batocera.pocket PERSIST 4b (sm8750) ==="
  echo "Date: $(date -Is)"
  echo "PID: $$"
  echo "Focus: configgen 4b (dolphin/rpcs3Paths/xenia) + keep 4a + splash-odin3"
} >>"$LOG_FILE"
rm -f "$PROJECT_DIR/rebuild-sm8750-persist-4b.DONE" "$PROJECT_DIR/rebuild-sm8750-persist-4b.FAILED"
ln -sfn "$LOG_FILE" "$PROJECT_DIR/output/upstream-review/rebuild-sm8750-persist-4b.log"

run_pkg() {
  local pkg="$1" ec
  log ""; log ">>> make sm8750-pkg PKG=$pkg  ($(date -Is))"
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
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-persist-4b.FAILED"
    exit "$ec"
  fi
  log "OK: $pkg"
}

run_cmd() {
  local cmd="$1" ec
  log ""; log ">>> make sm8750-build CMD=$cmd  ($(date -Is))"
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
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-persist-4b.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

run_pkg batocera-configgen-rebuild
run_pkg batocera-splash-reinstall
run_pkg batocera-splash-odin3-reinstall

TARGET="$PRIMARY/target"

# Force splash branding
SPLASH_ODIN3="$PROJECT_DIR/package/batocera/core/batocera-splash-odin3"
mkdir -p "$TARGET/usr/share/batocera/splash"
install -m 0755 "$SPLASH_ODIN3/images/logo.png" "$TARGET/usr/share/batocera/splash/boot-logo.png"
install -m 0755 "$SPLASH_ODIN3/images/logo-480p.png" "$TARGET/usr/share/batocera/splash/boot-logo-4x3.png"
install -m 0755 "$SPLASH_ODIN3/videos/splash.mp4" "$TARGET/usr/share/batocera/splash/splash.mp4"

# Force generators into site-packages (4a keep + 4b)
CG_DST=$(echo "$TARGET"/usr/lib/python*/site-packages/configgen/generators)
install -m 0644 "$CG_SRC/play/playGenerator.py" "$CG_DST/play/playGenerator.py"
install -m 0644 "$CG_SRC/azahar/azaharGenerator.py" "$CG_DST/azahar/azaharGenerator.py"
install -m 0644 "$CG_SRC/cemu/cemuGenerator.py" "$CG_DST/cemu/cemuGenerator.py"
install -m 0644 "$CG_SRC/vita3k/vita3kGenerator.py" "$CG_DST/vita3k/vita3kGenerator.py"
install -m 0644 "$CG_SRC/dolphin/dolphinGenerator.py" "$CG_DST/dolphin/dolphinGenerator.py"
install -m 0644 "$CG_SRC/dolphin/dolphinSYSCONF.py" "$CG_DST/dolphin/dolphinSYSCONF.py"
install -m 0644 "$CG_SRC/rpcs3/rpcs3Paths.py" "$CG_DST/rpcs3/rpcs3Paths.py"
install -m 0644 "$CG_SRC/xenia_edge/xenia_edgeGenerator.py" "$CG_DST/xenia_edge/xenia_edgeGenerator.py"

# Keep fan/upgrade pocket
SCR="$PROJECT_DIR/package/batocera/core/batocera-scripts/scripts"
install -m 0755 "$SCR/qcom-fan" "$TARGET/usr/bin/qcom-fan"
install -m 0755 "$SCR/batocera-upgrade" "$TARGET/usr/bin/batocera-upgrade"

log ">>> persist-4b greps"
fail=0
# 4a
grep -q 'emukill 5' "$CG_DST/play/playGenerator.py" || { log FAIL play_swissknife; fail=1; }
grep -q 'large_screen_proportion' "$CG_DST/azahar/azaharGenerator.py" || { log FAIL azahar_prop; fail=1; }
grep -q 'hasInternalMangoHUDCall' "$CG_DST/cemu/cemuGenerator.py" || { log FAIL cemu_mango; fail=1; }
grep -q 'seed_candidates' "$CG_DST/vita3k/vita3kGenerator.py" || { log FAIL vita_seed; fail=1; }
# 4b
grep -q 'add_section("GBA")' "$CG_DST/dolphin/dolphinGenerator.py" || { log FAIL dolphin_gba; fail=1; }
grep -q '6c' "$CG_DST/dolphin/dolphinGenerator.py" || { log FAIL dolphin_6c; fail=1; }
grep -q 'KEY_F10' "$CG_DST/dolphin/dolphinGenerator.py" || { log FAIL dolphin_f10; fail=1; }
grep -q 'AM-Baseboard' "$CG_DST/dolphin/dolphinGenerator.py" || { log FAIL dolphin_am; fail=1; }
grep -q 'BATOCERA_DOLPHIN_ACHIEVEMENT_SOUND' "$CG_DST/dolphin/dolphinGenerator.py" || { log FAIL dolphin_ach; fail=1; }
grep -q 'wii_language' "$CG_DST/dolphin/dolphinSYSCONF.py" || { log FAIL dolphin_lang; fail=1; }
grep -q 'RPCS3_VFS_CONFIG' "$CG_DST/rpcs3/rpcs3Paths.py" || { log FAIL rpcs3_vfs; fail=1; }
grep -q 'vulkan_mid_frame_submission_draws' "$CG_DST/xenia_edge/xenia_edgeGenerator.py" || { log FAIL xenia_mid; fail=1; }
grep -q 'XENIA_EDGE_QCOM_MID_FRAME_DRAWS' "$CG_DST/xenia_edge/xenia_edgeGenerator.py" || { log FAIL xenia_qcom; fail=1; }
md5sum "$TARGET/usr/share/batocera/splash/boot-logo.png" | grep -q a03a62aca4944202625f2bed25f38c30 \
  || { log FAIL splash_odin3; fail=1; }
grep -q 'TempTracker' "$TARGET/usr/bin/qcom-fan" || { log FAIL fan; fail=1; }
grep -q 'darkplace/batocera.pocket' "$TARGET/usr/bin/batocera-upgrade" || { log FAIL upgrade; fail=1; }
[ "$fail" -eq 0 ] || { echo FAILED greps >"$PROJECT_DIR/rebuild-sm8750-persist-4b.FAILED"; exit 1; }
log "PASS persist-4b greps"

run_cmd target-finalize
rm -f "$PRIMARY/images/rootfs.squashfs"
rm -f "$IMG_DIR"/batocera-sm8750-*.img.gz
rm -f "$IMG_DIR"/boot.tar.xz
run_cmd all

{
  echo ""
  echo "=== Finished OK: $(date -Is) ==="
  ls -lh "$IMG_DIR"/batocera-sm8750-*.img.gz "$IMG_DIR"/boot.tar.xz 2>/dev/null || true
} | tee -a "$LOG_FILE"
echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-persist-4b.DONE"
