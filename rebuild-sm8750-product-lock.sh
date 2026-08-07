#!/bin/bash
# Reinstall product locks (plasma scrub, splash logos, version) and remake sm8750 image.
# With PARALLEL_BUILD=y, package *-reinstall only updates per-package/<pkg>/target.
# Merged output/.../target is refreshed by target-finalize (also part of all-images).
#
# Usage:
#   ./rebuild-sm8750-product-lock.sh
#   SKIP_REINSTALL=1 ./rebuild-sm8750-product-lock.sh   # PP already updated; merge + image only
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

export TMPDIR="$PROJECT_DIR/output/sm8750/tmp"
mkdir -p "$TMPDIR"

if [[ ! -e /sm8750 ]] || [[ "$(readlink -f /sm8750 2>/dev/null || true)" != "$(readlink -f "$PROJECT_DIR/output/sm8750")" ]]; then
  if ln -sfn "$PROJECT_DIR/output/sm8750" /sm8750 2>/dev/null; then
    :
  elif command -v sudo >/dev/null 2>&1; then
    sudo ln -sfn "$PROJECT_DIR/output/sm8750" /sm8750
  else
    echo "ERROR: need /sm8750 -> $PROJECT_DIR/output/sm8750" >&2
    exit 1
  fi
fi

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PROJECT_DIR}/output/sm8750/host/bin"
export LD_LIBRARY_PATH="/usr/lib:${PROJECT_DIR}/output/sm8750/host/lib"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

LOG_FILE="$PROJECT_DIR/rebuild-sm8750-product-lock.log"
IMG_DIR="$PROJECT_DIR/output/sm8750/images/batocera/images/sm8750"
SKIP_REINSTALL="${SKIP_REINSTALL:-0}"

log() {
  echo "$@" | tee -a "$LOG_FILE"
}

{
  echo "=== batocera.pocket product lock rebuild ==="
  echo "Date: $(date)"
  echo "PID: $$"
  echo "SKIP_REINSTALL=$SKIP_REINSTALL"
  echo ""
} | tee "$LOG_FILE"

# Package reinstalls go through sm8750-pkg (PKG= is a real package name).
run_pkg() {
  local pkg="$1"
  log ""
  log ">>> make sm8750-pkg PKG=$pkg"
  set +e
  make sm8750-pkg \
      PKG="$pkg" \
      DIRECT_BUILD=y \
      PARALLEL_BUILD=y \
      MAKE_JLEVEL="${MAKE_JLEVEL:-20}" \
      MAKE_LLEVEL="${MAKE_LLEVEL:-20}" \
      2>&1 | tee -a "$LOG_FILE"
  local ec=${PIPESTATUS[0]}
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: $pkg (exit $ec)"
    exit "$ec"
  fi
}

# Non-package Buildroot targets (target-finalize, all-images) must use CMD=, not PKG=.
# PKG=target-finalize breaks PARALLEL_BUILD with: per-package//target
run_cmd() {
  local cmd="$1"
  log ""
  log ">>> make sm8750-build CMD=$cmd"
  set +e
  make sm8750-build \
      CMD="$cmd" \
      DIRECT_BUILD=y \
      PARALLEL_BUILD=y \
      MAKE_JLEVEL="${MAKE_JLEVEL:-20}" \
      MAKE_LLEVEL="${MAKE_LLEVEL:-20}" \
      2>&1 | tee -a "$LOG_FILE"
  local ec=${PIPESTATUS[0]}
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: CMD=$cmd (exit $ec)"
    exit "$ec"
  fi
}

if [ "$SKIP_REINSTALL" != "1" ]; then
  run_pkg batocera-system-reinstall
  run_pkg batocera-splash-odin3-reinstall
  # Arch first, then Ubuntu (Ubuntu PP vendors a copy of the arch script and can
  # overwrite target with a stale binary during target-finalize if left old).
  run_pkg batocera-arch-plasma-lxc-reinstall
  run_pkg batocera-ubuntu-plasma-lxc-reinstall
  run_pkg batocera-scripts-reinstall
else
  log ">>> Skipping package reinstalls (SKIP_REINSTALL=1); using existing per-package trees"
fi

run_cmd target-finalize

# Belt-and-suspenders: Ubuntu PP may still race-overwrite arch script on merge.
# Force the current source script into merged target + both plasma PPs.
PLASMA_SRC="$PROJECT_DIR/package/batocera/utils/batocera-arch-plasma-lxc/batocera-arch-plasma-lxc"
PLASMA_DST_REL="usr/bin/batocera-arch-plasma-lxc"
if [ -f "$PLASMA_SRC" ]; then
  log ">>> Force-sync batocera-arch-plasma-lxc from source into target + plasma PPs"
  install -D -m 0755 "$PLASMA_SRC" "$PROJECT_DIR/output/sm8750/target/$PLASMA_DST_REL"
  install -D -m 0755 "$PLASMA_SRC" \
    "$PROJECT_DIR/output/sm8750/per-package/batocera-arch-plasma-lxc/target/$PLASMA_DST_REL"
  install -D -m 0755 "$PLASMA_SRC" \
    "$PROJECT_DIR/output/sm8750/per-package/batocera-ubuntu-plasma-lxc/target/$PLASMA_DST_REL"
fi

log ""
log ">>> Target lock greps (post target-finalize)"
TARGET="$PROJECT_DIR/output/sm8750/target"
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

if grep -q 'scrub_mobile_shell_config' "$TARGET/usr/bin/batocera-arch-plasma-lxc"; then
  log "PASS plasma_scrub"
else
  log "FAIL plasma_scrub"
  fail=1
fi

if grep -q 'is_split_status_led_device' "$TARGET/usr/bin/batocera-led-handheld"; then
  log "PASS led"
else
  log "FAIL led"
  fail=1
fi

if ! grep -qE 'DEFAULT_TOUCH_MODE="4"|--default-touch-mode[[:space:]]+4' \
  "$TARGET/usr/bin/batocera-steam-session"; then
  log "PASS steam_touch_off"
else
  log "FAIL steam_touch_off"
  fail=1
fi

md5_src=$(md5sum "$PROJECT_DIR/package/batocera/core/batocera-splash-odin3/images/logo.png" 2>/dev/null | awk '{print $1}')
md5_tgt=$(md5sum "$TARGET/usr/share/batocera/splash/boot-logo.png" 2>/dev/null | awk '{print $1}')
if [ -n "$md5_src" ] && [ -n "$md5_tgt" ] && [ "$md5_src" = "$md5_tgt" ]; then
  log "PASS splash_logo"
else
  log "FAIL splash_logo src=${md5_src:-missing} tgt=${md5_tgt:-missing}"
  fail=1
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
rm -f "$PROJECT_DIR/output/sm8750/images/rootfs.squashfs"
rm -f "$IMG_DIR"/batocera-sm8750-*.img.gz
rm -f "$IMG_DIR"/boot.tar.xz

run_cmd all-images

{
  echo ""
  echo "=== Finished: $(date) ==="
  ls -lh "$IMG_DIR"/batocera-sm8750-*.img.gz "$IMG_DIR"/boot.tar.xz 2>/dev/null || true
} | tee -a "$LOG_FILE"
