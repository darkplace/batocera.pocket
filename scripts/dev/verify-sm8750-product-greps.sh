#!/usr/bin/env bash
# verify-sm8750-product-greps.sh — automated product-lock / OTA checks on a tree.
# Usage:
#   ./scripts/dev/verify-sm8750-product-greps.sh              # output/sm8750
#   ./scripts/dev/verify-sm8750-product-greps.sh output/sm8750-arch-backup
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TREE="${1:-$ROOT/output/sm8750}"
TARGET="$TREE/target"
fail=0
pass() { echo "PASS $1"; }
fail_msg() { echo "FAIL $1"; fail=1; }

echo "=== verify $TREE ==="
[ -d "$TARGET" ] || { echo "FAIL no target at $TARGET"; exit 1; }

grep -q 'updates.url=https://github.com/darkplace/batocera.pocket' \
  "$TARGET/usr/share/batocera/datainit/system/batocera.conf" && pass updates.url || fail_msg updates.url

grep -q 'darkplace/batocera.pocket' "$TARGET/usr/bin/batocera-upgrade" && pass upgrade || fail_msg upgrade

[ -x "$TARGET/usr/bin/batocera-pocket-github-release" ] && pass ota_helper || fail_msg ota_helper

if grep -q 'batocera-pocket-github-release' "$TARGET/usr/bin/batocera-upgrade" \
  && ! grep -qE 'api\.github\.com/.*/releases/latest' "$TARGET/usr/bin/batocera-upgrade"; then
  pass ota_per_board
else
  fail_msg ota_per_board
fi

grep -q 'scrub_mobile_shell_config' "$TARGET/usr/bin/batocera-arch-plasma-lxc" && pass plasma_scrub || fail_msg plasma_scrub
grep -q 'is_split_status_led_device' "$TARGET/usr/bin/batocera-led-handheld" && pass led || fail_msg led

if ! grep -qE 'DEFAULT_TOUCH_MODE="4"|--default-touch-mode[[:space:]]+4' \
  "$TARGET/usr/bin/batocera-steam-session"; then
  pass steam_touch_off
else
  fail_msg steam_touch_off
fi

md5_src=$(md5sum "$ROOT/package/batocera/core/batocera-splash-odin3/images/logo.png" | awk '{print $1}')
md5_tgt=$(md5sum "$TARGET/usr/share/batocera/splash/boot-logo.png" 2>/dev/null | awk '{print $1}')
[ "$md5_src" = "$md5_tgt" ] && pass splash_logo || fail_msg splash_logo

if grep -rq '44-dev-pocket' "$TARGET/usr/share/batocera/" "$TARGET/etc/" 2>/dev/null; then
  pass version_pocket
else
  fail_msg version_pocket
fi

IMG=$(ls -1 "$TREE/images/batocera/images/sm8750"/batocera-sm8750-*.img.gz 2>/dev/null | tail -1 || true)
BOOT="$TREE/images/batocera/images/sm8750/boot.tar.xz"
[ -n "$IMG" ] && [ -f "$IMG" ] && pass "img:$IMG" || fail_msg img.gz
[ -f "$BOOT" ] && pass "boot.tar.xz" || fail_msg boot.tar.xz

echo "=== result fail=$fail ==="
echo ""
echo "Device smoke (manual on Odin 3) — do before retiring Arch backup:"
echo "  1. Flash new Docker img.gz (or OTA from Arch image via prep + boot.tar.xz)"
echo "  2. Boot; check ES, WiFi, audio, Steam session start"
echo "  3. batocera-config canupdate  (must resolve v44-sm8750-* tag)"
echo "  4. Only then: safe to reclaim output/sm8750-arch-backup disk"
exit "$fail"
