#!/bin/bash

if [ ! -x /usr/bin/batocera-waydroid-session ] || [ ! -x /usr/bin/waydroid ]; then
    mkdir -p /userdata/system/logs
    echo "[$(date '+%F %T')] Waydroid package is not installed in this image." >> /userdata/system/logs/waydroid-launcher.log
    if command -v batocera-flash-screen >/dev/null 2>&1; then
        /usr/bin/batocera-flash-screen 7 "#ffffff" "Waydroid is not installed in this image." 20 >/dev/null 2>&1 || true
        /usr/bin/batocera-flash-screen 7 "#ffffff" "Rebuild/flash the image with Waydroid enabled." 18 >/dev/null 2>&1 || true
    fi
    exit 1
fi

if test -z "${WAYLAND_DISPLAY}" && test -z "${DISPLAY}"; then
    export WAYLAND_DISPLAY=$(getLocalWaylandDisplay)
fi

exec /usr/bin/batocera-waydroid-session
