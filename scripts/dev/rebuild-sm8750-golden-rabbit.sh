#!/usr/bin/env bash
# Rebuild sm8750 "Golden Rabbit" OTA image:
#   version 44-dev-pocket-golden-rabbit + Steam Proton11/MangoApp + wine-tools.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-golden-rabbit.log}"
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
rm -f "$PROJECT_DIR/rebuild-sm8750-golden-rabbit.DONE" "$PROJECT_DIR/rebuild-sm8750-golden-rabbit.FAILED"

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
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-golden-rabbit.FAILED"
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
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-golden-rabbit.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

log "=== sm8750 Golden Rabbit rebuild ==="
log "Date: $(date -Is) PID=$$"
log "Codename: Golden Rabbit (44-dev-pocket-golden-rabbit)"

run_pkg batocera-system-reinstall
run_pkg batocera-scripts-reinstall
run_pkg batocera-steam-aarch64-reinstall
run_pkg batocera-wine-reinstall

TARGET="$PRIMARY/target"
fail=0
if grep -q '44-dev-pocket-golden-rabbit' "$TARGET/usr/share/batocera/batocera.version" 2>/dev/null; then
  log "PASS version ($(cat "$TARGET/usr/share/batocera/batocera.version"))"
else
  log "FAIL version ($(cat "$TARGET/usr/share/batocera/batocera.version" 2>/dev/null || echo missing))"
  fail=1
fi
grep -q 'BATOCERA_STEAM_GS_MANGOAPP:-1' "$TARGET/usr/bin/batocera-steam" 2>/dev/null \
  && log "PASS mangoapp_batocera_steam" || { log "FAIL mangoapp_batocera_steam"; fail=1; }
grep -q '_mango_default="1"' "$TARGET/usr/bin/steam-direct-session.sh" 2>/dev/null \
  && log "PASS mangoapp_steam_direct" || { log "FAIL mangoapp_steam_direct"; fail=1; }
grep -q 'Do NOT symlink tool_dir' \
  "$TARGET/usr/bin/batocera-steam" 2>/dev/null \
  && log "PASS proton11_no_symlink" || { log "FAIL proton11_no_symlink"; fail=1; }
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
echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-golden-rabbit.DONE"
