#!/bin/bash
# Canonical Arch direct build for sm8750 (AYN Odin 3).
# This is the same method that produced the working device image.
#
# Usage:
#   cd /home/lukemotion/batocera.pocket
#   ./build-arch-persistent.sh
#
# Requirements on Arch: libxcrypt-compat (libcrypt.so.1 for host mkpasswd).

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

export TMPDIR="$PROJECT_DIR/output/sm8750/tmp"
mkdir -p "$TMPDIR"

# PARALLEL_BUILD host tools were configured with prefix /sm8750/... (short
# BASE_DIR / bind-mount path). fakeroot and many other host wrappers look for
# libs under that absolute path — keep a stable symlink for finalize steps.
if [[ ! -e /sm8750 ]] || [[ "$(readlink -f /sm8750 2>/dev/null || true)" != "$(readlink -f "$PROJECT_DIR/output/sm8750")" ]]; then
  if ln -sfn "$PROJECT_DIR/output/sm8750" /sm8750 2>/dev/null; then
    :
  elif command -v sudo >/dev/null 2>&1; then
    sudo ln -sfn "$PROJECT_DIR/output/sm8750" /sm8750
  else
    echo "ERROR: need /sm8750 -> $PROJECT_DIR/output/sm8750 (host-fakeroot PREFIX)" >&2
    exit 1
  fi
fi

# Keep argv/env under ARG_MAX (Cursor injects huge PATH/env otherwise).
# System tools first; host/lib last so libpython resolves without breaking git/perl.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PROJECT_DIR}/output/sm8750/host/bin"
export LD_LIBRARY_PATH="/usr/lib:${PROJECT_DIR}/output/sm8750/host/lib"
export CMAKE_POLICY_VERSION_MINIMUM=3.5
LOG_FILE="$PROJECT_DIR/build-arch-sm8750.log"

{
  echo "=== batocera.pocket - Arch Build sm8750 (Odin 3) ==="
  echo "Dir: $PROJECT_DIR"
  echo "Date: $(date)"
  echo "PID: $$"
  echo "Commit: $(git rev-parse --short HEAD) — $(git log -1 --pretty=%s)"
  echo "Method: DIRECT_BUILD=y PARALLEL_BUILD=y (per-package)"
  echo ""
} | tee "$LOG_FILE"

set +e
make sm8750-build \
    DIRECT_BUILD=y \
    PARALLEL_BUILD=y \
    MAKE_JLEVEL="${MAKE_JLEVEL:-20}" \
    MAKE_LLEVEL="${MAKE_LLEVEL:-20}" \
    2>&1 | tee -a "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}
set -e

{
  echo ""
  echo "=== Build finished: $(date) ==="
  echo "EXIT_CODE: $EXIT_CODE"
  if [ "$EXIT_CODE" -eq 0 ]; then
    echo "OK — images:"
    ls -lh "$PROJECT_DIR"/output/sm8750/images/batocera/images/sm8750/*.{img.gz,xz} 2>/dev/null || \
      find "$PROJECT_DIR/output/sm8750/images" -name 'batocera-*.img.gz' -o -name 'boot.tar.xz' 2>/dev/null
  else
    echo "FAILED"
  fi
} | tee -a "$LOG_FILE"

exit "$EXIT_CODE"
