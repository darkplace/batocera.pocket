#!/bin/sh

#EVENTS="game-selected system-selected game-start game-end screensaver-start screensaver-stop"
EVENTS="game-selected system-selected"
PIDFILE="/var/run/batocera-backglass.pid"
PARAMSFILE="/var/run/batocera-backglass.params"
KODIPIDFILE="/var/run/batocera-lower-screen-kodi.pid"
KODILOGFILE="/var/log/batocera-lower-screen-kodi.log"

# unset these variables while they causes issues on my side for webkit
export WEBKIT_DISABLE_DMABUF_RENDERER=1
export __GLX_VENDOR_LIBRARY_NAME=
export __NV_PRIME_RENDER_OFFLOAD=
export __VK_LAYER_NV_optimus=

do_help() {
    echo "${1} enable <x> <y> <width> <height> <http location|theme>" >&2
    echo "${1} enable" >&2
    echo "${1} enable <http location|theme>" >&2
    echo "${1} restart" >&2
    echo "${1} restart <http location|theme>" >&2
    echo "${1} disable" >&2
    echo "${1} location <http location|theme name|empty for the default theme>" >&2
}

ACTION=$1
if test -z "${ACTION}"
then
    do_help "${0}"
    exit 1
fi

shift

isRunning() {
    if test -e "${PIDFILE}"; then
	pid="$(tr -dc 0-9 < "${PIDFILE}" 2>/dev/null)"
	if test -n "${pid}" -a -e "/proc/${pid}/cmdline"; then
	    if tr '\0' ' ' < "/proc/${pid}/cmdline" | grep -q "batocera-backglass-window"; then
		return 0
	    fi
	fi
	rm -f "${PIDFILE}"
	return 1
    else
	return 1
    fi
}

apiCall() {
    curl --http0.9 --silent --show-error --max-time 2 "$@"
}

getUrl() {
    THEME=$1
    test -z "${THEME}" && THEME=backglass-default

    # allow http:// or https:// urls
    if echo "${THEME}" | grep -qE '^http://|^https://'
    then
	THEMEPATH=${THEME}
    else
	THEMEPATH="/userdata/system/backglass/${THEME}/index.htm"
	if ! test -e "${THEMEPATH}"
	then
	    THEMEPATH="/usr/share/batocera-backglass/www/${THEME}/index.htm"
	fi

	# not found => the default one
	if ! test -e "${THEMEPATH}"
	then
	    THEMEPATH="/usr/share/batocera-backglass/www/backglass-default/index.htm"
	fi
    fi
    echo "${THEMEPATH}"
}

isSpecialTheme() {
    case "$1" in
	none|kodi)
	    return 0
	    ;;
    esac

    return 1
}

setupGuiEnv() {
    # Thor's backglass window is GTK/X11-backed. Keep Xwayland available while
    # also exporting the sway socket for output discovery.
    if test -S /tmp/.X11-unix/X0 -o -S /var/run/.X11-unix/X0; then
        export DISPLAY="${DISPLAY:-:0}"
    fi

    for socket in /var/run/sway-ipc.0.sock /run/sway-ipc.0.sock /var/run/0-runtime-dir/sway-ipc.0.sock /run/0-runtime-dir/sway-ipc.0.sock; do
        if test -S "${socket}"; then
            export SWAYSOCK="${socket}"
            export I3SOCK="${socket}"
            break
        fi
    done

    WAYLAND_DISPLAY_VALUE=$(getLocalWaylandDisplay 2>/dev/null)
    if test -n "${WAYLAND_DISPLAY_VALUE}"; then
        for runtime in /var/run/0-runtime-dir /run/0-runtime-dir /run/user/0 /run/user/1000; do
            if test -S "${runtime}/${WAYLAND_DISPLAY_VALUE}"; then
                export XDG_RUNTIME_DIR="${runtime}"
                break
            fi
        done
        export WAYLAND_DISPLAY="${WAYLAND_DISPLAY_VALUE}"
        export XDG_SESSION_TYPE=wayland
        export XDG_CURRENT_DESKTOP=sway
        if test -z "${SWAYSOCK}" -a -S "${XDG_RUNTIME_DIR}/sway-ipc.0.sock"; then
            export SWAYSOCK="${XDG_RUNTIME_DIR}/sway-ipc.0.sock"
            export I3SOCK="${SWAYSOCK}"
        fi
    fi
}

