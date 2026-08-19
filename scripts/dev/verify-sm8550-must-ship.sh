#!/usr/bin/env bash
# MUST-SHIP proofs for sm8550 (shared pocket parity with sm8750, minus board-specific).
# Usage:
#   scripts/dev/verify-sm8550-must-ship.sh target
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODE="${1:-}"
PRIMARY="${PRIMARY:-$ROOT/output/sm8550}"
failn=0

log() { printf '%s\n' "$*"; }
fail() { log "FAIL: $*"; failn=$((failn + 1)); }
pass() { log "PASS: $*"; }

need_file() {
  local f="$1" msg="$2"
  if [ -e "$f" ]; then pass "$msg"; else fail "$msg (missing $f)"; fi
}
need_grep() {
  local pat="$1" f="$2" msg="$3"
  if [ -f "$f" ] && grep -q -- "$pat" "$f"; then pass "$msg"; else fail "$msg ($pat in $f)"; fi
}
need_grep_re() {
  local pat="$1" f="$2" msg="$3"
  if [ -f "$f" ] && grep -Eq -- "$pat" "$f"; then pass "$msg"; else fail "$msg ($pat in $f)"; fi
}
need_absent() {
  local f="$1" msg="$2"
  if [ -e "$f" ]; then fail "$msg (still present: $f)"; else pass "$msg"; fi
}

