#!/bin/bash
# Reinstall product locks and remake sm8750 image.
#
# Default: Docker primary tree at output/sm8750 (no DIRECT_BUILD / PARALLEL_BUILD).
# Emergency Arch: ARCH_BACKUP=1 → output/sm8750-arch-backup (swapped into slot for Make).
#
# Usage:
#   ./rebuild-sm8750-product-lock.sh
#   SKIP_REINSTALL=1 ./rebuild-sm8750-product-lock.sh
#   ARCH_BACKUP=1 ./rebuild-sm8750-product-lock.sh
#
# See docs/BUILD.md.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

ARCH_BACKUP="${ARCH_BACKUP:-0}"
SKIP_REINSTALL="${SKIP_REINSTALL:-0}"
LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-product-lock.log}"
PRIMARY="$PROJECT_DIR/output/sm8750"
ARCH_OUT="${SM8750_ARCH_OUT:-$PROJECT_DIR/output/sm8750-arch-backup}"
SWAP_DOCKER="$PROJECT_DIR/output/sm8750-docker-aside"
SWAPPED=0

if [ "$ARCH_BACKUP" = "1" ]; then
  DIRECT_BUILD=y
  PARALLEL_BUILD=y
  BUILD_LABEL=arch-backup
  if [ ! -d "$ARCH_OUT/host" ] && [ ! -d "$ARCH_OUT/build" ]; then
    echo "ERROR: Arch backup missing: $ARCH_OUT" >&2
    exit 1
  fi
  restore_layout() {
    [ "$SWAPPED" -eq 1 ] || return 0
    if [ -d "$PRIMARY" ]; then
      rm -rf "$ARCH_OUT"
      mv "$PRIMARY" "$ARCH_OUT"
      echo arch > "$ARCH_OUT/.batocera-build-env" 2>/dev/null || true
    fi
    if [ -d "$SWAP_DOCKER" ]; then
      mv "$SWAP_DOCKER" "$PRIMARY"
      echo docker > "$PRIMARY/.batocera-build-env" 2>/dev/null || true
    fi
  }
  trap restore_layout EXIT
  if [ -e "$PRIMARY" ] || [ -L "$PRIMARY" ]; then
    rm -rf "$SWAP_DOCKER"
    mv "$PRIMARY" "$SWAP_DOCKER"
  fi
  mv "$ARCH_OUT" "$PRIMARY"
  SWAPPED=1
  echo arch > "$PRIMARY/.batocera-build-env"
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PRIMARY}/host/bin"
  export LD_LIBRARY_PATH="/usr/lib:${PRIMARY}/host/lib"
  if [[ "$(readlink -f /sm8750 2>/dev/null || true)" != "$(readlink -f "$PRIMARY")" ]]; then
    ln -sfn "$PRIMARY" /sm8750 2>/dev/null || sudo ln -sfn "$PRIMARY" /sm8750
  fi
else
  DIRECT_BUILD=
  PARALLEL_BUILD=
  BUILD_LABEL=docker-primary
  mkdir -p "$PRIMARY"
  echo docker > "$PRIMARY/.batocera-build-env"
fi

OUT_TREE="$PRIMARY"
export TMPDIR="$OUT_TREE/tmp"
mkdir -p "$TMPDIR"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

IMG_DIR="$OUT_TREE/images/batocera/images/sm8750"

log() {
  echo "$@" | tee -a "$LOG_FILE"
}

{
  echo "=== batocera.pocket product lock rebuild ==="
  echo "Date: $(date)"
  echo "PID: $$"
  echo "Mode: $BUILD_LABEL"
  echo "SKIP_REINSTALL=$SKIP_REINSTALL ARCH_BACKUP=$ARCH_BACKUP"
  echo "Tree: $OUT_TREE"
  echo ""
} | tee "$LOG_FILE"

run_pkg() {
  local pkg="$1"
  log ""
  log ">>> make sm8750-pkg PKG=$pkg"
  set +e
  make sm8750-pkg \
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
  log ">>> make sm8750-build CMD=$cmd"
  set +e
  make sm8750-build \
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
  run_pkg batocera-splash-odin3-reinstall
  run_pkg batocera-arch-plasma-lxc-reinstall
  run_pkg batocera-ubuntu-plasma-lxc-reinstall
else
  log ">>> Skipping package reinstalls (SKIP_REINSTALL=1)"
fi

run_cmd target-finalize

PLASMA_SRC="$PROJECT_DIR/package/batocera/utils/batocera-arch-plasma-lxc/batocera-arch-plasma-lxc"
PLASMA_DST_REL="usr/bin/batocera-arch-plasma-lxc"
if [ -f "$PLASMA_SRC" ]; then
  log ">>> Force-sync batocera-arch-plasma-lxc from source into target + plasma PPs"
  install -D -m 0755 "$PLASMA_SRC" "$OUT_TREE/target/$PLASMA_DST_REL"
  if [ -d "$OUT_TREE/per-package/batocera-arch-plasma-lxc/target" ]; then
    install -D -m 0755 "$PLASMA_SRC" \
      "$OUT_TREE/per-package/batocera-arch-plasma-lxc/target/$PLASMA_DST_REL"
  fi
  if [ -d "$OUT_TREE/per-package/batocera-ubuntu-plasma-lxc/target" ]; then
    install -D -m 0755 "$PLASMA_SRC" \
      "$OUT_TREE/per-package/batocera-ubuntu-plasma-lxc/target/$PLASMA_DST_REL"
  fi
fi

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
rm -f "$OUT_TREE/images/rootfs.squashfs"
rm -f "$IMG_DIR"/batocera-sm8750-*.img.gz
rm -f "$IMG_DIR"/boot.tar.xz

run_cmd all

{
  echo ""
  echo "=== Finished: $(date) ==="
  ls -lh "$IMG_DIR"/batocera-sm8750-*.img.gz "$IMG_DIR"/boot.tar.xz 2>/dev/null || true
} | tee -a "$LOG_FILE"
