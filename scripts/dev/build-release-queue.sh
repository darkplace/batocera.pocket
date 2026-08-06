#!/usr/bin/env bash
# Sequential release builds for batocera.pocket Qualcomm targets.
# Order: sm8750 (Odin 3) → sm8550 (Odin 2 / Thor / AYANEO) → sm8250 (RP) → odin (SD845).
#
# Usage:
#   ./scripts/dev/build-release-queue.sh
#   TARGETS="sm8750 sm8550" ./scripts/dev/build-release-queue.sh

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

# odin (SD845) skipped by default: unmet qt5base/libxcb deps on this tree
TARGETS="${TARGETS:-sm8750 sm8550 sm8250}"
LOG_DIR="${PROJECT_DIR}/output/release-build-logs"
mkdir -p "$LOG_DIR"
MASTER_LOG="${LOG_DIR}/queue-$(date -u +%Y%m%dT%H%M%SZ).log"

# Direct host build by default (Docker -t breaks under nohup). Use DIRECT_BUILD= to force Docker.
DIRECT_BUILD="${DIRECT_BUILD-y}"
MAKE_JLEVEL="${MAKE_JLEVEL:-$(nproc)}"
MAKE_LLEVEL="${MAKE_LLEVEL:-$(nproc)}"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$MASTER_LOG"; }

log "=== batocera.pocket release build queue ==="
log "Targets: $TARGETS"
log "DIRECT_BUILD=${DIRECT_BUILD:-n (docker)}"
log "MAKE_JLEVEL=$MAKE_JLEVEL MAKE_LLEVEL=$MAKE_LLEVEL"
log "Commit: $(git rev-parse --short HEAD) — $(git log -1 --pretty=%s)"
log ""

FAIL=0
for t in $TARGETS; do
    TLOG="${LOG_DIR}/${t}-$(date -u +%Y%m%dT%H%M%SZ).log"
    log ">>> START $t  (log: $TLOG)"
    START=$(date +%s)

    set +e
    if [ -n "$DIRECT_BUILD" ]; then
        export TMPDIR="${PROJECT_DIR}/output/${t}/tmp"
        mkdir -p "$TMPDIR"
        # Ensure host-zstd exists before packages that extract .tar.zst (vkd3d-proton)
        make "${t}-build" DIRECT_BUILD=y MAKE_JLEVEL="$MAKE_JLEVEL" MAKE_LLEVEL="$MAKE_LLEVEL" BATCH_MODE= CMD=host-zstd \
            >>"$TLOG" 2>&1
        make "${t}-build" \
            DIRECT_BUILD=y \
            MAKE_JLEVEL="$MAKE_JLEVEL" \
            MAKE_LLEVEL="$MAKE_LLEVEL" \
            BATCH_MODE= \
            2>&1 | tee -a "$TLOG"
        rc=${PIPESTATUS[0]}
    else
        make "${t}-build" BATCH_MODE= CMD=host-zstd \
            MAKE_JLEVEL="$MAKE_JLEVEL" MAKE_LLEVEL="$MAKE_LLEVEL" >>"$TLOG" 2>&1
        make "${t}-build" \
            MAKE_JLEVEL="$MAKE_JLEVEL" \
            MAKE_LLEVEL="$MAKE_LLEVEL" \
            BATCH_MODE= \
            2>&1 | tee -a "$TLOG"
        rc=${PIPESTATUS[0]}
    fi
    set -e

    END=$(date +%s)
    DUR=$(( (END - START) / 60 ))
    if [ "$rc" -eq 0 ]; then
        log "<<< OK $t (${DUR} min)"
        # Record image paths if present
        find "output/${t}/images" -name 'batocera-*.img.gz' -o -name 'boot.tar.xz' 2>/dev/null \
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
