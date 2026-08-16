#!/usr/bin/env bash
# Full sm8750 OTA with all pending fixes:
#   OSK @, Steam QAM/Back, ES screensaver dim,
#   xenia-edge XenDroid FIFO + SPIR-V bits, xbox360 default → xenia-edge,
#   ports Box64↔FEX translator (+ Tools launcher icon/desc),
#   Proton Experimental x86 tip (Rockstar / FEX+SLR) + ★ Recommended tip dirs
#   (proton_cachyos_arm64 / proton_ge_arm64) in batocera-steam 1.5 + wine-tools.
# Does NOT upload to GitHub. After DONE, apply via tunnel:
#   HOST=root@127.0.0.1 SSH_PORT=22199 ./scripts/dev/apply-sm8750-ota.sh
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.log}"
PRIMARY="$PROJECT_DIR/output/sm8750"
IMG_DIR="$PRIMARY/images/batocera/images/sm8750"
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
mkdir -p "$PRIMARY" "$PRIMARY/tmp"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
: >"$LOG_FILE"
rm -f "$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.DONE" \
      "$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.FAILED"

run_pkg() {
  local pkg="$1" ec
  log ""; log ">>> make sm8750-pkg PKG=$pkg  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8750-pkg PKG="$pkg" BATCH_MODE=1 \
    MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
    >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: $pkg ($ec)"
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.FAILED"
    exit "$ec"
  fi
  log "OK: $pkg"
}

