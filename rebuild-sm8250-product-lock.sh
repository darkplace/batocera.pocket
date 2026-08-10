#!/bin/bash
# Reinstall product locks and remake the sm8250 image (Docker primary tree at
# output/sm8250). Mirror of rebuild-sm8550-product-lock.sh, adapted for sm8250.
#
# sm8250 (Retroid Pocket 5 / Mini / Mini V2 / Flip 2) does NOT ship the Arch /
# Ubuntu Plasma LXC nor batocera-apps, and uses the generic batocera-splash
# (no board-specific logo). So the Plasma reinstalls / force-sync / plasma_scrub
# precheck are dropped, and the splash / led / steam prechecks are non-fatal
# (board-variant tolerant). The critical OTA / fan / governor / version locks
# are still enforced.
#
# Usage:
#   ./rebuild-sm8250-product-lock.sh
#   SKIP_REINSTALL=1 ./rebuild-sm8250-product-lock.sh
#
# See docs/BUILD.md.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

SKIP_REINSTALL="${SKIP_REINSTALL:-0}"
LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8250-product-lock.log}"
PRIMARY="$PROJECT_DIR/output/sm8250"

DIRECT_BUILD=
PARALLEL_BUILD=
BUILD_LABEL=docker-primary
mkdir -p "$PRIMARY"
echo docker > "$PRIMARY/.batocera-build-env"

OUT_TREE="$PRIMARY"
export TMPDIR="$OUT_TREE/tmp"
mkdir -p "$TMPDIR"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

IMG_DIR="$OUT_TREE/images/batocera/images/sm8250"

log() {
  echo "$@" | tee -a "$LOG_FILE"
}

{
  echo "=== batocera.pocket product lock rebuild (sm8250) ==="
  echo "Date: $(date)"
  echo "PID: $$"
  echo "Mode: $BUILD_LABEL"
  echo "SKIP_REINSTALL=$SKIP_REINSTALL"
  echo "Tree: $OUT_TREE"
  echo ""
} | tee "$LOG_FILE"

run_pkg() {
  local pkg="$1"
  log ""
  log ">>> make sm8250-pkg PKG=$pkg"
  set +e
  make sm8250-pkg \
      PKG="$pkg" \
      DIRECT_BUILD="$DIRECT_BUILD" \
      PARALLEL_BUILD="$PARALLEL_BUILD" \
      MAKE_JLEVEL="${MAKE_JLEVEL:-12}" \
      MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
      2>&1 | tee -a "$LOG_FILE"
  local ec=${PIPESTATUS[0]}
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: $pkg (exit $ec)"
    exit "$ec"
  fi
}

run_cmd() {
  local cmd="$1"
  log ""
  log ">>> make sm8250-build CMD=$cmd"
  set +e
  make sm8250-build \
      CMD="$cmd" \
      DIRECT_BUILD="$DIRECT_BUILD" \
      PARALLEL_BUILD="$PARALLEL_BUILD" \
      MAKE_JLEVEL="${MAKE_JLEVEL:-12}" \
      MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
      2>&1 | tee -a "$LOG_FILE"
  local ec=${PIPESTATUS[0]}
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: CMD=$cmd (exit $ec)"
    exit "$ec"
  fi
}

if [ "$SKIP_REINSTALL" != "1" ]; then
  run_pkg batocera-scripts-reinstall
  run_pkg batocera-system-reinstall
  # A1 fan modes UI (Silent/Auto/Aggressive/Off) live in controlcenter.xml.
  run_pkg batocera-controlcenter-reinstall
  # Packages whose *installed* (copied, not compiled) scripts we edited and
  # that buildroot would otherwise ship stale: A2 wine wine64/fallback, A6 UI
  # scale hooks in desktop apps / aarch64 app launchers.
  run_pkg batocera-wine-reinstall
  run_pkg batocera-desktopapps-reinstall
  run_pkg batocera-apps-aarch64-reinstall
else
  log ">>> Skipping package reinstalls (SKIP_REINSTALL=1)"
fi

run_cmd target-finalize

log ""
log ">>> Target lock greps (post target-finalize)"
TARGET="$OUT_TREE/target"
fail=0
set +e

if grep -q 'updates.url=https://github.com/darkplace/batocera.pocket' \
  "$TARGET/usr/share/batocera/datainit/system/batocera.conf"; then
  log "PASS updates.url"
else
  log "FAIL updates.url"
  fail=1
fi

if grep -q 'darkplace/batocera.pocket' "$TARGET/usr/bin/batocera-upgrade"; then
  log "PASS upgrade"
else
  log "FAIL upgrade"
  fail=1
fi

if [ -x "$TARGET/usr/bin/batocera-pocket-github-release" ]; then
  log "PASS ota_helper"
