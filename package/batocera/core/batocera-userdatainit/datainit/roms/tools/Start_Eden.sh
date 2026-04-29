#!/bin/bash

if test -z "${DISPLAY}"
then
    export DISPLAY=$(getLocalXDisplay)
fi

XDG_CONFIG_HOME="/userdata/system/configs" \
XDG_DATA_HOME="/userdata/saves/switch" \
XDG_CACHE_HOME="/userdata/system/cache" \
QT_QPA_PLATFORM="xcb" \
/usr/bin/eden -platform xcb
