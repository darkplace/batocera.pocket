#!/usr/bin/env bash
# sm8550 all-in-one OTA: Screenscraper ES + configgen + Waydroid 1.6.3 + wifi parity + images.
# Single tester pass — package everything safe (no kernel/display PR ports).
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8550-allinone-ota.log}"
PRIMARY="$PROJECT_DIR/output/sm8550"
IMG_DIR="$PRIMARY/images/batocera/images/sm8550"
KEYS="$PROJECT_DIR/package/batocera/emulationstation/batocera-emulationstation/keys.txt"
DIRECT_BUILD=
PARALLEL_BUILD=
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
mkdir -p "$PRIMARY" "$PRIMARY/tmp"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
: >"$LOG_FILE"
rm -f "$PROJECT_DIR/rebuild-sm8550-allinone-ota.DONE" \
      "$PROJECT_DIR/rebuild-sm8550-allinone-ota.FAILED"

run_pkg() {
  local pkg="$1" ec
  log ""; log ">>> make sm8550-pkg PKG=$pkg  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8550-pkg PKG="$pkg" DIRECT_BUILD="$DIRECT_BUILD" \
    PARALLEL_BUILD="$PARALLEL_BUILD" BATCH_MODE=1 \
    MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
    >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: $pkg ($ec)"
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8550-allinone-ota.FAILED"
    exit "$ec"
  fi
  log "OK: $pkg"
}

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

log "=== sm8550 all-in-one OTA (ES/SS + configgen + Waydroid + wifi) ==="
log "Date: $(date -Is) PID=$$"

if [ ! -f "$KEYS" ] || ! grep -qE '^SCREENSCRAPER_DEV_LOGIN=devid=.+&devpassword=.+' "$KEYS"; then
  log "FAIL: keys.txt missing/invalid (gitignored; required for Screenscraper)"
  echo "FAILED keys $(date -Is)" >"$PROJECT_DIR/rebuild-sm8550-allinone-ota.FAILED"
  exit 1
fi
log "PASS keys.txt present"

# Force refresh packages that must pick up tree changes
log ">>> wiping ES / configgen / waydroid build dirs"
rm -rf "$PRIMARY"/build/batocera-emulationstation-*
rm -rf "$PRIMARY"/build/batocera-configgen-*
rm -rf "$PRIMARY"/build/waydroid-*

run_pkg batocera-emulationstation-rebuild
run_pkg batocera-configgen-rebuild
run_pkg waydroid-rebuild
run_pkg batocera-system-reinstall

TARGET="$PRIMARY/target"

# Force board wifi overlays into target (belt-and-suspenders)
install -m 0755 \
  "$PROJECT_DIR/board/batocera/qualcomm/sm8550/fsoverlay/usr/bin/sm8550-wifi-resilience" \
  "$TARGET/usr/bin/sm8550-wifi-resilience"
install -m 0755 \
  "$PROJECT_DIR/board/batocera/qualcomm/sm8550/fsoverlay/etc/init.d/S09sm8550-wifi-resilience" \
  "$TARGET/etc/init.d/S09sm8550-wifi-resilience"

ES_BIN="$TARGET/usr/bin/emulationstation"
fail=0
if [ ! -x "$ES_BIN" ] || ! grep -aFq 'devid=' "$ES_BIN" || ! grep -aFq 'jeuInfos.php' "$ES_BIN"; then
  log "FAIL: ES missing Screenscraper"
  fail=1
else
  log "PASS ES Screenscraper"
fi

AES=$(ls "$TARGET"/usr/lib/python*/site-packages/configgen/generators/aethersx2/aethersx2Generator.py 2>/dev/null | head -1 || true)
RPC=$(ls "$TARGET"/usr/lib/python*/site-packages/configgen/generators/rpcs3/rpcs3Paths.py 2>/dev/null | head -1 || true)
if [ -n "$AES" ] && grep -q 'get_str("aethersx2_renderer"' "$AES"; then
  log "PASS aethersx2 get_str"
else
  log "FAIL aethersx2 get_str"; fail=1
fi
if [ -n "$RPC" ] && grep -q 'RPCS3_PATCH_YML' "$RPC"; then
  log "PASS rpcs3 PATCH_YML"
else
  log "FAIL rpcs3 PATCH_YML"; fail=1
fi

if [ -x "$TARGET/usr/bin/waydroid" ] || [ -f "$TARGET/usr/lib/waydroid/data/scripts/waydroid.py" ] || \
   ls "$TARGET"/usr/lib/waydroid* >/dev/null 2>&1; then
  # version string often in waydroid package data
  if grep -Rqs '1\.6\.3' "$TARGET/usr/lib/waydroid" "$TARGET/usr/share/waydroid" 2>/dev/null \
     || grep -aqs '1.6.3' "$TARGET/usr/bin/waydroid" 2>/dev/null; then
    log "PASS waydroid 1.6.3 marker"
  else
    log "WARN waydroid installed but 1.6.3 string not grepped (ok if layout differs)"
  fi
else
  log "FAIL waydroid missing from target"; fail=1
fi

if grep -q 'dead-air' "$TARGET/etc/init.d/S09sm8550-wifi-resilience" \
   && grep -q 'COUNTRY_STAMP' "$TARGET/usr/bin/sm8550-wifi-resilience"; then
  log "PASS wifi dead-air + country stamp"
else
  log "FAIL wifi overlays"; fail=1
fi

[ "$fail" -eq 0 ] || {
  echo "FAILED prechecks $(date -Is)" >"$PROJECT_DIR/rebuild-sm8550-allinone-ota.FAILED"
  exit 1
}

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
log "DONE — next: split-release + publish v44-sm8550-YYYYMMDD"
