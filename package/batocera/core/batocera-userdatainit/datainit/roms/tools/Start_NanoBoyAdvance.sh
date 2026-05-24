#!/bin/bash

if test -z "${DISPLAY}"
then
    export DISPLAY=$(getLocalXDisplay)
fi

emulatorlauncher -system gba -emulator nanoboyadvance -core nanoboyadvance -rom config

exit 0
