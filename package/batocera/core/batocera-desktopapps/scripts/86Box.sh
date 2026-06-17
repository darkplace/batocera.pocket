#!/bin/bash
set -euo pipefail

batocera-mouse show
trap 'batocera-mouse hide' EXIT

export HOME=/userdata/system
export XDG_CONFIG_HOME=/userdata/system/configs
export XDG_DATA_HOME=/userdata/saves/86box
export XDG_CACHE_HOME=/userdata/system/cache
ROM_PATH=/userdata/bios/86box

mkdir -p \
    "${XDG_CONFIG_HOME}/86Box" \
    "${XDG_DATA_HOME}" \
    "${XDG_CACHE_HOME}/86box" \
    "${ROM_PATH}"

has_rompath=0
for arg in "$@"
do
    case "${arg}" in
        --rompath|--rompath=*)
            has_rompath=1
            ;;
    esac
done

if test "${has_rompath}" -eq 1
then
    exec /usr/bin/86Box "$@"
fi

exec /usr/bin/86Box --rompath "${ROM_PATH}" "$@"
