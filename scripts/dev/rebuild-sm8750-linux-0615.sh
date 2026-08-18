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
# SKIP_LINUX=1 SKIP_GOBJECT=1 resumes after a kernel/cairo success without wiping the log.
if [ "${SKIP_LINUX:-0}" != 1 ] || [ "${SKIP_GOBJECT:-0}" != 1 ]; then
  : >"$LOG_FILE"
fi
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

MAC="$PRIMARY/build/linux-7.1.4/drivers/net/wireless/ath/ath12k/mac.c"
WMI="$PRIMARY/build/linux-7.1.4/drivers/net/wireless/ath/ath12k/wmi.c"
KCFG="$PRIMARY/build/linux-7.1.4/.config"

if [ "${SKIP_LINUX:-0}" = 1 ]; then
  log "SKIP_LINUX=1: reuse existing linux build"
else
  run_cmd linux-dirclean
  log "next: PKG=linux (defconfig + show-build-order can stay quiet for several minutes)"
  run_pkg linux
fi

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
# lutris/desktopapps stamps can be "already installed" while target still has
# the old 0.5.20 tree and the 397-byte launcher stub — always dirclean them.
if [ "${SKIP_GOBJECT:-0}" = 1 ]; then
  log "SKIP_GOBJECT=1: reuse existing python-gobject"
else
  run_cmd python-gobject-dirclean
  run_pkg python-gobject
fi
if ! ls "$PRIMARY"/target/usr/lib/python*/site-packages/gi/_gi_cairo*.so >/dev/null 2>&1; then
  log "FAILED: gi._gi_cairo missing after python-gobject"
  echo "FAILED gi._gi_cairo missing $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
log "gi._gi_cairo present"
run_cmd lutris-dirclean
run_pkg lutris
if ! grep -q '_pixbuf_as_cairo_surface' \
     "$PRIMARY"/target/usr/lib/python*/site-packages/lutris/gui/widgets/utils.py; then
  log "FAILED: lutris cairo pixbuf patch missing in target"
  echo "FAILED lutris-cairo-patch $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
log "lutris cairo/EGS patches present"
run_cmd batocera-desktopapps-dirclean
run_pkg batocera-desktopapps
if ! grep -q 'timeout 2 sh -c "echo resume' \
     "$PRIMARY/target/usr/bin/batocera-config-lutris"; then
  log "FAILED: batocera-config-lutris resume timeout missing"
  echo "FAILED lutris-launcher $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
log "Lutris launcher + cairo present"

# PS2 flexible BIOS + RPCS3 generator paths + mouse-mode M2 + OLED care.
run_cmd batocera-configgen-dirclean
run_pkg batocera-configgen
if ! grep -q 'RPCS3_SHARE_PATCH' \
     "$PRIMARY"/target/usr/lib/python*/site-packages/configgen/generators/rpcs3/rpcs3Paths.py; then
  log "FAILED: rpcs3Paths.py missing RPCS3_SHARE_PATCH"
  echo "FAILED rpcs3-paths $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
run_cmd batocera-scripts-dirclean
run_pkg batocera-scripts
if ! grep -q 'anyFile' "$PRIMARY/target/usr/bin/batocera-systems"; then
  log "FAILED: batocera-systems still has strict PS2 BIOS MD5"
  echo "FAILED ps2-bios-check $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
if ! grep -q 'PADDLE_M2' "$PRIMARY/target/usr/bin/batocera-mouse-mode"; then
  log "FAILED: batocera-mouse-mode missing M2 toggle"
  echo "FAILED mouse-m2 $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
if [ ! -x "$PRIMARY/target/usr/bin/batocera-oled-care" ] \
   || [ ! -x "$PRIMARY/target/etc/init.d/S33oledcare" ]; then
  log "FAILED: OLED care binaries/init missing"
  echo "FAILED oled-care $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
log "PS2/PS3 configgen+scripts, M2 mouse toggle, OLED care present"

