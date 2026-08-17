#!/usr/bin/env bash
# Follow-up: Ports X86 Translator Tools launcher (icon+desc) + helper + OTA package.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-ports-translator-tools.log}"
PRIMARY="$PROJECT_DIR/output/sm8750"
IMG_DIR="$PRIMARY/images/batocera/images/sm8750"
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
mkdir -p "$PRIMARY" "$PRIMARY/tmp"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
: >"$LOG_FILE"
rm -f "$PROJECT_DIR/rebuild-sm8750-ports-translator-tools.DONE" \
      "$PROJECT_DIR/rebuild-sm8750-ports-translator-tools.FAILED"

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
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-ports-translator-tools.FAILED"
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
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-ports-translator-tools.FAILED"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

log "=== ports translator Tools (icon+desc) follow-up ==="
log "Date: $(date -Is) PID=$$"

need=(
  package/batocera/core/batocera-scripts/scripts/batocera-ports-translator
  package/batocera/emulationstation/batocera-es-system/roms/emulator/Ports_X86_Translator.sh
  package/batocera/emulationstation/batocera-es-system/roms/emulator/images/windows-translator.png
)
for f in "${need[@]}"; do
  [ -f "$PROJECT_DIR/$f" ] || { log "FAIL missing $f"; echo "FAILED missing $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-ports-translator-tools.FAILED"; exit 1; }
done

run_pkg batocera-scripts
run_pkg batocera-es-system
run_pkg batocera-configgen

[ -f "$PRIMARY/target/usr/share/batocera/datainit/roms/emulator/Ports_X86_Translator.sh" ]
[ -f "$PRIMARY/target/usr/share/batocera/datainit/roms/emulator/images/windows-translator.png" ]
grep -q 'Ports_X86_Translator' "$PRIMARY/target/usr/share/batocera/datainit/roms/emulator/gamelist.xml"
[ -x "$PRIMARY/target/usr/bin/batocera-ports-translator" ]
grep -q 'ports_translator' "$PRIMARY/target/usr/share/emulationstation/es_features.cfg"
log "PASS target sanity"

set +e
stdbuf -oL -eL make sm8750-pkg PKG=batocera-system-reinstall BATCH_MODE=1 \
  MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" >>"$LOG_FILE" 2>&1
set -e
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

echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-ports-translator-tools.DONE"
echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-full-fixes-ota.DONE"
log "DONE — apply: HOST=root@127.0.0.1 SSH_PORT=22199 ./scripts/dev/apply-sm8750-ota.sh && reboot"
