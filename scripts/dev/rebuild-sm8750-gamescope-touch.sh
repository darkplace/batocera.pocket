#!/bin/bash
# Rebuild gamescope with wl_touch wired + batocera-onscreen-keyboard layers fix.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-gamescope-touch.log}"
DONE_FILE="$PROJECT_DIR/rebuild-sm8750-gamescope-touch.DONE"
FAIL_FILE="$PROJECT_DIR/rebuild-sm8750-gamescope-touch.FAILED"
B="$PROJECT_DIR/output/sm8750/build/gamescope-3.16.25"
PATCH="$PROJECT_DIR/package/batocera/utils/gamescope/001-rocknix-wayland-touch.patch"

rm -f "$DONE_FILE" "$FAIL_FILE"
: >"$LOG_FILE"

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }

trap 'log "FAILED at $(date -Is)"; touch "$FAIL_FILE"; exit 1' ERR

log "=== gamescope wl_touch + OSK rebuild ==="
log "Date: $(date -Is)"
log "PID: $$"

if [ ! -f "$PATCH" ]; then
  log "missing patch: $PATCH"
  exit 1
fi

if [ -f "$B/src/Backends/WaylandBackend.cpp" ]; then
  if ! grep -q Wayland_Touch_Down "$B/src/Backends/WaylandBackend.cpp"; then
    log "applying wl_touch patch to build tree"
    patch -d "$B" -p1 <"$PATCH"
  else
    log "build tree already has Wayland_Touch_Down"
  fi
else
  log "build tree missing; make will extract and apply package patch"
fi

rm -f "$B/.stamp_built" 2>/dev/null || true

log ">>> make sm8750-pkg PKG=gamescope ($(date -Is))"
stdbuf -oL -eL make sm8750-pkg PKG=gamescope BATCH_MODE=1 2>&1 | tee -a "$LOG_FILE"

log ">>> make sm8750-pkg PKG=batocera-onscreen-keyboard-rebuild ($(date -Is))"
if ! stdbuf -oL -eL make sm8750-pkg PKG=batocera-onscreen-keyboard-rebuild BATCH_MODE=1 2>&1 | tee -a "$LOG_FILE"; then
  log "rebuild target failed; trying plain package"
  stdbuf -oL -eL make sm8750-pkg PKG=batocera-onscreen-keyboard BATCH_MODE=1 2>&1 | tee -a "$LOG_FILE"
fi

log "=== verify ==="
if grep -q Wayland_Touch_Down "$B/src/Backends/WaylandBackend.cpp"; then
  log "PASS source has Wayland_Touch_Down"
else
  log "FAIL source missing Wayland_Touch_Down"
  exit 1
fi

if grep -q 'simple,special' "$PROJECT_DIR/output/sm8750/target/usr/bin/onscreen-keyboard"; then
  log "PASS onscreen-keyboard layers"
else
  log "FAIL onscreen-keyboard layers"
  exit 1
fi

GS_BIN="$PROJECT_DIR/output/sm8750/target/usr/bin/gamescope"
if [ -x "$GS_BIN" ]; then
  log "gamescope mtime: $(stat -c '%y' "$GS_BIN")"
fi

log "DONE $(date -Is)"
touch "$DONE_FILE"
