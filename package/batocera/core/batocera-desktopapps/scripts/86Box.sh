#!/bin/bash
set -euo pipefail

batocera-mouse show
trap 'batocera-mouse hide' EXIT

export HOME=/userdata/system
export XDG_CONFIG_HOME=/userdata/system/configs
export XDG_DATA_HOME=/userdata/saves/86box
export XDG_CACHE_HOME=/userdata/system/cache

mkdir -p \
    "${XDG_CONFIG_HOME}/86Box" \
    "${XDG_DATA_HOME}" \
    "${XDG_CACHE_HOME}/86box"

exec /usr/bin/86Box "$@"
