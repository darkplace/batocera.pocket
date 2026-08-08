#!/bin/bash
# Emergency Arch direct build for sm8750 (AYN Odin 3).
# Primary / release path is Docker — see docs/BUILD.md.
# Rebuilds the frozen Arch tree (default: output/sm8750-arch-backup).
#
# Usage:
#   ./build-arch-persistent.sh
#
# Env:
#   SM8750_ARCH_OUT   Arch tree (default: <project>/output/sm8750-arch-backup)
#   MAKE_JLEVEL / MAKE_LLEVEL  (default: 12)
#
# Requirements on Arch: libxcrypt-compat.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

ARCH_OUT="${SM8750_ARCH_OUT:-$PROJECT_DIR/output/sm8750-arch-backup}"
PRIMARY="$PROJECT_DIR/output/sm8750"
SWAP_DOCKER="$PROJECT_DIR/output/sm8750-docker-aside"
LOG_FILE="$PROJECT_DIR/build-arch-sm8750.log"
SWAPPED=0

if [ ! -d "$ARCH_OUT/host" ] && [ ! -d "$ARCH_OUT/build" ]; then
  echo "ERROR: Arch backup tree not found or empty: $ARCH_OUT" >&2
  exit 1
fi

restore_layout() {
  [ "$SWAPPED" -eq 1 ] || return 0
  # Primary currently holds Arch tree → move back to ARCH_OUT
  if [ -d "$PRIMARY" ]; then
    rm -rf "$ARCH_OUT"
    mv "$PRIMARY" "$ARCH_OUT"
    echo arch > "$ARCH_OUT/.batocera-build-env" 2>/dev/null || true
  fi
  # Restore Docker primary if we set it aside
  if [ -d "$SWAP_DOCKER" ]; then
    mv "$SWAP_DOCKER" "$PRIMARY"
    echo docker > "$PRIMARY/.batocera-build-env" 2>/dev/null || true
  fi
  if [ -d "$PRIMARY" ]; then
    ln -sfn "$PRIMARY" /sm8750 2>/dev/null || sudo ln -sfn "$PRIMARY" /sm8750 2>/dev/null || true
  elif [ -d "$ARCH_OUT" ]; then
    ln -sfn "$ARCH_OUT" /sm8750 2>/dev/null || sudo ln -sfn "$ARCH_OUT" /sm8750 2>/dev/null || true
  fi
}
trap restore_layout EXIT

# Slot Arch tree at output/sm8750 for Make (target name is always sm8750).
if [ -e "$PRIMARY" ] || [ -L "$PRIMARY" ]; then
  if [ "$(readlink -f "$PRIMARY")" = "$(readlink -f "$ARCH_OUT")" ]; then
    echo "ERROR: output/sm8750 and arch backup resolve to the same path; refuse." >&2
    exit 1
  fi
  rm -rf "$SWAP_DOCKER"
  mv "$PRIMARY" "$SWAP_DOCKER"
  echo docker > "$SWAP_DOCKER/.batocera-build-env" 2>/dev/null || true
fi
mv "$ARCH_OUT" "$PRIMARY"
SWAPPED=1
echo arch > "$PRIMARY/.batocera-build-env"

export TMPDIR="$PRIMARY/tmp"
mkdir -p "$TMPDIR"

if [[ "$(readlink -f /sm8750 2>/dev/null || true)" != "$(readlink -f "$PRIMARY")" ]]; then
  if ln -sfn "$PRIMARY" /sm8750 2>/dev/null; then
    :
  elif command -v sudo >/dev/null 2>&1; then
    sudo ln -sfn "$PRIMARY" /sm8750
  else
    echo "ERROR: need /sm8750 -> $PRIMARY (host-fakeroot PREFIX)" >&2
    exit 1
  fi
fi

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PRIMARY}/host/bin"
export LD_LIBRARY_PATH="/usr/lib:${PRIMARY}/host/lib"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

{
  echo "=== batocera.pocket - Arch EMERGENCY build sm8750 ==="
  echo "Dir: $PROJECT_DIR"
  echo "Arch backup restored to slot output/sm8750 for this run"
  echo "Date: $(date)"
  echo "PID: $$"
  echo "Commit: $(git rev-parse --short HEAD) — $(git log -1 --pretty=%s)"
  echo "Method: DIRECT_BUILD=y PARALLEL_BUILD=y"
  echo ""
} | tee "$LOG_FILE"

set +e
make sm8750-build \
    DIRECT_BUILD=y \
    PARALLEL_BUILD=y \
    MAKE_JLEVEL="${MAKE_JLEVEL:-12}" \
    MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
    2>&1 | tee -a "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}
set -e

{
  echo ""
  echo "=== Build finished: $(date) ==="
  echo "EXIT_CODE: $EXIT_CODE"
  if [ "$EXIT_CODE" -eq 0 ]; then
    echo "OK — images under output/sm8750 (will be moved back to arch-backup on exit):"
    ls -lh "$PRIMARY"/images/batocera/images/sm8750/*.{img.gz,xz} 2>/dev/null || true
  else
    echo "FAILED"
  fi
} | tee -a "$LOG_FILE"

exit "$EXIT_CODE"
