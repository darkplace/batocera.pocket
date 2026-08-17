#!/usr/bin/env bash
# Rebuild sm8750 OTA: OSK @ fix, Steam QAM (Back), ES screensaver dim fullscreen.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.log}"
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
rm -f "$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.DONE" \
      "$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"

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
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"
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
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

log "=== sm8750 OSK + QAM + screensaver OTA ==="
log "Date: $(date -Is) PID=$$"

need=(
  package/batocera/utils/batocera-onscreen-keyboard/004-fix-special-symbols-emit-shift.patch
  package/batocera/utils/batocera-steam/batocera-steam-qam
  package/batocera/utils/batocera-steam/batocera-steam-back-qam
  package/batocera/emulationstation/batocera-emulationstation/0016-fix-screensaver-dim-fullscreen.patch
)
for f in "${need[@]}"; do
  if [ ! -f "$PROJECT_DIR/$f" ]; then
    log "FAIL: missing $f"
    echo "FAILED missing-$f $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"
    exit 1
  fi
done

# Force ES re-extract so 0016 applies.
run_pkg batocera-emulationstation-dirclean || true
run_pkg batocera-emulationstation

# OSK: patches live at package root (Buildroot does not recurse patches/).
run_pkg batocera-onscreen-keyboard-dirclean || true
run_pkg batocera-onscreen-keyboard

run_pkg hotkeygen-reinstall || run_pkg hotkeygen
# Force reinstall: local SITE package skips install when VERSION stamp is unchanged.
run_pkg batocera-steam-aarch64-dirclean || true
run_pkg batocera-steam-aarch64
run_pkg batocera-userdatainit || run_pkg batocera-system || true
run_pkg batocera-system-reinstall || run_pkg batocera-system

OSK_BIN="$PRIMARY/target/usr/libexec/onscreen-keyboard/wvkbd-mobintl"
QAM="$PRIMARY/target/usr/bin/batocera-steam-qam"
BACK="$PRIMARY/target/usr/bin/batocera-steam-back-qam"
ES="$PRIMARY/target/usr/bin/emulationstation"

[ -x "$OSK_BIN" ] || { log "FAIL: missing $OSK_BIN"; echo "FAILED osk-bin $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"; exit 1; }
[ -x "$QAM" ] || { log "FAIL: missing $QAM"; echo "FAILED qam $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"; exit 1; }
[ -x "$BACK" ] || { log "FAIL: missing $BACK"; echo "FAILED back-qam $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"; exit 1; }
[ -x "$ES" ] || { log "FAIL: missing $ES"; echo "FAILED es $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"; exit 1; }

if ! grep -q 'OnQuickAccessButtonPressed' "$QAM"; then
  log "FAIL: batocera-steam-qam missing CEF hook"
  echo "FAILED qam-cef $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"
  exit 1
fi
if ! grep -q 'BTN_BACK' "$BACK"; then
  log "FAIL: batocera-steam-back-qam missing BTN_BACK watch"
  echo "FAILED back-btn $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.FAILED"
  exit 1
fi
log "PASS target binaries present"

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
  unsquashfs -d "$TMP/sq" -f "$SQ" \
    /usr/bin/batocera-steam-qam \
    /usr/bin/batocera-steam-back-qam \
    /usr/libexec/onscreen-keyboard/wvkbd-mobintl \
    /usr/bin/emulationstation >/dev/null
  for p in batocera-steam-qam batocera-steam-back-qam; do
    if [ -x "$TMP/sq/usr/bin/$p" ]; then
      echo "PASS packaged $p"
    else
      echo "FAIL packaged $p"
      rm -rf "$TMP"
      exit 1
    fi
  done
  if [ -x "$TMP/sq/usr/libexec/onscreen-keyboard/wvkbd-mobintl" ]; then
    echo "PASS packaged wvkbd"
  else
    echo "FAIL packaged wvkbd"
    rm -rf "$TMP"
    exit 1
  fi
  rm -rf "$TMP"
} | tee -a "$LOG_FILE"

echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-osk-qam-ss-ota.DONE"
log "DONE — test locally with ./scripts/dev/apply-sm8750-ota.sh (do not upload to GitHub yet)"
