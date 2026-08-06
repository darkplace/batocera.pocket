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

# Keep argv/env under ARG_MAX (Cursor injects huge PATH/env otherwise).
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
export LD_LIBRARY_PATH="$PROJECT_DIR/output/sm8750/host/lib"
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
