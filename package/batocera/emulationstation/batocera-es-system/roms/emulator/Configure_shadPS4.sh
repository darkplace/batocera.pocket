#!/bin/bash

if [ -z "${DISPLAY}" ]; then
    export DISPLAY="$(getLocalXDisplay)"
fi

unclutter-remote -s >/dev/null 2>&1 || true

if command -v "batocera-config-shadps4" >/dev/null 2>&1; then
    exec batocera-config-shadps4
fi

exec emulatorlauncher -system ps4 -rom config -emulator shadps4
