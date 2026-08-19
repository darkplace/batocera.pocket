#!/usr/bin/env bash
# MUST-SHIP proofs for sm8750. Fail closed. Used by pocket-change-memory skill.
# Usage:
#   scripts/dev/verify-sm8750-must-ship.sh target
#   scripts/dev/verify-sm8750-must-ship.sh device
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODE="${1:-}"
HOST="${HOST:-root@10.10.10.115}"
PW="${PW:-linux}"
PRIMARY="${PRIMARY:-$ROOT/output/sm8750}"
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

verify_tree() {
  local t="$1" py
  py=$(ls -d "$t"/usr/lib/python3.12/site-packages 2>/dev/null | head -1)
  [ -n "$py" ] || py=$(ls -d "$t"/usr/lib/python3.*/site-packages 2>/dev/null | tail -1)
  log "=== MUST-SHIP target $t ==="

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
  need_grep "UFS_DEVICE_QUIRK_NO_TIMESTAMP_SUPPORT" \
    "$ROOT/board/batocera/qualcomm/sm8750/linux_patches/0618-scsi-ufs-latch-NO_TIMESTAMP-after-qTimestamp-fail.patch" \
    "UFS 0618 latch NO_TIMESTAMP"
  need_file "$t/etc/init.d/S08ufs-pm" "S08ufs-pm keeps UFS runtime-active"
  need_grep "power/control" "$t/etc/init.d/S08ufs-pm" "S08ufs-pm writes power/control"
  need_grep 'DRIVER=="ufshcd-qcom"' "$t/usr/lib/udev/rules.d/99-ayn-odin3.rules" "udev keeps ufshcd-qcom runtime-active"

  need_grep "anyFile" "$t/usr/bin/batocera-systems" "PS2 anyFile BIOS check"
  need_grep "RPCS3_SHARE_PATCH" "$py/configgen/generators/rpcs3/rpcs3Paths.py" "PS3 RPCS3_SHARE_PATCH"
  need_grep "_strip_steam_runtime_env" "$ROOT/package/batocera/core/batocera-configgen/configgen/configgen/emulatorlauncher.py" "configgen strips Steam runtime env"
  need_grep "-u LD_LIBRARY_PATH" "$ROOT/package/batocera/utils/batocera-steam/steam-direct-session.sh" "ES restore unsets Steam LD_LIBRARY_PATH"
  need_grep "PADDLE_M2" "$t/usr/bin/batocera-mouse-mode" "M2 paddle symbol"
  need_grep "self.toggle()" "$t/usr/bin/batocera-mouse-mode" "M2 calls toggle"
  need_file "$t/usr/bin/batocera-oled-care" "OLED care"
  need_grep "start_idle_helper || true" "$ROOT/package/batocera/core/batocera-scripts/scripts/batocera-oled-care" "OLED watch respawns idle helper"
  need_file "$t/etc/init.d/S33oledcare" "S33oledcare"
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
  need_grep "shadps4_resolution: 1280x720" \
    "$t/usr/share/batocera/configgen/configgen-defaults-arch.yml" "shadPS4 720p default"
  if ls "$t"/usr/lib/python*/site-packages/gi/_gi_cairo*.so >/dev/null 2>&1; then
    pass "gi._gi_cairo"
  else
    fail "gi._gi_cairo missing"
  fi
}

verify_device() {
  log "=== MUST-SHIP device $HOST ==="
  sshpass -p "$PW" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=12 "$HOST" 'bash -s' <<'REMOTE'
set +e
failn=0
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; failn=$((failn+1)); }
need_file() { [ -e "$1" ] && pass "$2" || fail "$2"; }
need_grep() { [ -f "$2" ] && grep -q -- "$1" "$2" && pass "$3" || fail "$3"; }

