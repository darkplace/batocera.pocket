#!/usr/bin/env bash
# Kernel + Lutris sm8750 rebuild:
#   0615 skip fully-passive multi-band scan (crash)
#   0616 split scan into 8-channel chunks (missing APs)
#   0617 send computed scan_priority (11d starvation)
#   defconfig CFG80211_CERTIFICATION_ONUS (real country / active 5 GHz)
#   python-gobject cairo foreign + lutris + batocera-config-lutris
# Does NOT touch ES, USB gadget, ConnMan, iwd, or NetworkManager.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-linux-0615.log}"
PRIMARY="$PROJECT_DIR/output/sm8750"
DIRECT_BUILD=
PARALLEL_BUILD=
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
mkdir -p "$PRIMARY" "$PRIMARY/tmp"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
: >"$LOG_FILE"
rm -f "$PROJECT_DIR/rebuild-sm8750-linux-0615.DONE" \
      "$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"

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
    log "FAILED: $cmd ($ec)"
    echo "FAILED $cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
    exit "$ec"
  fi
  log "OK: $cmd"
}

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
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
    exit "$ec"
  fi
  log "OK: $pkg"
}

log "=== sm8750 linux ath12k wifi 0615/0616/0617 + ONUS + Lutris cairo ($(date -Is)) ==="
log "Hands-off: USB gadget, ES Network Settings, ConnMan, NM/iwd."
run_cmd linux-dirclean
run_pkg linux

MAC="$PRIMARY/build/linux-7.1.4/drivers/net/wireless/ath/ath12k/mac.c"
WMI="$PRIMARY/build/linux-7.1.4/drivers/net/wireless/ath/ath12k/wmi.c"
KCFG="$PRIMARY/build/linux-7.1.4/.config"
fail=0
if ! grep -q 'ath12k_mac_scan_start_chunk' "$MAC"; then
  log "FAILED: 0616 symbol missing in mac.c"
  fail=1
fi
if ! grep -q 'ath12k_mac_scan_chunk_multiband' "$MAC"; then
  log "FAILED: 0615/0616 multiband helper missing in mac.c"
  fail=1
fi
if ! grep -q 'cmd->scan_priority = cpu_to_le32(arg->scan_priority)' "$WMI"; then
  log "FAILED: 0617 scan_priority assignment missing in wmi.c"
  fail=1
fi
if ! grep -q '^CONFIG_CFG80211_CERTIFICATION_ONUS=y' "$KCFG"; then
  log "FAILED: CONFIG_CFG80211_CERTIFICATION_ONUS not set in kernel .config"
  fail=1
fi
if [ "$fail" -ne 0 ]; then
  echo "FAILED wifi-patch-verify $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
log "0615/0616/0617 + CERTIFICATION_ONUS present"

# Lutris covers: force python-gobject cairo foreign, then lutris + launcher.
run_cmd python-gobject-dirclean
run_pkg python-gobject
if ! ls "$PRIMARY"/target/usr/lib/python*/site-packages/gi/_gi_cairo*.so >/dev/null 2>&1; then
  log "FAILED: gi._gi_cairo missing after python-gobject"
  echo "FAILED gi._gi_cairo missing $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
log "gi._gi_cairo present"
run_pkg lutris
run_pkg batocera-desktopapps
if ! grep -q 'timeout 2 sh -c "echo resume' \
     "$PRIMARY/target/usr/bin/batocera-config-lutris"; then
  log "FAILED: batocera-config-lutris resume timeout missing"
  echo "FAILED lutris-launcher $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
log "Lutris launcher + cairo present"

echo "DONE $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.DONE"
log "=== DONE $(date -Is) ==="
log "Kernel + Lutris packages rebuilt. No OTA packed. USB gadget unchanged."