verify_tree() {
  local t="$1" py
  py=$(ls -d "$t"/usr/lib/python3.12/site-packages 2>/dev/null | head -1)
  [ -n "$py" ] || py=$(ls -d "$t"/usr/lib/python3.*/site-packages 2>/dev/null | tail -1)
  log "=== MUST-SHIP sm8550 target $t ==="

  need_file "$t/usr/bin/pkmnrecomp" "pkmnrecomp wrapper"
  need_file "$t/usr/share/pkmnrecomp/gen1recomp.AppImage" "gen1 AppImage"
  need_file "$t/usr/share/pkmnrecomp/gen2recomp.AppImage" "gen2 AppImage"
  need_grep "pkmnrecomp" "$t/usr/share/emulationstation/es_systems.cfg" "ES system pkmnrecomp"
  need_grep "<theme>pkmnrecomp</theme>" "$t/usr/share/emulationstation/es_systems.cfg" "ES theme pkmnrecomp (not gb)"
  need_grep "theme: pkmnrecomp" "$ROOT/package/batocera/emulationstation/batocera-es-system/es_systems.yml" "es_systems.yml theme pkmnrecomp"
  need_grep "pkmnrecomp" "$t/usr/share/emulationstation/es_features.cfg" "ES features pkmnrecomp"
  need_file "$py/configgen/generators/pkmnrecomp/pkmnrecompGenerator.py" "pkmnrecomp generator"
  need_grep "pkmnrecomp" "$py/configgen/generators/importer.py" "configgen importer pkmnrecomp"
  need_file "$t/usr/share/batocera/datainit/roms/emulator/Configure_Gen1Recomp.sh" "Configure Gen1Recomp"
  need_file "$t/usr/share/batocera/datainit/roms/emulator/Configure_Gen2Recomp.sh" "Configure Gen2Recomp"
  need_file "$t/usr/share/pkmnrecomp/theme/logo-pokeball.png" "pkmnrecomp pokeball logo"
  need_file "$t/usr/share/emulationstation/themes/es-theme-carbon/art/logos/pkmnrecomp.png" "carbon pkmnrecomp pokeball"
  need_file "$t/etc/init.d/S32pkmnrecomp-theme" "S32 pkmnrecomp PlayStation-X art"

  need_grep "proton_tip_already_installed" "$t/usr/bin/batocera-steam" "Steam proton tip skip"
  need_grep "proton_experimental_x86" "$t/usr/bin/batocera-steam" "Steam proton experimental x86 tip"
  need_grep "proton_cachyos_arm64\\|PROTON_CACHYOS_STEAM_DIR" "$t/usr/bin/batocera-steam" "Steam proton cachyos tip dirs"
  need_grep "-u LD_LIBRARY_PATH" "$t/usr/bin/steam-direct-session.sh" "ES restore unsets Steam LD_LIBRARY_PATH"
  need_grep "_strip_steam_runtime_env" "$py/configgen/emulatorlauncher.py" "configgen strips Steam runtime env"

  need_grep "anyFile" "$t/usr/bin/batocera-systems" "PS2 anyFile BIOS check"
  need_grep "RPCS3_SHARE_PATCH" "$py/configgen/generators/rpcs3/rpcs3Paths.py" "PS3 RPCS3_SHARE_PATCH"
  need_grep "PADDLE_M2" "$t/usr/bin/batocera-mouse-mode" "M2 paddle symbol"
  need_grep "self.toggle()" "$t/usr/bin/batocera-mouse-mode" "M2 calls toggle"

  need_absent "$t/usr/bin/batocera-oled-care" "OLED care absent on sm8550"
  need_absent "$t/etc/init.d/S33oledcare" "S33oledcare absent on sm8550"

  need_grep_re "^44-pocket " "$t/usr/share/batocera/batocera.version" "short version prefix"
  if grep -Eq "golden-rabbit|-dev-pocket" "$t/usr/share/batocera/batocera.version" 2>/dev/null; then
    fail "version still long/dev hashed"
  else
    pass "version not golden-rabbit/dev-hash"
  fi
  need_grep "44-pocket" "$t/usr/share/batocera/splash/splash.srt" "splash.srt version"
  need_grep "batocera.pocket-logo.png" "$t/etc/sway/config" "sway pocket logo"
  need_grep "discord_running" "$t/usr/bin/onscreen-keyboard" "OSK Discord-only shift"
  need_file "$t/usr/xenia_edge/xenia_edge" "xenia-edge payload"
  need_file "$t/usr/bin/batocera-ports-translator" "ports translator"
  need_grep_re 'ports_translator|PORTS TRANSLATOR' "$t/usr/share/emulationstation/es_features.cfg" "ES features ports_translator"

  if ls "$t"/usr/lib/python*/site-packages/gi/_gi_cairo*.so >/dev/null 2>&1; then
    pass "gi._gi_cairo"
  else
    fail "gi._gi_cairo missing"
  fi
  need_file "$t/usr/bin/lutris" "lutris installed"
  lutris_utils="$(ls "$t"/usr/lib/python*/site-packages/lutris/gui/widgets/utils.py 2>/dev/null | head -1)"
  need_grep "_pixbuf_as_cairo_surface" "${lutris_utils:-/missing}" "lutris cairo pixbuf patch"
  need_file "$t/usr/bin/batocera-config-lutris" "batocera-config-lutris launcher"

  if ls "$ROOT"/board/batocera/qualcomm/sm8550/linux_patches/*ath12k* >/dev/null 2>&1; then
    fail "sm8550 linux_patches must not contain ath12k wifi patches"
  else
    pass "sm8550 linux_patches has no ath12k files"
  fi
  if grep -q '^CONFIG_CFG80211_CERTIFICATION_ONUS=y' \
      "$ROOT/board/batocera/qualcomm/sm8550/linux_sm8550-defconfig.config" 2>/dev/null; then
    fail "sm8550 defconfig must not set CFG80211_CERTIFICATION_ONUS"
  else
    pass "sm8550 defconfig has no CERTIFICATION_ONUS"
  fi
}

case "$MODE" in
  target)
    verify_tree "$PRIMARY/target"
    oskc="$PRIMARY/build/batocera-onscreen-keyboard-v0.17/main.c"
    need_grep "set_exclusive_zone(layer_surface, 0)" "$oskc" "wvkbd exclusive_zone 0"
    ;;
  *)
    echo "usage: $0 target" >&2
    exit 2
    ;;
esac

if [ "$failn" -ne 0 ]; then
  log "=== $failn MUST-SHIP check(s) failed ==="
  exit 1
fi
log "=== MUST-SHIP sm8550 OK ==="
exit 0