run_cmd() {
  local cmd="$1" ec
  log ""; log ">>> make sm8750-build CMD=$cmd  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8750-build CMD="$cmd" BATCH_MODE=1 \
    MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
    >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: CMD=$cmd ($ec)"
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

log "=== sm8750 FULL FIXES OTA (OSK+QAM+SS+xenia+ports+proton-experimental) ==="
log "Date: $(date -Is) PID=$$"

need=(
  package/batocera/utils/batocera-onscreen-keyboard/004-fix-special-symbols-emit-shift.patch
  package/batocera/utils/batocera-steam/batocera-steam-qam
  package/batocera/utils/batocera-steam/batocera-steam-back-qam
  package/batocera/emulationstation/batocera-emulationstation/0016-fix-screensaver-dim-fullscreen.patch
  package/batocera/emulators/xenia-edge/0014-posix-semaphore-fifo-acquisition-xendroid.patch
  package/batocera/emulators/xenia-edge/0015-spirv-multiply-zero-test-on-bits-xendroid.patch
  package/batocera/core/batocera-scripts/scripts/batocera-ports-translator
  package/batocera/emulationstation/batocera-es-system/roms/emulator/Ports_X86_Translator.sh
  package/batocera/emulationstation/batocera-es-system/roms/emulator/images/windows-translator.png
)
for f in "${need[@]}"; do
  [ -f "$PROJECT_DIR/$f" ] || { log "FAIL missing $f"; echo "FAILED missing $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.FAILED"; exit 1; }
done
grep -q 'proton_cachyos_arm64' \
  "$PROJECT_DIR/package/batocera/utils/batocera-steam-aarch64/batocera-steam" \
  || { log "FAIL missing proton_cachyos_arm64 promote in batocera-steam"; exit 1; }
grep -q 'proton_experimental_x86' \
  "$PROJECT_DIR/package/batocera/utils/batocera-steam-aarch64/batocera-steam" \
  || { log "FAIL missing proton_experimental_x86 in batocera-steam"; exit 1; }
grep -q 'xenia-edge' \
  "$PROJECT_DIR/package/batocera/core/batocera-configgen/configs/configgen-defaults-sm8750.yml" \
  || { log "FAIL xbox360 default not xenia-edge"; exit 1; }

# Packages
run_pkg batocera-emulationstation
run_pkg batocera-onscreen-keyboard
run_pkg hotkeygen

# Force steam 1.4 + wine-tools refresh
set +e
stdbuf -oL -eL make sm8750-pkg PKG=batocera-steam-aarch64-dirclean BATCH_MODE=1 \
  MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" >>"$LOG_FILE" 2>&1
set -e
run_pkg batocera-steam-aarch64

set +e
stdbuf -oL -eL make sm8750-pkg PKG=batocera-wine-dirclean BATCH_MODE=1 \
  MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" >>"$LOG_FILE" 2>&1
set -e
run_pkg batocera-wine

run_pkg batocera-configgen
run_pkg batocera-scripts
# es-system only copies template roms when @D/roms/<sys> is missing — wipe Tools folder so new launchers land
rm -rf "$PRIMARY"/build/batocera-es-system-*/roms/emulator
set +e
stdbuf -oL -eL make sm8750-pkg PKG=batocera-es-system-dirclean BATCH_MODE=1 \
  MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" >>"$LOG_FILE" 2>&1
set -e
run_pkg batocera-es-system
# Ensure Tools launcher survived hooks that re-patch gamelist.xml
if [ ! -f "$PRIMARY/target/usr/share/batocera/datainit/roms/emulator/Ports_X86_Translator.sh" ]; then
  log "injecting Ports_X86_Translator into datainit (es-system copy skipped stale tree)"
  install -m 0755 \
    "$PROJECT_DIR/package/batocera/emulationstation/batocera-es-system/roms/emulator/Ports_X86_Translator.sh" \
    "$PRIMARY/target/usr/share/batocera/datainit/roms/emulator/"
  install -m 0644 \
    "$PROJECT_DIR/package/batocera/emulationstation/batocera-es-system/roms/emulator/Ports_X86_Translator.sh.keys" \
    "$PRIMARY/target/usr/share/batocera/datainit/roms/emulator/"
  install -m 0644 \
    "$PROJECT_DIR/package/batocera/emulationstation/batocera-es-system/roms/emulator/images/windows-translator.png" \
    "$PRIMARY/target/usr/share/batocera/datainit/roms/emulator/images/"
  install -m 0644 \
    "$PROJECT_DIR/package/batocera/emulationstation/batocera-es-system/roms/emulator/gamelist.xml" \
    "$PRIMARY/target/usr/share/batocera/datainit/roms/emulator/gamelist.xml"
fi

# xenia-edge: rebuild if missing, else reinstall into target
if [ ! -x "$PRIMARY/target/usr/xenia_edge/xenia_edge" ]; then
  set +e
  stdbuf -oL -eL make sm8750-pkg PKG=xenia-edge-dirclean BATCH_MODE=1 \
    MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" >>"$LOG_FILE" 2>&1
  set -e
  run_pkg xenia-edge
else
  log "xenia-edge binary present in target — reinstall only"
  set +e
  stdbuf -oL -eL make sm8750-pkg PKG=xenia-edge-reinstall BATCH_MODE=1 \
    MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    run_pkg xenia-edge
  else
    log "OK: xenia-edge-reinstall"
  fi
fi

XENIA="$PRIMARY/target/usr/xenia_edge/xenia_edge"
STRIP=$(ls "$PRIMARY"/host/bin/aarch64-*-strip 2>/dev/null | head -1 || true)
if [ -x "$XENIA" ] && [ -n "$STRIP" ]; then
  SZ=$(stat -c%s "$XENIA")
  if [ "$SZ" -gt 80000000 ]; then
    log "stripping xenia_edge ($SZ bytes) for squashfs size"
    "$STRIP" --strip-unneeded "$XENIA" || "$STRIP" "$XENIA" || true
    log "stripped size=$(stat -c%s "$XENIA")"
  fi
fi

# Sanity
[ -x "$PRIMARY/target/usr/bin/batocera-steam-qam" ] || { log "FAIL qam"; echo "FAILED qam $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.FAILED"; exit 1; }
[ -x "$PRIMARY/target/usr/bin/batocera-steam-back-qam" ] || { log "FAIL back-qam"; echo "FAILED back $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.FAILED"; exit 1; }
[ -x "$PRIMARY/target/usr/bin/batocera-ports-translator" ] || { log "FAIL ports-translator"; echo "FAILED ports-translator $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.FAILED"; exit 1; }
[ -f "$PRIMARY/target/usr/share/batocera/datainit/roms/emulator/Ports_X86_Translator.sh" ] \
  || { log "FAIL Ports_X86_Translator.sh"; echo "FAILED ports launcher $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.FAILED"; exit 1; }
[ -f "$PRIMARY/target/usr/share/batocera/datainit/roms/emulator/images/windows-translator.png" ] \
  || { log "FAIL windows-translator.png"; echo "FAILED ports icon $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.FAILED"; exit 1; }
[ -x "$XENIA" ] || { log "FAIL xenia"; echo "FAILED xenia $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.FAILED"; exit 1; }
grep -q 'OnQuickAccessButtonPressed' "$PRIMARY/target/usr/bin/batocera-steam-qam"
grep -q 'proton_cachyos_arm64\|PROTON_CACHYOS_STEAM_DIR' "$PRIMARY/target/usr/bin/batocera-steam" \
  || { log "FAIL batocera-steam missing proton_cachyos_arm64"; exit 1; }
grep -q 'proton_experimental_x86' "$PRIMARY/target/usr/bin/batocera-steam" \
  || { log "FAIL batocera-steam missing proton_experimental_x86"; exit 1; }
grep -q 'ports_translator' "$PRIMARY/target/usr/share/emulationstation/es_features.cfg" \
  || { log "FAIL es_features missing ports_translator"; exit 1; }
grep -q 'Ports_X86_Translator' "$PRIMARY/target/usr/share/batocera/datainit/roms/emulator/gamelist.xml" \
  || { log "FAIL gamelist missing Ports_X86_Translator"; exit 1; }
log "PASS target checks"

set +e
stdbuf -oL -eL make sm8750-pkg PKG=batocera-system-reinstall BATCH_MODE=1 \
  MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" >>"$LOG_FILE" 2>&1
ec=$?
set -e
if [ "$ec" -ne 0 ]; then
  run_pkg batocera-system
else
  log "OK: batocera-system-reinstall"
fi
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

echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.DONE"
log "DONE — apply: HOST=root@127.0.0.1 SSH_PORT=22199 ./scripts/dev/apply-sm8750-ota.sh && reboot"
