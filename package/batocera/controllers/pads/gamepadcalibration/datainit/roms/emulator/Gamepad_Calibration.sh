#!/bin/bash

if ! command -v batocera-gamepad-calibrator >/dev/null 2>&1; then
    echo "batocera-gamepad-calibrator is not available on this build."
    exit 1
fi

exec batocera-gamepad-calibrator
