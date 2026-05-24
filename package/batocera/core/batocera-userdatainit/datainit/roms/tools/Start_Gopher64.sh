#!/bin/bash

if test -z "${DISPLAY}"
then
    export DISPLAY=$(getLocalXDisplay)
fi

emulatorlauncher -system n64 -emulator gopher64 -core gopher64 -rom config

exit 0
