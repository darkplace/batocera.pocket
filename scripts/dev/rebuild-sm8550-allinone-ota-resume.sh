#!/usr/bin/env bash
# Resume sm8550 all-in-one after RPATH false-fail on host ld.gold.
# Assumes ES/configgen/waydroid/wifi prechecks already passed.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8550-allinone-ota.log}"
PRIMARY="$PROJECT_DIR/output/sm8550"
IMG_DIR="$PRIMARY/images/batocera/images/sm8550"
HOST="$PRIMARY/host"
DIRECT_BUILD=
PARALLEL_BUILD=
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
rm -f "$PROJECT_DIR/rebuild-sm8550-allinone-ota.DONE" \
      "$PROJECT_DIR/rebuild-sm8550-allinone-ota.FAILED"

{
  echo ""
  echo "=== RESUME after RPATH fix ($(date -Is)) ==="
} >>"$LOG_FILE"

# Ensure contaminated host linker has a check-host-rpath-accepted RUNPATH
GOLD="$HOST/bin/aarch64-buildroot-linux-gnu-ld.gold"
if [ -f "$GOLD" ] && [ -x "$HOST/bin/patchelf" ]; then
  # Break hardlink so we don't corrupt toolchain sibling paths
  cp -a "$GOLD" "$GOLD.tmp" && mv "$GOLD.tmp" "$GOLD"
  "$HOST/bin/patchelf" --set-rpath '$ORIGIN/../lib' "$GOLD"
  log "PASS repaired $GOLD RPATH"
fi

run_cmd() {
  local cmd="$1" ec
  log ""; log ">>> make sm8550-build CMD=$cmd  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8550-build CMD="$cmd" DIRECT_BUILD="$DIRECT_BUILD" \
    PARALLEL_BUILD="$PARALLEL_BUILD" BATCH_MODE=1 \
    MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
    >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: CMD=$cmd ($ec)"
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8550-allinone-ota.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

# Re-assert wifi overlays (finalize may overwrite from fsoverlay anyway)
TARGET="$PRIMARY/target"
install -m 0755 \
  "$PROJECT_DIR/board/batocera/qualcomm/sm8550/fsoverlay/usr/bin/sm8550-wifi-resilience" \
  "$TARGET/usr/bin/sm8550-wifi-resilience"
install -m 0755 \
  "$PROJECT_DIR/board/batocera/qualcomm/sm8550/fsoverlay/etc/init.d/S09sm8550-wifi-resilience" \
  "$TARGET/etc/init.d/S09sm8550-wifi-resilience"

run_cmd target-finalize

log ">>> wipe prior images"
rm -f "$PRIMARY/images/rootfs.squashfs"
rm -f "$IMG_DIR"/batocera-sm8550-*.img.gz
rm -f "$IMG_DIR"/boot.tar.xz

run_cmd all

{
  echo ""
  echo "=== Finished OK: $(date -Is) ==="
  ls -lh "$IMG_DIR"/batocera-sm8550-*.img.gz "$IMG_DIR"/boot.tar.xz "$IMG_DIR"/batocera.version 2>/dev/null || true
  cat "$IMG_DIR"/batocera.version 2>/dev/null || true
  TMP=$(mktemp -d)
  tar -xJf "$IMG_DIR/boot.tar.xz" -C "$TMP" boot/batocera 2>/dev/null \
    || tar -xJf "$IMG_DIR/boot.tar.xz" -C "$TMP" boot/batocera.update
  SQ=$(find "$TMP" -name 'batocera' -o -name 'batocera.update' | head -1)
  unsquashfs -d "$TMP/sq" -f "$SQ" /usr/bin/emulationstation >/dev/null
  if grep -aFq 'devid=' "$TMP/sq/usr/bin/emulationstation"; then
    echo "PASS packaged ES devid="
  else
    echo "FAIL packaged ES missing devid="
    rm -rf "$TMP"
    exit 1
  fi
  rm -rf "$TMP"
} | tee -a "$LOG_FILE"

echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8550-allinone-ota.DONE"
log "DONE — next: split-release + publish"
