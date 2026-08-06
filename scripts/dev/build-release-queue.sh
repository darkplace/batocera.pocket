#!/usr/bin/env bash
# Sequential release builds for batocera.pocket Qualcomm targets.
# Default method matches the working Odin 3 path: Arch DIRECT_BUILD + PARALLEL_BUILD.
#
# Usage:
#   ./scripts/dev/build-release-queue.sh
#   TARGETS="sm8750" ./scripts/dev/build-release-queue.sh
#   DIRECT_BUILD= TARGETS="sm8550" ./scripts/dev/build-release-queue.sh   # Docker only on clean trees

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

TARGETS="${TARGETS:-sm8750 sm8550 sm8250}"
LOG_DIR="${PROJECT_DIR}/output/release-build-logs"
mkdir -p "$LOG_DIR"
MASTER_LOG="${LOG_DIR}/queue-$(date -u +%Y%m%dT%H%M%SZ).log"

# Match build-arch-persistent.sh / working Odin builds
DIRECT_BUILD="${DIRECT_BUILD-y}"
PARALLEL_BUILD="${PARALLEL_BUILD-y}"
MAKE_JLEVEL="${MAKE_JLEVEL:-20}"
MAKE_LLEVEL="${MAKE_LLEVEL:-20}"
export CMAKE_POLICY_VERSION_MINIMUM="${CMAKE_POLICY_VERSION_MINIMUM:-3.5}"
# Shrink env so target-finalize does not hit ARG_MAX under Cursor
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$MASTER_LOG"; }

log "=== batocera.pocket release build queue ==="
log "Targets: $TARGETS"
if [ -n "$DIRECT_BUILD" ]; then
    log "Method: DIRECT_BUILD=y PARALLEL_BUILD=${PARALLEL_BUILD:-n}"
else
    log "Method: Docker (only safe on trees whose host/ was built in Docker)"
fi
log "MAKE_JLEVEL=$MAKE_JLEVEL"
log "Commit: $(git rev-parse --short HEAD) — $(git log -1 --pretty=%s)"
log ""

FAIL=0
for t in $TARGETS; do
    TLOG="${LOG_DIR}/${t}-$(date -u +%Y%m%dT%H%M%SZ).log"
    log ">>> START $t  (log: $TLOG)"
    START=$(date +%s)

    set +e
    export TMPDIR="${PROJECT_DIR}/output/${t}/tmp"
    mkdir -p "$TMPDIR"
    if [ -d "${PROJECT_DIR}/output/${t}/host/lib" ]; then
        export LD_LIBRARY_PATH="/usr/lib:${PROJECT_DIR}/output/${t}/host/lib"
    else
        unset LD_LIBRARY_PATH || true
    fi
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PROJECT_DIR}/output/${t}/host/bin"
    if [ -n "$DIRECT_BUILD" ]; then
        make "${t}-build" \
            DIRECT_BUILD=y \
            PARALLEL_BUILD=y \
            MAKE_JLEVEL="$MAKE_JLEVEL" \
            MAKE_LLEVEL="$MAKE_LLEVEL" \
            2>&1 | tee -a "$TLOG"
        rc=${PIPESTATUS[0]}
    else
        make "${t}-build" \
            MAKE_JLEVEL="$MAKE_JLEVEL" \
            MAKE_LLEVEL="$MAKE_LLEVEL" \
            2>&1 | tee -a "$TLOG"
        rc=${PIPESTATUS[0]}
    fi
    set -e

    END=$(date +%s)
    DUR=$(( (END - START) / 60 ))
    if [ "$rc" -eq 0 ]; then
        log "<<< OK $t (${DUR} min)"
        find "output/${t}/images" \( -name 'batocera-*.img.gz' -o -name 'boot.tar.xz' \) 2>/dev/null \
            | tee -a "$MASTER_LOG" || true
    else
        log "<<< FAIL $t exit=$rc (${DUR} min) — continuing with next target"
        FAIL=1
        echo "$rc" > "${LOG_DIR}/${t}.exit"
    fi
    log ""
done

log "=== queue finished FAIL=$FAIL ==="
echo "$FAIL" > "${LOG_DIR}/queue.exit"
exit "$FAIL"
