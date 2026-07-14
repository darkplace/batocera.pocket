#!/bin/sh

GMUPATH="/userdata/system/configs/gmu"
GMUCONFIG="${GMUPATH}/gmu.conf"
GMUINPUT="${GMUPATH}/gmuinput.conf"
MUSICDIR="/userdata/roms/music"
LOGDIR="/userdata/system/logs"

mkdir -p "${GMUPATH}" "${MUSICDIR}" "${LOGDIR}"

if [ ! -f "${GMUCONFIG}" ]; then
    cp /usr/share/gmu/batocera/gmu.conf "${GMUCONFIG}"
fi

cp /usr/share/gmu/batocera/gmuinput.conf "${GMUINPUT}"
sed -i \
    -e "s~^SDL.InputConfigFile=.*~SDL.InputConfigFile=${GMUINPUT}~" \
    -e "s~^SDL.KeyMap=.*~SDL.KeyMap=batocera.keymap~" \
    "${GMUCONFIG}"

resolution="$(batocera-resolution currentResolution 2>/dev/null || true)"
case "${resolution}" in
    *x*)
        width="${resolution%x*}"
        height="${resolution#*x}"
        ;;
    *)
        width=1280
        height=720
        ;;
esac

sed -i \
    -e "s~^SDL.Height=.*~SDL.Height=${height}~" \
    -e "s~^SDL.Width=.*~SDL.Width=${width}~" \
    "${GMUCONFIG}"

if [ "${width}" -le 1024 ]; then
    sed -i \
        -e "s~^SDL.DefaultSkin=.*~SDL.DefaultSkin=default-modern~" \
        -e "s~^SDL.Fullscreen=.*~SDL.Fullscreen=no~" \
        "${GMUCONFIG}"
else
    sed -i \
        -e "s~^SDL.DefaultSkin=.*~SDL.DefaultSkin=default-modern-large~" \
        -e "s~^SDL.Fullscreen=.*~SDL.Fullscreen=yes~" \
        "${GMUCONFIG}"
fi

cd /usr/share/gmu || exit 1

if [ -n "${1:-}" ] && [ -f "$1" ]; then
    exec /usr/bin/gmu.bin -d /usr/etc/gmu -c "${GMUCONFIG}" "$1"
fi

exec /usr/bin/gmu.bin -d /usr/etc/gmu -c "${GMUCONFIG}"
