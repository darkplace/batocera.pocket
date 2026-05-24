#!/bin/bash

if test -z "${DISPLAY}"
then
    export DISPLAY=$(getLocalXDisplay)
fi

exec xterm -fs 14 -fg white -bg black -fa "Monospace" -en UTF-8 -sb -rightbar -geometry 120x38 -e env BATOCERA_FORCE_DIALOG=1 /usr/bin/batocera-m3u-builder dialog