# Short version string, splash subtitle, pocket logo, OSK exclusive-zone=0.
run_cmd batocera-system-dirclean
run_pkg batocera-system
if ! grep -q '^44-pocket ' "$PRIMARY/target/usr/share/batocera/batocera.version"; then
  log "FAILED: batocera.version is not the short 44-pocket prefix"
  echo "FAILED version-prefix $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
if grep -q 'golden-rabbit\|-dev-pocket' "$PRIMARY/target/usr/share/batocera/batocera.version"; then
  log "FAILED: batocera.version still has the long golden-rabbit/dev string"
  echo "FAILED version-long $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
run_cmd batocera-splash-dirclean
run_pkg batocera-splash
run_pkg batocera-splash-odin3
if ! grep -q '44-pocket' "$PRIMARY/target/usr/share/batocera/splash/splash.srt"; then
  log "FAILED: splash.srt missing short version"
  echo "FAILED splash-srt $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
run_cmd batocera-onscreen-keyboard-dirclean
run_pkg batocera-onscreen-keyboard
if ! grep -q 'discord_running' "$PRIMARY/target/usr/bin/onscreen-keyboard"; then
  log "FAILED: onscreen-keyboard still shifts all windows"
  echo "FAILED osk-shift $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
if ! grep -q 'set_exclusive_zone(layer_surface, 0)' \
     "$PRIMARY/build/batocera-onscreen-keyboard-v0.17/main.c"; then
  log "FAILED: wvkbd exclusive_zone is not 0"
  echo "FAILED osk-exclusive $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
SWAY_SRC="$PROJECT_DIR/package/batocera/emulationstation/batocera-emulationstation/wayland/sway"
install -m 0755 "$SWAY_SRC/config" "$PRIMARY/target/etc/sway/config"
install -m 0644 "$SWAY_SRC/batocera.pocket-logo.png" \
  "$PRIMARY/target/usr/share/batocera/splash/batocera.pocket-logo.png"
if ! grep -q 'batocera.pocket-logo.png' "$PRIMARY/target/etc/sway/config"; then
  log "FAILED: sway config missing pocket logo"
  echo "FAILED sway-logo $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
log "short version + splash.srt + pocket logo + OSK Discord-only shift present"

# Pokemon Recomp in ES (own theme, not gb) + Steam env strip / Proton skip.
run_cmd batocera-es-system-dirclean
run_pkg batocera-es-system
if ! grep -q '<theme>pkmnrecomp</theme>' \
     "$PRIMARY/target/usr/share/emulationstation/es_systems.cfg"; then
  log "FAILED: es_systems.cfg missing theme pkmnrecomp"
  echo "FAILED es-pkmnrecomp-theme $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
run_cmd pkmnrecomp-dirclean
run_pkg pkmnrecomp
if [ ! -f "$PRIMARY/target/usr/share/pkmnrecomp/theme/logo-pokeball.png" ]; then
  log "FAILED: pkmnrecomp pokeball logo missing"
  echo "FAILED pkmnrecomp-logo $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
run_cmd batocera-steam-aarch64-dirclean
run_pkg batocera-steam-aarch64
if ! grep -q '-u LD_LIBRARY_PATH' "$PRIMARY/target/usr/bin/steam-direct-session.sh"; then
  log "FAILED: steam-direct-session.sh missing LD_LIBRARY_PATH unset"
  echo "FAILED steam-env $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
if ! grep -q 'proton_tip_already_installed' "$PRIMARY/target/usr/bin/batocera-steam"; then
  log "FAILED: batocera-steam missing proton tip skip"
  echo "FAILED steam-proton-tip $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.FAILED"
  exit 1
fi
log "pkmnrecomp ES theme + pokeball art + Steam env/proton skip present"

echo "DONE $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-linux-0615.DONE"
log "=== DONE $(date -Is) ==="
log "Kernel + Lutris + PS2/PS3/scripts + version/splash/OSK/logo rebuilt. No OTA packed. USB gadget unchanged."