else
  log "FAIL ota_helper (batocera-pocket-github-release missing)"
  fail=1
fi

if grep -q 'batocera-pocket-github-release' "$TARGET/usr/bin/batocera-upgrade" \
  && ! grep -qE 'api\.github\.com/.*/releases/latest' "$TARGET/usr/bin/batocera-upgrade"; then
  log "PASS ota_per_board"
else
  log "FAIL ota_per_board (upgrade still uses /releases/latest or missing helper)"
  fail=1
fi

# A1 fan modes UI must ship in controlcenter.xml
if grep -q 'qcom-fan aggressive' "$TARGET/usr/share/batocera/controlcenter/controlcenter.xml" 2>/dev/null; then
  log "PASS fan_modes_ui"
else
  log "FAIL fan_modes_ui (controlcenter.xml missing silent/aggressive choices)"
  fail=1
fi

# A1 fan root-cause fix + A7 governor honoring must ship
if grep -q 'basename(tok) == "qcom-fan"' "$TARGET/usr/bin/qcom-fan" 2>/dev/null; then
  log "PASS fan_bootfix"
else
  log "FAIL fan_bootfix (qcom-fan missing basename daemon match)"
  fail=1
fi

# OTA downgrade-popup fix must ship
if grep -q '_ver_num' "$TARGET/usr/bin/batocera-config" 2>/dev/null; then
  log "PASS ota_no_downgrade"
else
  log "FAIL ota_no_downgrade (batocera-config canupdate not numeric)"
  fail=1
fi

# LED handheld helper is board-variant; check only if present (non-fatal).
if [ -f "$TARGET/usr/bin/batocera-led-handheld" ]; then
  if grep -q 'is_split_status_led_device' "$TARGET/usr/bin/batocera-led-handheld"; then
    log "PASS led"
  else
    log "WARN led (batocera-led-handheld present but missing split-status marker; non-fatal)"
  fi
else
  log "WARN led (batocera-led-handheld not shipped on this board; non-fatal)"
fi

# Steam session touch default is board-variant; check only if present (non-fatal).
if [ -f "$TARGET/usr/bin/batocera-steam-session" ]; then
  if ! grep -qE 'DEFAULT_TOUCH_MODE="4"|--default-touch-mode[[:space:]]+4' \
    "$TARGET/usr/bin/batocera-steam-session"; then
    log "PASS steam_touch_off"
  else
    log "WARN steam_touch_off (default-touch-mode 4 still present; non-fatal)"
  fi
else
  log "WARN steam_touch_off (batocera-steam-session not shipped on this board; non-fatal)"
fi

version_ok=0
VERSION_FILE=""
for cand in \
  "$TARGET/usr/share/batocera/batocera.version" \
  "$TARGET/etc/batocera.version" \
  "$TARGET/usr/share/batocera/system/batocera.version"
do
  if [ -f "$cand" ]; then
    VERSION_FILE="$cand"
    break
  fi
done
if [ -z "$VERSION_FILE" ]; then
  VERSION_FILE=$(find "$TARGET/usr/share/batocera" "$TARGET/etc" -name 'batocera.version' 2>/dev/null | head -1)
fi
if [ -n "${VERSION_FILE:-}" ] && [ -f "$VERSION_FILE" ]; then
  log "version_file=$VERSION_FILE content=$(tr -d '\n' < "$VERSION_FILE")"
  if grep -q '44-dev-pocket' "$VERSION_FILE"; then
    version_ok=1
  fi
fi
if [ "$version_ok" -eq 0 ] && [ -f "$TARGET/etc/issue" ] && grep -q '44-dev-pocket' "$TARGET/etc/issue"; then
  version_ok=1
fi
if [ "$version_ok" -eq 0 ]; then
  if grep -rq '44-dev-pocket' "$TARGET/usr/share/batocera/" "$TARGET/etc/" 2>/dev/null; then
    version_ok=1
  fi
fi
if [ "$version_ok" -eq 1 ]; then
  log "PASS version_pocket"
else
  log "FAIL version_pocket"
  fail=1
fi

set -e
log "prechecks fail=$fail"
[ "$fail" -eq 0 ] || exit 1

log ">>> Removing rootfs.squashfs and prior images"
rm -f "$OUT_TREE/images/rootfs.squashfs"
rm -f "$IMG_DIR"/batocera-sm8250-*.img.gz
rm -f "$IMG_DIR"/boot.tar.xz

run_cmd all

{
  echo ""
  echo "=== Finished: $(date) ==="
  ls -lh "$IMG_DIR"/batocera-sm8250-*.img.gz "$IMG_DIR"/boot.tar.xz 2>/dev/null || true
} | tee -a "$LOG_FILE"