BASE=/overlay/base
need_file /usr/bin/pkmnrecomp "live pkmnrecomp wrapper"
need_file /usr/share/pkmnrecomp/gen1recomp.AppImage "live gen1 AppImage"
need_file /usr/share/pkmnrecomp/gen2recomp.AppImage "live gen2 AppImage"
need_grep pkmnrecomp /usr/share/emulationstation/es_systems.cfg "live ES pkmnrecomp"
need_grep "<theme>pkmnrecomp</theme>" /usr/share/emulationstation/es_systems.cfg "live ES theme pkmnrecomp"
need_grep pkmnrecomp "$BASE/usr/share/emulationstation/es_systems.cfg" "squashfs ES pkmnrecomp"
need_grep "<theme>pkmnrecomp</theme>" "$BASE/usr/share/emulationstation/es_systems.cfg" "squashfs ES theme pkmnrecomp"
need_file /usr/share/pkmnrecomp/theme/logo-pokeball.png "live pokeball logo"
need_file "$BASE/usr/share/pkmnrecomp/theme/logo-pokeball.png" "squashfs pokeball logo"
need_grep anyFile /usr/bin/batocera-systems "live PS2 anyFile"
need_grep anyFile "$BASE/usr/bin/batocera-systems" "squashfs PS2 anyFile"
python3 - <<'PY' || fail "RPCS3_SHARE_PATCH import"
from configgen.generators.rpcs3.rpcs3Paths import RPCS3_SHARE_PATCH
from configgen.emulatorlauncher import get_generator
assert RPCS3_SHARE_PATCH
g = get_generator("rpcs3")
print("PASS: RPCS3_SHARE_PATCH", RPCS3_SHARE_PATCH, type(g).__name__)
PY
need_grep _strip_steam_runtime_env /usr/lib/python3.12/site-packages/configgen/emulatorlauncher.py "live Steam env strip"
need_grep "-u LD_LIBRARY_PATH" /usr/bin/steam-direct-session.sh "live ES restore unsets Steam libs"
need_grep PADDLE_M2 /usr/bin/batocera-mouse-mode "live M2"
need_file /usr/bin/batocera-oled-care "live OLED care"
need_grep "start_idle_helper || true" /usr/bin/batocera-oled-care "live OLED helper respawn"
need_grep "^44-pocket " /usr/share/batocera/batocera.version "live short version"
need_grep discord_running /usr/bin/onscreen-keyboard "live OSK discord_running"
need_file /usr/xenia_edge/xenia_edge "live xenia-edge payload"
need_file "$BASE/etc/init.d/S08ufs-pm" "squashfs S08ufs-pm"
need_file /etc/init.d/S08ufs-pm "live S08ufs-pm"
need_grep 'DRIVER=="ufshcd-qcom"' /usr/lib/udev/rules.d/99-ayn-odin3.rules "live UFS udev keeps host active"
need_grep 'DRIVER=="ufshcd-qcom"' "$BASE/usr/lib/udev/rules.d/99-ayn-odin3.rules" "squashfs UFS udev"
ufsctl=$(cat /sys/bus/platform/devices/1d84000.ufs/power/control 2>/dev/null || true)
if [ "$ufsctl" = on ]; then
  pass "UFS power/control=on"
else
  fail "UFS power/control is '${ufsctl:-missing}' (want on)"
fi

# overlays must not still install old PS2/PS3
if grep -q 'es-resume-fix/configgen/rpcs3Paths.py' /userdata/system/services/custom_service 2>/dev/null; then
  fail "custom_service still overlays old rpcs3Paths"
else
  pass "custom_service does not overlay old rpcs3Paths"
fi
if grep -q 'apps-hotfix/batocera-systems' /userdata/system/custom.sh 2>/dev/null; then
  fail "custom.sh still overlays batocera-systems"
else
  pass "custom.sh does not overlay batocera-systems"
fi
svc=$(batocera-settings-get system.services 2>/dev/null || true)
case " $svc " in
  *" wave2scripts "*) fail "wave2scripts still enabled (clobbers batocera-systems)" ;;
  *) pass "wave2scripts not in system.services" ;;
esac
if [ -e /userdata/system/upgrade/hotpatch/batocera.version ] || [ -e /userdata/system/upgrade/hotpatch/splash.srt ]; then
  fail "hotpatch still has batocera.version or splash.srt"
else
  pass "hotpatch has no version/srt clobber"
fi
exit "$failn"
REMOTE
}

case "$MODE" in
  target)
    verify_tree "$PRIMARY/target"
    wmi="$PRIMARY/build/linux-7.1.4/drivers/net/wireless/ath/ath12k/wmi.c"
    mac="$PRIMARY/build/linux-7.1.4/drivers/net/wireless/ath/ath12k/mac.c"
    kcfg="$PRIMARY/build/linux-7.1.4/.config"
    need_grep "ath12k_mac_scan_start_chunk" "$mac" "wifi 0616 chunk"
    need_grep "ath12k_mac_scan_chunk_multiband" "$mac" "wifi 0615/0616 multiband"
    need_grep "cmd->scan_priority = cpu_to_le32(arg->scan_priority)" "$wmi" "wifi 0617 scan_priority"
    need_grep "^CONFIG_CFG80211_CERTIFICATION_ONUS=y" "$kcfg" "CERTIFICATION_ONUS"
    ufshcd="$PRIMARY/build/linux-7.1.4/drivers/ufs/core/ufshcd.c"
    need_grep "Some UFS 4.0 devices advertise wspecversion >= 0x400 but" \
      "$ufshcd" "UFS 0618 latch in ufshcd.c"
    oskc="$PRIMARY/build/batocera-onscreen-keyboard-v0.17/main.c"
    need_grep "set_exclusive_zone(layer_surface, 0)" "$oskc" "wvkbd exclusive_zone 0"
    ;;
  device)
    verify_device
    exit $?
    ;;
  *)
    echo "usage: $0 target|device" >&2
    exit 2
    ;;
esac

if [ "$failn" -ne 0 ]; then
  log "=== $failn MUST-SHIP check(s) failed ==="
  exit 1
fi
log "=== MUST-SHIP OK ==="
exit 0
