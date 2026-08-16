#!/usr/bin/env bash
# Resume after Ports_X86_Translator sanity fail: files already injected in target.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.log}"
PRIMARY="$PROJECT_DIR/output/sm8750"
IMG_DIR="$PRIMARY/images/batocera/images/sm8750"
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
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

log ""
log "=== RESUME packaging after Ports_X86 inject ($(date -Is)) ==="

# es_features.cfg is only regenerated on BUILD, not reinstall. Force rebuild if ports_translator missing.
CFG="$PRIMARY/target/usr/share/emulationstation/es_features.cfg"
if ! grep -q 'ports_translator\|PORTS TRANSLATOR' "$CFG" 2>/dev/null; then
  log "ports_translator missing from es_features.cfg — forcing batocera-es-system rebuild"
  rm -f "$PRIMARY/build/batocera-es-system-"*/.stamp_built \
        "$PRIMARY/build/batocera-es-system-"*/.stamp_installed \
        "$PRIMARY/build/batocera-es-system-"*/.stamp_target_installed
  rm -rf "$PRIMARY/build/batocera-es-system-"*/roms/emulator
  run_pkg batocera-es-system
fi
# batocera-es-system rebuild if needed

# Re-assert inject (in case something wiped it)
SRC="$PROJECT_DIR/package/batocera/emulationstation/batocera-es-system/roms/emulator"
DST="$PRIMARY/target/usr/share/batocera/datainit/roms/emulator"
mkdir -p "$DST/images"
install -m 0755 "$SRC/Ports_X86_Translator.sh" "$DST/"
install -m 0644 "$SRC/Ports_X86_Translator.sh.keys" "$DST/"
install -m 0644 "$SRC/images/windows-translator.png" "$DST/images/"
# Merge gamelist entry if missing (don't clobber Wine/Steam Tools hooks wholesale if present)
if ! grep -q 'Ports_X86_Translator' "$DST/gamelist.xml" 2>/dev/null; then
  install -m 0644 "$SRC/gamelist.xml" "$DST/gamelist.xml"
fi

XENIA="$PRIMARY/target/usr/xenia_edge/xenia_edge"
[ -x "$PRIMARY/target/usr/bin/batocera-steam-qam" ]
[ -x "$PRIMARY/target/usr/bin/batocera-steam-back-qam" ]
[ -x "$PRIMARY/target/usr/bin/batocera-ports-translator" ]
[ -f "$DST/Ports_X86_Translator.sh" ]
[ -f "$DST/images/windows-translator.png" ]
[ -x "$XENIA" ]
grep -q 'OnQuickAccessButtonPressed' "$PRIMARY/target/usr/bin/batocera-steam-qam"
grep -q 'proton_experimental_x86' "$PRIMARY/target/usr/bin/batocera-steam"
grep -qE 'ports_translator|PORTS TRANSLATOR|value="ports_translator"' "$PRIMARY/target/usr/share/emulationstation/es_features.cfg"
grep -q 'Ports_X86_Translator' "$DST/gamelist.xml"
log "PASS target checks (resume)"

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
