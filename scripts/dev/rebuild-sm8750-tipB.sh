#!/bin/bash
# Tip oleada B: xenia-edge c38a672 + xenia-canary 92ada8e + shadps4 side-build/inject.
# RPCS3/Gopher64 tip bumps blocked (LLVM / rustc) — stay pinned.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"
LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-tipB.log}"
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
  echo "=== batocera.pocket TIP WAVE B (sm8750) ==="
  echo "Date: $(date -Is)"
  echo "PID: $$"
  echo "Focus: xenia-edge c38a672, xenia-canary 92ada8e, shadps4 5a4373c via FEX side-build"
  echo "Blocked: rpcs3 cd814f8 (LLVM), gopher64 c2b64ad (rustc 1.97)"
} >>"$LOG_FILE"
rm -f "$PROJECT_DIR/rebuild-sm8750-tipB.DONE" "$PROJECT_DIR/rebuild-sm8750-tipB.FAILED"
ln -sfn "$LOG_FILE" "$PROJECT_DIR/output/upstream-review/rebuild-sm8750-tipB.log"

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
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-tipB.FAILED"
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
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-tipB.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

run_side() {
  local ec
  log ""; log ">>> make sm8750_x86_64_v3_shadps4-build  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8750_x86_64_v3_shadps4-build \
      DIRECT_BUILD="$DIRECT_BUILD" \
      PARALLEL_BUILD="$PARALLEL_BUILD" \
      BATCH_MODE=1 \
      MAKE_JLEVEL="${MAKE_JLEVEL:-12}" \
      MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
      >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: sm8750_x86_64_v3_shadps4-build (exit $ec) at $(date -Is)"
    echo "FAILED shadps4-side $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-tipB.FAILED"
    exit "$ec"
  fi
  log "OK: sm8750_x86_64_v3_shadps4-build"
}

# --- native tips ---
if [ "${TIPB_SKIP_XENIA:-0}" != "1" ]; then
  run_pkg xenia-edge-rebuild
  run_pkg xenia-canary-rebuild
else
  log "SKIP xenia (TIPB_SKIP_XENIA=1)"
fi

# --- shadPS4 x86_64 guest for FEX ---
if [ "${TIPB_SKIP_SIDE:-0}" != "1" ]; then
  run_side
  run_pkg shadps4-fex-reinstall
else
  log "SKIP side-build/fex (TIPB_SKIP_SIDE=1)"
fi

TARGET="$PRIMARY/target"
# Inject guest rootfs (same helper post-build uses)
if [ -x "$PROJECT_DIR/board/batocera/scripts/inject-shadps4-fex-rootfs.sh" ]; then
  log ">>> inject-shadps4-fex-rootfs"
  "$PROJECT_DIR/board/batocera/scripts/inject-shadps4-fex-rootfs.sh" \
      SM8750 "$TARGET" "$PROJECT_DIR" >>"$LOG_FILE" 2>&1 \
    || { echo FAILED inject >"$PROJECT_DIR/rebuild-sm8750-tipB.FAILED"; exit 1; }
fi

# Splash + keep configgen locks
SPLASH_ODIN3="$PROJECT_DIR/package/batocera/core/batocera-splash-odin3"
mkdir -p "$TARGET/usr/share/batocera/splash"
install -m 0755 "$SPLASH_ODIN3/images/logo.png" "$TARGET/usr/share/batocera/splash/boot-logo.png"
install -m 0755 "$SPLASH_ODIN3/images/logo-480p.png" "$TARGET/usr/share/batocera/splash/boot-logo-4x3.png"
install -m 0755 "$SPLASH_ODIN3/videos/splash.mp4" "$TARGET/usr/share/batocera/splash/splash.mp4"

CG_DST=$(echo "$TARGET"/usr/lib/python*/site-packages/configgen/generators)
install -m 0644 "$CG_SRC/xenia_edge/xenia_edgeGenerator.py" "$CG_DST/xenia_edge/xenia_edgeGenerator.py"
install -m 0644 "$CG_SRC/shadps4/shadps4Generator.py" "$CG_DST/shadps4/shadps4Generator.py"
install -m 0644 "$CG_SRC/aethersx2/aethersx2Generator.py" "$CG_DST/aethersx2/aethersx2Generator.py"
install -m 0644 "$CG_SRC/armsx2/armsx2Generator.py" "$CG_DST/armsx2/armsx2Generator.py"

SCR="$PROJECT_DIR/package/batocera/core/batocera-scripts/scripts"
install -m 0755 "$SCR/qcom-fan" "$TARGET/usr/bin/qcom-fan"
install -m 0755 "$SCR/batocera-upgrade" "$TARGET/usr/bin/batocera-upgrade"

log ">>> tipB greps"
fail=0
# Prefer rg -a on the ELF (strings on ~900MB binaries is flaky/slow under load).
XENIA_EDGE_BIN="$TARGET/usr/xenia_edge/xenia_edge"
if command -v rg >/dev/null 2>&1; then
  rg -a -q 'c38a672' "$XENIA_EDGE_BIN" \
    || { log FAIL xenia_edge_tip_string; fail=1; }
else
  grep -a -q 'c38a672' "$XENIA_EDGE_BIN" \
    || { log FAIL xenia_edge_tip_string; fail=1; }
fi
grep -q 'vulkan_mid_frame_submission_draws' "$CG_DST/xenia_edge/xenia_edgeGenerator.py" || { log FAIL xenia_mid; fail=1; }
grep -q 'SHADPS4_FEX_BIN' "$CG_DST/shadps4/shadps4Generator.py" || { log FAIL shad_fex_lock; fail=1; }
test -x "$TARGET/usr/share/batocera/apps/shadps4-fex-rootfs/usr/bin/shadps4/shadps4" \
  || test -x "$TARGET/usr/bin/shadps4-x86_64/shadps4" \
  || { log FAIL shadps4_payload; fail=1; }
md5sum "$TARGET/usr/share/batocera/splash/boot-logo.png" | grep -q a03a62aca4944202625f2bed25f38c30 \
  || { log FAIL splash; fail=1; }
[ "$fail" -eq 0 ] || { echo FAILED greps >"$PROJECT_DIR/rebuild-sm8750-tipB.FAILED"; exit 1; }
log "PASS tipB greps"

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
echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-tipB.DONE"
