#!/bin/bash

# when the program is called from a non X environment, handle the mouse
# maybe an other choice is better

if test -z "${DISPLAY}"
then
    export DISPLAY=$(getLocalXDisplay)
fi

batocera-mouse show
trap 'batocera-mouse hide' EXIT

if [[ -x /usr/bin/lutris ]]; then
    /usr/bin/lutris
else
    echo "System not found."
    exit 1
fi
