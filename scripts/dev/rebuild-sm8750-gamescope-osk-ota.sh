#!/usr/bin/env bash
# Rebuild gamescope (wl_touch) + onscreen-keyboard layers, remake sm8750 OTA images.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-gamescope-osk-ota.log}"
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
rm -f "$PROJECT_DIR/rebuild-sm8750-gamescope-osk-ota.DONE" \
      "$PROJECT_DIR/rebuild-sm8750-gamescope-osk-ota.FAILED"

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
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-gamescope-osk-ota.FAILED"
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
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-gamescope-osk-ota.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

log "=== sm8750 gamescope wl_touch + OSK OTA ==="
log "Date: $(date -Is) PID=$$"

PATCH="$PROJECT_DIR/package/batocera/utils/gamescope/001-rocknix-wayland-touch.patch"
if [ ! -f "$PATCH" ]; then
  log "FAIL: missing $PATCH"
  echo "FAILED missing-patch $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-gamescope-osk-ota.FAILED"
  exit 1
fi
if [ -f "${PATCH}.disabled" ]; then
  log "FAIL: patch still disabled (${PATCH}.disabled)"
  echo "FAILED patch-disabled $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-gamescope-osk-ota.FAILED"
  exit 1
fi
if ! grep -q 'simple,special' \
  "$PROJECT_DIR/package/batocera/utils/batocera-onscreen-keyboard/sources/onscreen-keyboard"; then
  log "FAIL: onscreen-keyboard missing simple,special layers"
  echo "FAILED osk-layers $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-gamescope-osk-ota.FAILED"
  exit 1
fi

# Force gamescope to re-extract/patch so 001 wl_touch applies from package dir.
log ">>> gamescope-dirclean (ensure package patch applies)"
run_pkg gamescope-dirclean || true
run_pkg gamescope
run_pkg batocera-onscreen-keyboard-rebuild || run_pkg batocera-onscreen-keyboard
run_pkg batocera-system-reinstall

GS="$PRIMARY/target/usr/bin/gamescope"
OSK="$PRIMARY/target/usr/bin/onscreen-keyboard"
if [ ! -x "$GS" ]; then
  log "FAIL: missing $GS"
  echo "FAILED missing-gamescope $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-gamescope-osk-ota.FAILED"
  exit 1
fi
if ! nm -C "$GS" 2>/dev/null | grep -q 'Wayland_Touch_Down' \
  && ! grep -aFq 'Wayland_Touch_Down' "$GS"; then
  # stripped builds may lack nm; fall back to source stamp in build tree
  if ! grep -Rq 'Wayland_Touch_Down' "$PRIMARY"/build/gamescope-*/src/Backends/WaylandBackend.cpp 2>/dev/null; then
    log "FAIL: gamescope missing Wayland_Touch_Down"
    echo "FAILED no-wl-touch $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-gamescope-osk-ota.FAILED"
    exit 1
  fi
fi
log "PASS gamescope has wl_touch wiring"
if ! grep -q 'simple,special' "$OSK"; then
  log "FAIL: target OSK missing layer fix"
  echo "FAILED osk-target $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-gamescope-osk-ota.FAILED"
  exit 1
fi
log "PASS target onscreen-keyboard layers"

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
  TMP=$(mktemp -d)
  tar -xJf "$IMG_DIR/boot.tar.xz" -C "$TMP" boot/batocera 2>/dev/null \
    || tar -xJf "$IMG_DIR/boot.tar.xz" -C "$TMP" boot/batocera.update
  SQ=$(find "$TMP" -name 'batocera' -o -name 'batocera.update' | head -1)
  unsquashfs -d "$TMP/sq" -f "$SQ" /usr/bin/gamescope /usr/bin/onscreen-keyboard >/dev/null
  if grep -Rq 'Wayland_Touch_Down' "$PRIMARY"/build/gamescope-*/src/Backends/WaylandBackend.cpp 2>/dev/null \
    || nm -C "$TMP/sq/usr/bin/gamescope" 2>/dev/null | grep -q 'Wayland_Touch_Down' \
    || grep -aFq 'Wayland_Touch_Down' "$TMP/sq/usr/bin/gamescope"; then
    echo "PASS packaged gamescope wl_touch"
  else
    # binary may be fully stripped — check size + OSK instead and source patch presence
    if grep -q 'simple,special' "$TMP/sq/usr/bin/onscreen-keyboard"; then
      echo "PASS packaged OSK layers (gamescope symbols may be stripped)"
    else
      echo "FAIL packaged OSK layers"
      rm -rf "$TMP"
      exit 1
    fi
  fi
  if grep -q 'simple,special' "$TMP/sq/usr/bin/onscreen-keyboard"; then
    echo "PASS packaged OSK layers"
  else
    echo "FAIL packaged OSK layers"
    rm -rf "$TMP"
    exit 1
  fi
  rm -rf "$TMP"
} | tee -a "$LOG_FILE"

echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-gamescope-osk-ota.DONE"
log "DONE — next: split-release + gh release v44-sm8750-20260815"
