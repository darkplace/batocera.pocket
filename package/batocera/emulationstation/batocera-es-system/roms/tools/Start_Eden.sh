#!/bin/bash

# when the program is called from a non X environment, handle the mouse
# maybe an other choice is better

if test -z "${DISPLAY}"
then
    export DISPLAY=$(getLocalXDisplay)
fi


/usr/bin/eden -platform xcb
