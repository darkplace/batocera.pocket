#!/bin/bash
# Persistent Arch build script for sm8750
# Run from a terminal outside Cursor:
#   cd /home/lukemotion/batocera.pocket
#   ./build-arch-persistent.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# Set TMPDIR outside /tmp to avoid Cursor sandbox
export TMPDIR="$PROJECT_DIR/output/sm8750/tmp"
mkdir -p "$TMPDIR"

LOG_FILE="$PROJECT_DIR/build-arch-sm8750.log"

echo "=== batocera.pocket - Arch Build sm8750 ===" | tee "$LOG_FILE"
echo "Directorio: $PROJECT_DIR" | tee -a "$LOG_FILE"
echo "Fecha: $(date)" | tee -a "$LOG_FILE"
echo "PID: $$" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Run the build
make sm8750-build \
    DIRECT_BUILD=y \
    MAKE_JLEVEL=20 \
    MAKE_LLEVEL=20 \
    BATCH_MODE=1 \
    EXTRA_OPTS="BR2_CCACHE=n" \
    2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=$?

echo "" | tee -a "$LOG_FILE"
echo "=== Build terminado: $(date) ===" | tee -a "$LOG_FILE"
echo "EXIT_CODE: $EXIT_CODE" | tee -a "$LOG_FILE"

if [ $EXIT_CODE -eq 0 ]; then
    echo "Build exitoso!" | tee -a "$LOG_FILE"
    echo "Imagen en: $PROJECT_DIR/output/sm8750/images/" | tee -a "$LOG_FILE"
    ls -la "$PROJECT_DIR/output/sm8750/images/" 2>/dev/null | tee -a "$LOG_FILE"
else
    echo "Build falló con código $EXIT_CODE" | tee -a "$LOG_FILE"
fi

exit $EXIT_CODE
