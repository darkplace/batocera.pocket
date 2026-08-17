#!/bin/bash
# Oleada 2: batocera-scripts rebuild + image (CMD=all) for OTA.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"
LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-wave2-scripts.log}"
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

RESUME="${1:-}"
if [ "$RESUME" != "--resume-image" ]; then
  : >"$LOG_FILE"
fi
{
  echo "=== batocera.pocket WAVE2 scripts rebuild (sm8750) ==="
  echo "Date: $(date -Is)"
  echo "PID: $$"
  echo "Mode: ${RESUME:-full}"
} >>"$LOG_FILE"
rm -f "$PROJECT_DIR/rebuild-sm8750-wave2-scripts.DONE" "$PROJECT_DIR/rebuild-sm8750-wave2-scripts.FAILED"
ln -sfn "$LOG_FILE" "$PROJECT_DIR/output/upstream-review/rebuild-sm8750-wave2-scripts.log"

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
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-wave2-scripts.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

if [ "$RESUME" != "--resume-image" ]; then
  run_cmd "batocera-scripts-dirclean"
  run_cmd "batocera-scripts-rebuild"
fi

TARGET="$PRIMARY/target"
# Force wave2 sources into target (belt-and-suspenders)
SCR="$PROJECT_DIR/package/batocera/core/batocera-scripts/scripts"
for f in batocera-info batocera-vulkan batocera-services batocera-storage-udev \
         batocera-storage-manager batocera-support batocera-systems \
         batocera-shutdown batocera-install-internal batocera-wifi \
         batocera-brightness batocera-temp batocera-keyboard; do
  [ -f "$SCR/$f" ] && install -m 0755 "$SCR/$f" "$TARGET/usr/bin/$f"
done
# Keep blacklist pocket binaries
install -m 0755 "$SCR/qcom-fan" "$TARGET/usr/bin/qcom-fan"
install -m 0755 "$SCR/batocera-upgrade" "$TARGET/usr/bin/batocera-upgrade"
install -m 0755 "$SCR/batocera-power-mode" "$TARGET/usr/bin/batocera-power-mode"
[ -f "$SCR/batocera-pocket-github-release" ] && \
  install -m 0755 "$SCR/batocera-pocket-github-release" "$TARGET/usr/bin/batocera-pocket-github-release"

log ">>> wave2 greps"
fail=0
grep -q 'supportsEncoding' "$TARGET/usr/bin/batocera-vulkan" || { log FAIL vulkan; fail=1; }
grep -q 'batocera-temp --cpu' "$TARGET/usr/bin/batocera-info" || { log FAIL info; fail=1; }
grep -q 'S51led-handheld' "$TARGET/usr/bin/batocera-shutdown" || { log FAIL shutdown_led; fail=1; }
grep -q 'TempTracker' "$TARGET/usr/bin/qcom-fan" || { log FAIL fan; fail=1; }
grep -q 'darkplace/batocera.pocket' "$TARGET/usr/bin/batocera-upgrade" || { log FAIL upgrade; fail=1; }
[ -x "$TARGET/usr/bin/batocera-install-internal" ] || { log FAIL install_internal; fail=1; }
[ "$fail" -eq 0 ] || { echo FAILED greps >"$PROJECT_DIR/rebuild-sm8750-wave2-scripts.FAILED"; exit 1; }
log "PASS wave2 greps"

# Force Odin 3 splash branding into target (batocera-splash alone leaves generic logos).
SPLASH_ODIN3="$PROJECT_DIR/package/batocera/core/batocera-splash-odin3"
mkdir -p "$TARGET/usr/share/batocera/splash"
install -m 0755 "$SPLASH_ODIN3/images/logo.png" \
  "$TARGET/usr/share/batocera/splash/boot-logo.png"
install -m 0755 "$SPLASH_ODIN3/images/logo-480p.png" \
  "$TARGET/usr/share/batocera/splash/boot-logo-4x3.png"
install -m 0755 "$SPLASH_ODIN3/videos/splash.mp4" \
  "$TARGET/usr/share/batocera/splash/splash.mp4"
# Expected pocket logo.md5
if ! md5sum "$TARGET/usr/share/batocera/splash/boot-logo.png" | grep -q a03a62aca4944202625f2bed25f38c30; then
  log "FAIL splash_odin3_branding"
  echo FAILED splash >"$PROJECT_DIR/rebuild-sm8750-wave2-scripts.FAILED"
  exit 1
fi
log "PASS splash_odin3_branding"

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
echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-wave2-scripts.DONE"
