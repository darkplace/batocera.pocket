#!/bin/bash
set -euo pipefail

# Pin the complete variant identity instead of relying on defaults in the
# shared Plasma LXC engine.  This keeps an inherited Ubuntu smoke-test
# environment from redirecting the Arch launcher to the Ubuntu container.
export BATOCERA_PLASMA_DIST=archlinux
export BATOCERA_PLASMA_OS_ID=arch
export BATOCERA_PLASMA_IMAGE_RELEASE=current
export BATOCERA_PLASMA_LABEL="Arch Plasma"
export BATOCERA_PLASMA_ROOTFS_URL=
export BATOCERA_PLASMA_ROOTFS_FALLBACK_URLS=
export BATOCERA_PLASMA_ROOTFS_INDEX_URL=
export BATOCERA_ARCH_PLASMA_CONTAINER=arch-plasma
export BATOCERA_ARCH_PLASMA_LXC_PATH=/userdata/system/lxc
export BATOCERA_ARCH_PLASMA_STATE_DIR=/userdata/system/arch-plasma-lxc
export BATOCERA_ARCH_PLASMA_LOG=/userdata/system/logs/arch-plasma-lxc.log
export BATOCERA_ARCH_PLASMA_RUNTIME=/userdata/system/.runtime-arch-plasma
export BATOCERA_ARCH_PLASMA_SESSION_NAME=arch-plasma-lxc
export BATOCERA_ARCH_PLASMA_ENABLE_INPUTMETHOD="${BATOCERA_ARCH_PLASMA_ENABLE_INPUTMETHOD:-1}"
# Keep FORCE_OUTPUT_MODE at 1080p; scale widgets via KWin (see batocera-ui-scale).
if [ -z "${BATOCERA_ARCH_PLASMA_OUTPUT_SCALE:-}" ]; then
    if command -v batocera-ui-scale >/dev/null 2>&1; then
        BATOCERA_ARCH_PLASMA_OUTPUT_SCALE="$(batocera-ui-scale factor)"
    else
        BATOCERA_ARCH_PLASMA_OUTPUT_SCALE="1.75"
    fi
fi
export BATOCERA_ARCH_PLASMA_OUTPUT_SCALE
export BATOCERA_ARCH_PLASMA_TOUCH_CALIBRATION_MATRIX="${BATOCERA_ARCH_PLASMA_TOUCH_CALIBRATION_MATRIX:-auto}"
export BATOCERA_ARCH_PLASMA_POINTER_ACCEL="${BATOCERA_ARCH_PLASMA_POINTER_ACCEL:--0.5}"
exec /usr/bin/batocera-arch-plasma-lxc "$@"
