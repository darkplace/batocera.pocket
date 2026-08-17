#!/bin/bash

if [ -z "${DISPLAY}" ] && [ -z "${WAYLAND_DISPLAY}" ]; then
    export DISPLAY="$(getLocalXDisplay)"
fi

unclutter-remote -s >/dev/null 2>&1 || true

if ! command -v pkmnrecomp >/dev/null 2>&1; then
    echo "pkmnrecomp is not available on this build."
    exit 1
fi

exec pkmnrecomp --core gen2recomp --config
