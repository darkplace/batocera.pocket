#!/bin/bash

if test -z "${DISPLAY}"
then
    export DISPLAY=$(getLocalXDisplay)
fi

emulatorlauncher -system gba -emulator skyemu -core skyemu -rom config

exit 0