getBottomPanelInfo() {
    test "$(batocera-settings-get-master display.position 2>/dev/null)" = "top-bottom" || return 1
    test "$(batocera-resolution getDisplayComp 2>/dev/null)" = "sway" || return 1
    command -v swaymsg >/dev/null 2>&1 || return 1
    command -v jq >/dev/null 2>&1 || return 1

    swaymsg -t get_outputs 2>/dev/null | jq -r '
        ((map(select(.active and .name == "DSI-1"))[0]) //
        (map(select(.active)) | sort_by(.rect.y, .rect.x) | .[1])) |
        select(. != null) |
        [.current_workspace, .rect.x, .rect.y, .rect.width, .rect.height] | @tsv
    '
}

moveKodiToBottomPanel() {
    setupGuiEnv
    BOTTOM_INFO=$(getBottomPanelInfo) || return 0
    BOTTOM_WORKSPACE=$(echo "${BOTTOM_INFO}" | awk '{ print $1 }')
    KODI_X=$(echo "${BOTTOM_INFO}" | awk '{ print $2 }')
    KODI_Y=$(echo "${BOTTOM_INFO}" | awk '{ print $3 }')
    KODI_WIDTH=$(echo "${BOTTOM_INFO}" | awk '{ print $4 }')
    KODI_HEIGHT=$(echo "${BOTTOM_INFO}" | awk '{ print $5 }')
    test -n "${BOTTOM_WORKSPACE}" || return 0
    test -n "${KODI_X}" || KODI_X=0
    test -n "${KODI_Y}" || KODI_Y=480
    test -n "${KODI_WIDTH}" || KODI_WIDTH=640
    test -n "${KODI_HEIGHT}" || KODI_HEIGHT=480

    i=0
    while test "${i}" -lt 80; do
        if swaymsg -t get_tree 2>/dev/null | jq -e '
            .. | objects |
            select(((.app_id? // "") | ascii_downcase) == "kodi" or
                   ((.name? // "") | ascii_downcase | contains("kodi")))
        ' >/dev/null 2>&1; then
            break
        fi
        i=$((i + 1))
        sleep 0.1
    done

    for CRITERIA in '[app_id="Kodi"]' '[app_id="kodi"]' '[title="Kodi"]'; do
        swaymsg "${CRITERIA} fullscreen disable" >/dev/null 2>&1 || true
        swaymsg "${CRITERIA} floating enable" >/dev/null 2>&1 || true
        swaymsg "${CRITERIA} resize set width ${KODI_WIDTH} px height ${KODI_HEIGHT} px" >/dev/null 2>&1 || true
        swaymsg "${CRITERIA} move to workspace ${BOTTOM_WORKSPACE}" >/dev/null 2>&1 || true
        swaymsg "${CRITERIA} move position ${KODI_X} ${KODI_Y}" >/dev/null 2>&1 || true
        swaymsg "${CRITERIA} fullscreen enable" >/dev/null 2>&1 || true
    done
}

stopKodiWidget() {
    if test -p /var/run/kodi.msg; then
        echo "EXIT" > /var/run/kodi.msg 2>/dev/null || true
        sleep 1
    fi

    if test -f "${KODIPIDFILE}"; then
        KODIPID=$(tr -dc 0-9 < "${KODIPIDFILE}" 2>/dev/null)
        test -n "${KODIPID}" && kill "${KODIPID}" 2>/dev/null || true
        rm -f "${KODIPIDFILE}"
    fi

    pkill -f '/usr/lib/kodi/kodi.bin' 2>/dev/null || true
}

startKodiWidget() {
    setupGuiEnv
    stopKodiWidget

    BOTTOM_INFO=$(getBottomPanelInfo) || BOTTOM_INFO=
    BOTTOM_WORKSPACE=$(echo "${BOTTOM_INFO}" | awk '{ print $1 }')
    test -n "${BOTTOM_WORKSPACE}" && swaymsg workspace "${BOTTOM_WORKSPACE}" >/dev/null 2>&1 || true

    export KODI_TOUCH_ONLY=1
    export KODI_BOTTOM_WIDGET=1
    batocera-kodilauncher >"${KODILOGFILE}" 2>&1 &
    echo "$!" > "${KODIPIDFILE}"
    moveKodiToBottomPanel &
}

stopSpecialTheme() {
    case "$1" in
	control-center)
	    batocera-controlcenter hidden >/dev/null 2>&1 &
	    return 0
	    ;;
	kodi)
	    stopKodiWidget
	    return 0
	    ;;
    esac
}

startSpecialTheme() {
    case "$1" in
	none)
	    return 0
	    ;;
	kodi)
	    startKodiWidget
	    return 0
	    ;;
    esac
}

restartSpecialTheme() {
    case "$1" in
	none)
	    return 0
	    ;;
	kodi)
	    startKodiWidget
	    return 0
	    ;;
    esac
}

