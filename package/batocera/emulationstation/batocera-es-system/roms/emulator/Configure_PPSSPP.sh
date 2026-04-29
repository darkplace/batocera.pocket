#!/bin/bash

if [ -z "${DISPLAY}" ]; then
    export DISPLAY="$(getLocalXDisplay)"
fi

unclutter-remote -s >/dev/null 2>&1 || true

if ! command -v "batocera-config-ppsspp" >/dev/null 2>&1; then
    echo "batocera-config-ppsspp is not available on this build."
    exit 1
fi

exec batocera-config-ppsspp
