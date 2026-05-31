#!/bin/sh

PIDFILE="/var/run/batocera-controlcenter.pid"
LAUNCHFILE="/var/run/batocera-controlcenter.started"

getCCPID() {
    X=$(cat "${PIDFILE}" 2>/dev/null)
    KEEP=""

    # valiate that the pid is still running
    if test -n "${X}" && test -e "/proc/${X}"; then
        KEEP="${X}"
    fi

    PIDS=$(pgrep -f '/usr/bin/batocera-controlcenter-app' 2>/dev/null | sort -n)
    if test -z "${KEEP}"; then
        for PID in ${PIDS}; do
            KEEP="${PID}"
        done
    fi

    test -z "${KEEP}" && return 1

    for PID in ${PIDS}; do
        if test "${PID}" != "${KEEP}"; then
            kill "${PID}" 2>/dev/null || true
        fi
    done

    if test -e "/proc/${KEEP}"; then
        echo "${KEEP}" >"${PIDFILE}"
        echo "${KEEP}"
        return 0
    fi

    return 1
}

setupDisplayEnv() {
    if test -z "${XDG_RUNTIME_DIR}" -o ! -d "${XDG_RUNTIME_DIR}"; then
        export XDG_RUNTIME_DIR="/var/run"
    fi

    BCC_DISPLAY="$(getLocalXDisplay)"
    if test -n "${BCC_DISPLAY}"; then
        export DISPLAY="${BCC_DISPLAY}"
    elif test -z "${DISPLAY}"; then
        export DISPLAY=":0"
    fi

    if [ -f "/etc/profile.d/wayland.sh" ]; then
        . /etc/profile.d/wayland.sh
    fi
    if { test -z "${SWAYSOCK}" || ! test -S "${SWAYSOCK}"; } && test -S "/var/run/sway-ipc.0.sock"; then
        export SWAYSOCK="/var/run/sway-ipc.0.sock"
    fi

    export GDK_BACKEND="x11"
    unset WAYLAND_DISPLAY
}

setupDisplayEnv

FLAGS=
test "$1" = "hidden" && FLAGS="--hidden"

NB_SCREENS=$(batocera-resolution listOutputs | wc -l)
if [ "$NB_SCREENS" -ge 2 ]; then
    COMP=$(batocera-resolution getDisplayComp)
    if test "$COMP" = "labwc"; then
        RC=/userdata/system/.config/labwc/rc.xml
        BCC_SCREEN=$(grep -A5 "Batocera Control Center" "$RC" | grep output | sed 's,.*<output>[[:space:]]*\([[:alnum:]_-][[:alnum:]_-]*\)[[:space:]]*</output>.*,\1,')
        RESO=$(batocera-resolution --screen "$BCC_SCREEN" currentResolution)
        FLAGS="$FLAGS --window $RESO"
    fi
fi
PIDVALUE=$(getCCPID)
if test "$?" -eq 0; then
    # don't toogle if the hidden argument is given
    if test "$1" != "hidden"; then
        NOW=$(date +%s)
        STARTED=$(cat "${LAUNCHFILE}" 2>/dev/null)
        GRACE="${BCC_TOGGLE_GRACE_SECONDS:-4}"
        case "${STARTED}${GRACE}" in
            *[!0-9]*)
                ;;
            *)
                if test $((NOW - STARTED)) -lt "${GRACE}"; then
                    exit 0
                fi
                ;;
        esac
        date +%s >"${LAUNCHFILE}"
        # toogle
        kill -10 "${PIDVALUE}"
    fi
else
    # switch on
    bccdisabled="$(/usr/bin/batocera-settings-get bcc.disabled)"
    bcclogs="$(/usr/bin/batocera-settings-get bcc.logs)"
    if test "$bccdisabled" != "1"; then
        export BCC_STARTUP_IGNORE_SECONDS="${BCC_STARTUP_IGNORE_SECONDS:-0.9}"
        export BCC_GAMEPAD_START_DELAY_SECONDS="${BCC_GAMEPAD_START_DELAY_SECONDS:-0.15}"
        export BCC_MAIN_BACK_CLOSE="${BCC_MAIN_BACK_CLOSE:-1}"

        if test "$bcclogs" = "1"; then
            CONTROLCENTER_DEBUG=1 batocera-controlcenter-app ${FLAGS} 20 >/dev/null &
            echo "$!" >"${PIDFILE}"
        else
            batocera-controlcenter-app ${FLAGS} 20 >/dev/null &
            echo "$!" >"${PIDFILE}"
        fi
        date +%s >"${LAUNCHFILE}"
    fi
fi
