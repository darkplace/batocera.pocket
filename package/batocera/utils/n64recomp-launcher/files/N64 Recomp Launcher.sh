#!/bin/bash

if command -v batocera-mouse >/dev/null 2>&1; then
    batocera-mouse show
    trap 'batocera-mouse hide' EXIT
fi

exec n64recomp-launcher "$@"