addHooks() {
    for EVT in ${EVENTS}
    do
        mkdir -p /var/run/emulationstation/scripts/${EVT} || exit 1
        ln -sf /usr/share/batocera-backglass/scripts/${EVT}.sh /var/run/emulationstation/scripts/${EVT}/batocera-backglass.sh || exit 1
    done
}

removeHooks() {
    for EVT in ${EVENTS}
    do
        unlink /var/run/emulationstation/scripts/${EVT}/batocera-backglass.sh 2>/dev/null || true
    done
}

case "${ACTION}" in
    "location")
	LURL=$(getUrl "${1}")
	apiCall "http://localhost:2033/location?url=${LURL}"
	;;

    "enable")
	if isRunning
	then
	    echo "batocera-backglass is already running" >&2
	    exit 1
	fi

	if test $# -le 1 -a -f "${PARAMSFILE}" # ok, we can reuse the last used parameters (to make easy restart)
	then
	    read X Y WIDTH HEIGHT THEME < "${PARAMSFILE}"
	else
	    #
	    X=$1
	    Y=$2
	    WIDTH=$3
	    HEIGHT=$4
	    THEME=$5 # can be empty
	    shift
	    shift
	    shift
	    shift
	    if test -z "${X}" -o -z "${Y}" -o -z "${WIDTH}" -o -z "${HEIGHT}"
	    then
		echo "${0} X Y WIDTH HEIGHT"
		exit 1
	    fi
	    echo "${X} ${Y} ${WIDTH} ${HEIGHT} ${THEME}" > "${PARAMSFILE}" || exit 1
	fi

	if isSpecialTheme "${THEME}"
	then
	    startSpecialTheme "${THEME}"
	    exit 0
	fi

	### theme
	THEMEPATH=$(getUrl "${THEME}")
	###

	setupGuiEnv
	batocera-backglass-window --x "${X}" --y "${Y}" --width "${WIDTH}" --height "${HEIGHT}" --www "${THEMEPATH}" >/var/log/batocera-backglass-window.log 2>&1 &
	echo "$!" > "${PIDFILE}"

	# add hooks
	addHooks
    ;;

    "disable")
	if isRunning
	then
	    kill -15 $(cat "${PIDFILE}")
	    rm -f "${PIDFILE}"
	else
	    if test -f "${PARAMSFILE}"
	    then
		read X Y WIDTH HEIGHT THEME < "${PARAMSFILE}"
		if isSpecialTheme "${THEME}"
		then
		    stopSpecialTheme "${THEME}"
		    exit 0
		fi
	    fi
	    echo "batocera-backglass is already disabled" >&2
	    exit 1
	fi

	# remove hooks
	removeHooks
	;;

    "restart")
	if isRunning
	then
	    kill -15 $(cat "${PIDFILE}")
	    rm -f "${PIDFILE}"
	fi

	if test -f "${PARAMSFILE}"
	then
	    read X Y WIDTH HEIGHT OLD_THEME < "${PARAMSFILE}"
	    stopSpecialTheme "${OLD_THEME}"
	fi

	# reread theme from configuration in case it changed
	THEME=$(batocera-settings-get backglass.theme)
	echo "${X} ${Y} ${WIDTH} ${HEIGHT} ${THEME}" > "${PARAMSFILE}" || exit 1

	if isSpecialTheme "${THEME}"
	then
	    restartSpecialTheme "${THEME}"
	    exit 0
	fi

	THEMEPATH=$(getUrl "${THEME}")

	setupGuiEnv
	batocera-backglass-window --x "${X}" --y "${Y}" --width "${WIDTH}" --height "${HEIGHT}" --www "${THEMEPATH}" >/var/log/batocera-backglass-window.log 2>&1 &
	echo "$!" > "${PIDFILE}"
	addHooks
    ;;

    "list-themes")
	(echo kodi; ls /usr/share/batocera-backglass/www; ls /userdata/system/backglass) 2>/dev/null | grep -viE '^systems$' | sort -u
	;;
esac
