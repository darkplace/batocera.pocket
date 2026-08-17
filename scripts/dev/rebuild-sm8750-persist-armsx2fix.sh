#!/bin/bash
# Persist configgen fix: aethersx2/armsx2 get_str + keep 4a/4b generators + splash.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"
LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-persist-armsx2fix.log}"
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
  echo "=== batocera.pocket PERSIST armsx2-fix (sm8750) ==="
  echo "Date: $(date -Is)"
  echo "PID: $$"
  echo "Focus: configgen get_str aethersx2/armsx2 + keep 4a/4b + splash"
} >>"$LOG_FILE"
rm -f "$PROJECT_DIR/rebuild-sm8750-persist-armsx2fix.DONE" "$PROJECT_DIR/rebuild-sm8750-persist-armsx2fix.FAILED"
ln -sfn "$LOG_FILE" "$PROJECT_DIR/output/upstream-review/rebuild-sm8750-persist-armsx2fix.log"

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
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-persist-armsx2fix.FAILED"
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
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-persist-armsx2fix.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

run_pkg batocera-configgen-rebuild
run_pkg batocera-splash-odin3-reinstall

TARGET="$PRIMARY/target"
SPLASH_ODIN3="$PROJECT_DIR/package/batocera/core/batocera-splash-odin3"
mkdir -p "$TARGET/usr/share/batocera/splash"
install -m 0755 "$SPLASH_ODIN3/images/logo.png" "$TARGET/usr/share/batocera/splash/boot-logo.png"
install -m 0755 "$SPLASH_ODIN3/images/logo-480p.png" "$TARGET/usr/share/batocera/splash/boot-logo-4x3.png"
install -m 0755 "$SPLASH_ODIN3/videos/splash.mp4" "$TARGET/usr/share/batocera/splash/splash.mp4"

CG_DST=$(echo "$TARGET"/usr/lib/python*/site-packages/configgen/generators)
# Force critical generators from source
for pair in \
  play/playGenerator.py \
  azahar/azaharGenerator.py \
  cemu/cemuGenerator.py \
  vita3k/vita3kGenerator.py \
  dolphin/dolphinGenerator.py \
  dolphin/dolphinSYSCONF.py \
  rpcs3/rpcs3Paths.py \
  xenia_edge/xenia_edgeGenerator.py \
  aethersx2/aethersx2Generator.py \
  armsx2/armsx2Generator.py
do
  install -m 0644 "$CG_SRC/$pair" "$CG_DST/$pair"
done

SCR="$PROJECT_DIR/package/batocera/core/batocera-scripts/scripts"
install -m 0755 "$SCR/qcom-fan" "$TARGET/usr/bin/qcom-fan"
install -m 0755 "$SCR/batocera-upgrade" "$TARGET/usr/bin/batocera-upgrade"

log ">>> persist-armsx2fix greps"
fail=0
grep -q 'get_str("aethersx2_renderer"' "$CG_DST/aethersx2/aethersx2Generator.py" || { log FAIL aether_get_str; fail=1; }
grep -q 'get_str("aethersx2_renderer"' "$CG_DST/armsx2/armsx2Generator.py" || { log FAIL arms_get_str; fail=1; }
grep -q 'emukill 5' "$CG_DST/play/playGenerator.py" || { log FAIL play; fail=1; }
grep -q 'vulkan_mid_frame_submission_draws' "$CG_DST/xenia_edge/xenia_edgeGenerator.py" || { log FAIL xenia; fail=1; }
grep -q 'KEY_F10' "$CG_DST/dolphin/dolphinGenerator.py" || { log FAIL dolphin; fail=1; }
md5sum "$TARGET/usr/share/batocera/splash/boot-logo.png" | grep -q a03a62aca4944202625f2bed25f38c30 \
  || { log FAIL splash; fail=1; }
[ "$fail" -eq 0 ] || { echo FAILED greps >"$PROJECT_DIR/rebuild-sm8750-persist-armsx2fix.FAILED"; exit 1; }
log "PASS greps"

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
echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-persist-armsx2fix.DONE"
