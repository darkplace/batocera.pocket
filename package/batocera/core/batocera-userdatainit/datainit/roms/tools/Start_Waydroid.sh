#!/bin/bash

if test -z "${WAYLAND_DISPLAY}" && test -z "${DISPLAY}"
then
    export WAYLAND_DISPLAY=$(getLocalWaylandDisplay)
fi

exec /usr/bin/batocera-waydroid-session
