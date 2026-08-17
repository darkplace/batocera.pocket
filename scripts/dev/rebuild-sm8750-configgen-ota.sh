#!/usr/bin/env bash
# Short rebuild: refresh batocera-configgen (aethersx2 get_str + rpcs3Paths) and remake images.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-configgen-ota.log}"
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
rm -f "$PROJECT_DIR/rebuild-sm8750-configgen-ota.DONE" "$PROJECT_DIR/rebuild-sm8750-configgen-ota.FAILED"

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
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-configgen-ota.FAILED"
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
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-configgen-ota.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

log "=== sm8750 configgen short OTA ==="
log "Date: $(date -Is) PID=$$"

# Buildroot *-rebuild does NOT always re-extract; wipe package dir so rsync
# pulls latest aethersx2/rpcs3 sources from the tree.
log ">>> wiping output/sm8750/build/batocera-configgen-*"
rm -rf "$PRIMARY"/build/batocera-configgen-*

run_pkg batocera-configgen-rebuild
run_pkg batocera-system-reinstall

TARGET="$PRIMARY/target"
# Keep WiFi fix present (belt-and-suspenders)
install -m 0755 \
  "$PROJECT_DIR/board/batocera/qualcomm/sm8750/fsoverlay/etc/init.d/S09sm8750-wifi-resilience" \
  "$TARGET/etc/init.d/S09sm8750-wifi-resilience"

# Resolve python site-packages without broken globs under set -u
AES=$(ls "$TARGET"/usr/lib/python*/site-packages/configgen/generators/aethersx2/aethersx2Generator.py 2>/dev/null | head -1 || true)
RPC=$(ls "$TARGET"/usr/lib/python*/site-packages/configgen/generators/rpcs3/rpcs3Paths.py 2>/dev/null | head -1 || true)
RPCGEN=$(ls "$TARGET"/usr/lib/python*/site-packages/configgen/generators/rpcs3/rpcs3Generator.py 2>/dev/null | head -1 || true)
SRC_CFG="$PROJECT_DIR/package/batocera/core/batocera-configgen/configgen/configgen/generators"

# Force-sync critical files if rebuild still left stale copies
if [ -n "$AES" ] && ! grep -q 'get_str("aethersx2_renderer"' "$AES"; then
  log "WARN forcing aethersx2Generator.py from source"
  install -m 0644 "$SRC_CFG/aethersx2/aethersx2Generator.py" "$AES"
fi
if [ -n "$RPC" ] && ! grep -q 'RPCS3_PATCH_YML' "$RPC"; then
  log "WARN forcing rpcs3Paths.py from source"
  install -m 0644 "$SRC_CFG/rpcs3/rpcs3Paths.py" "$RPC"
fi
if [ -n "$RPCGEN" ]; then
  install -m 0644 "$SRC_CFG/rpcs3/rpcs3Generator.py" "$RPCGEN"
fi

fail=0
if [ -n "$AES" ] && grep -q 'get_str("aethersx2_renderer"' "$AES"; then
  log "PASS aethersx2_get_str ($AES)"
else
  log "FAIL aethersx2_get_str (AES='$AES')"
  fail=1
fi
if [ -n "$RPC" ] && grep -q 'RPCS3_PATCH_YML' "$RPC"; then
  log "PASS rpcs3_PATCH_YML ($RPC)"
else
  log "FAIL rpcs3_PATCH_YML (RPC='$RPC')"
  fail=1
fi
if grep -q 'dead-air' "$TARGET/etc/init.d/S09sm8750-wifi-resilience"; then
  log "PASS wifi_dead_air"
else
  log "FAIL wifi"
  fail=1
fi
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
  # re-verify inside freshly staged version file + greps on target
  grep -n 'get_str("aethersx2_renderer"' $AES | head -1 || true
  grep -n 'RPCS3_PATCH_YML' $RPC | head -1 || true
} | tee -a "$LOG_FILE"

echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-configgen-ota.DONE"
