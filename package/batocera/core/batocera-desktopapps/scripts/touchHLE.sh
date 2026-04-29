#!/bin/bash
set -euo pipefail

batocera-mouse show
trap 'batocera-mouse hide' EXIT

TOUCHHLE_HOME=/userdata/roms/ios
RESOURCE_DIR=/usr/share/touchhle

mkdir -p \
    "${TOUCHHLE_HOME}" \
    "${TOUCHHLE_HOME}/touchHLE_apps" \
    "${TOUCHHLE_HOME}/touchHLE_sandbox"

for resource in touchHLE_dylibs touchHLE_fonts touchHLE_default_options.txt; do
    if [ ! -e "${TOUCHHLE_HOME}/${resource}" ]; then
        ln -snf "${RESOURCE_DIR}/${resource}" "${TOUCHHLE_HOME}/${resource}"
    fi
done

if [ ! -f "${TOUCHHLE_HOME}/touchHLE_options.txt" ]; then
    cp -f "${RESOURCE_DIR}/touchHLE_options.txt" "${TOUCHHLE_HOME}/touchHLE_options.txt"
fi

if [ ! -f "${TOUCHHLE_HOME}/OPTIONS_HELP.txt" ]; then
    cp -f "${RESOURCE_DIR}/OPTIONS_HELP.txt" "${TOUCHHLE_HOME}/OPTIONS_HELP.txt"
fi

if [ ! -f "${TOUCHHLE_HOME}/touchHLE_apps/README.txt" ]; then
    cp -f "${RESOURCE_DIR}/touchHLE_apps/README.txt" "${TOUCHHLE_HOME}/touchHLE_apps/README.txt"
fi

if [ -f /userdata/system/gamecontrollerdb.txt ]; then
    export SDL_GAMECONTROLLERCONFIG
    SDL_GAMECONTROLLERCONFIG="$(cat /userdata/system/gamecontrollerdb.txt)"
fi

export SDL_JOYSTICK_HIDAPI=0
export HOME="${TOUCHHLE_HOME}"

cd "${TOUCHHLE_HOME}"
if [ "$#" -eq 0 ]; then
    exec /usr/bin/touchHLE --fullscreen
fi

exec /usr/bin/touchHLE "$@"
