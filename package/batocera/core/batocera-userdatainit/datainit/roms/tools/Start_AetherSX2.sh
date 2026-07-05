#!/bin/bash

batocera-mouse show
trap 'batocera-mouse hide' EXIT
aethersx2 -bigpicture -fullscreen "$@"
