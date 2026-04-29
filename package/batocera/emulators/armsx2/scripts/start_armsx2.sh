#!/bin/sh

set -eu

DATA_ROOT="/userdata/system/.config/aethersx2"
CONFIG_ROOT="/usr/share/batocera/datainit/system/configs/armsx2"

mkdir -p "${DATA_ROOT}" /userdata/bios/armsx2 /userdata/saves/ps2 /userdata/screenshots

if [ ! -f "${DATA_ROOT}/inis/PCSX2.ini" ] && [ -d "${CONFIG_ROOT}" ]; then
    mkdir -p "${DATA_ROOT}/inis"
    cp -f "${CONFIG_ROOT}/ARMSX2.ini" "${DATA_ROOT}/inis/PCSX2.ini"
fi

if [ -f /usr/share/evmapy/gamecontrollerdb.txt ]; then
    ln -sf /usr/share/evmapy/gamecontrollerdb.txt "${DATA_ROOT}/game_controller_db.txt"
elif [ -f /usr/share/SDL-GameControllerDB/gamecontrollerdb.txt ]; then
    ln -sf /usr/share/SDL-GameControllerDB/gamecontrollerdb.txt "${DATA_ROOT}/game_controller_db.txt"
fi

case "$(batocera-info 2>/dev/null | sed -n 's/^Board: //p')" in
    sm8250)
        export MESA_LOADER_DRIVER_OVERRIDE="${MESA_LOADER_DRIVER_OVERRIDE:-zink}"
        ;;
esac

exec /usr/bin/armsx2 \
    --app-root /usr/share/armsx2/assets \
    --data-root "${DATA_ROOT}" \
    "$1"
