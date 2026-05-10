#!/bin/sh

STATE_FILE="/var/run/batocera-dual-screen-backglass.cmd"
FLYCAST_VMU_STATE_FILE="/var/run/batocera-flycast-vmu-backglass.params"
DOLPHIN_GBA_PIDFILE="/var/run/batocera-dolphin-gba-bottom.pid"
PIDFILE="/var/run/batocera-backglass.pid"
PARAMSFILE="/var/run/batocera-backglass.params"

is_dual_screen_handheld() {
    [ "$(/usr/bin/batocera-settings-get-master display.position)" = "top-bottom" ] || return 1
    [ -n "$(/usr/bin/batocera-settings-get-master global.videooutput2)" ] && return 0
    [ "$(batocera-model 2>/dev/null)" = "Anbernic_RG_DS" ] && return 0
    tr '\0' '\n' < /sys/firmware/devicetree/base/compatible 2>/dev/null | grep -qx "anbernic,rg-ds"
}

is_dual_screen_emulator() {
    case "$2:$3:$4" in
        nds:drastic:drastic|nds:melonds:melonds|3ds:azahar:azahar|n3ds:azahar:azahar|wiiu:cemu:cemu)
            return 0
            ;;
    esac

    is_rgds_vertical_arcade_launch "$2" "$3" "$4" "$5"
}

is_rgds_vertical_arcade_core() {
    case "$1" in
        fbneo|fbalpha|mame|mame078plus|mame0139|mame0160|mamevirtual|imame4all)
            return 0
            ;;
    esac

    return 1
}

get_flycast_vmu_display() {
    local SYSTEM_NAME="$1"
    local GAME_NAME="$2"
    local MODE=""

    if [ -n "${GAME_NAME}" ]; then
        MODE="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}[\"${GAME_NAME}\"].flycast_vmu_display" 2>/dev/null)"
    fi

    [ -n "${MODE}" ] || MODE="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}.flycast_vmu_display" 2>/dev/null)"
    [ -n "${MODE}" ] || MODE="off"
    echo "${MODE}"
}

is_flycast_vmu_bottom_launch() {
    local SYSTEM_NAME="$1"
    local EMULATOR_NAME="$2"
    local CORE_NAME="$3"
    local GAME_PATH="$4"
    local GAME_NAME
    local MODE

    [ "${EMULATOR_NAME}" = "flycast" ] || return 1
    [ "${CORE_NAME}" = "flycast" ] || return 1

    GAME_NAME="${GAME_PATH##*/}"
    MODE="$(get_flycast_vmu_display "${SYSTEM_NAME}" "${GAME_NAME}")"
    [ "${MODE}" = "bottom" ]
}

get_dolphin_gba_screen() {
    local SYSTEM_NAME="$1"
    local GAME_NAME="$2"
    local MODE=""

    if [ -n "${GAME_NAME}" ]; then
        MODE="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}[\"${GAME_NAME}\"].dolphin_gba_screen" 2>/dev/null)"
    fi

    [ -n "${MODE}" ] || MODE="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}.dolphin_gba_screen" 2>/dev/null)"
    [ -n "${MODE}" ] || MODE="main"
    echo "${MODE}"
}

is_dolphin_gba_bottom_launch() {
    local SYSTEM_NAME="$1"
    local EMULATOR_NAME="$2"
    local CORE_NAME="$3"
    local GAME_PATH="$4"
    local GAME_NAME
    local MODE

    [ "${EMULATOR_NAME}" = "dolphin" ] || return 1
    [ "${CORE_NAME}" = "dolphin" ] || return 1

    GAME_NAME="${GAME_PATH##*/}"
    MODE="$(get_dolphin_gba_screen "${SYSTEM_NAME}" "${GAME_NAME}")"
    [ "${MODE}" = "bottom" ]
}

setup_sway_env() {
    if command -v getLocalWaylandDisplay >/dev/null 2>&1; then
        WAYLAND_DISPLAY_VALUE="$(getLocalWaylandDisplay 2>/dev/null)"
    fi

    [ -n "${WAYLAND_DISPLAY_VALUE}" ] || WAYLAND_DISPLAY_VALUE="${WAYLAND_DISPLAY:-wayland-1}"
    for runtime in /var/run/0-runtime-dir /run/0-runtime-dir /run/user/0 /run/user/1000; do
        if [ -S "${runtime}/${WAYLAND_DISPLAY_VALUE}" ]; then
            export XDG_RUNTIME_DIR="${runtime}"
            break
        fi
    done

    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/run/0-runtime-dir}"
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY_VALUE}"
    export XDG_SESSION_TYPE=wayland
    export XDG_CURRENT_DESKTOP=sway
    export SWAYSOCK="${SWAYSOCK:-${XDG_RUNTIME_DIR}/sway-ipc.0.sock}"
    export I3SOCK="${I3SOCK:-$SWAYSOCK}"
}

get_bottom_panel_info() {
    [ "$(batocera-settings-get-master display.position 2>/dev/null)" = "top-bottom" ] || return 1
    [ "$(batocera-resolution getDisplayComp 2>/dev/null)" = "sway" ] || return 1
    command -v swaymsg >/dev/null 2>&1 || return 1
    command -v jq >/dev/null 2>&1 || return 1

    swaymsg -t get_outputs 2>/dev/null | jq -r '
        ((map(select(.active and .name == "DSI-1"))[0]) //
        (map(select(.active)) | sort_by(.rect.y, .rect.x) | .[1])) |
        select(. != null) |
        [.current_workspace, .rect.x, .rect.y, .rect.width, .rect.height] | @tsv
    '
}

move_dolphin_gba_window_to_bottom() {
    local BOTTOM_INFO BOTTOM_WORKSPACE GBA_X GBA_Y GBA_WIDTH GBA_HEIGHT
    local CRITERIA

    setup_sway_env
    BOTTOM_INFO="$(get_bottom_panel_info)" || return 0
    BOTTOM_WORKSPACE="$(echo "${BOTTOM_INFO}" | awk '{ print $1 }')"
    GBA_X="$(echo "${BOTTOM_INFO}" | awk '{ print $2 }')"
    GBA_Y="$(echo "${BOTTOM_INFO}" | awk '{ print $3 }')"
    GBA_WIDTH="$(echo "${BOTTOM_INFO}" | awk '{ print $4 }')"
    GBA_HEIGHT="$(echo "${BOTTOM_INFO}" | awk '{ print $5 }')"
    [ -n "${BOTTOM_WORKSPACE}" ] || return 0
    [ -n "${GBA_X}" ] || GBA_X=0
    [ -n "${GBA_Y}" ] || GBA_Y=480
    [ -n "${GBA_WIDTH}" ] || GBA_WIDTH=640
    [ -n "${GBA_HEIGHT}" ] || GBA_HEIGHT=480

    swaymsg -t get_tree 2>/dev/null | jq -e '
        .. | objects |
        select((.name? // "") | test("^GBA[1-4]"))
    ' >/dev/null 2>&1 || return 0

    CRITERIA='[title="^GBA[1-4].*"]'
    swaymsg "${CRITERIA} fullscreen disable" >/dev/null 2>&1 || true
    swaymsg "${CRITERIA} floating enable" >/dev/null 2>&1 || true
    swaymsg "${CRITERIA} border none" >/dev/null 2>&1 || true
    swaymsg "${CRITERIA} resize set width ${GBA_WIDTH} px height ${GBA_HEIGHT} px" >/dev/null 2>&1 || true
    swaymsg "${CRITERIA} move to workspace ${BOTTOM_WORKSPACE}" >/dev/null 2>&1 || true
    swaymsg "${CRITERIA} move position ${GBA_X} ${GBA_Y}" >/dev/null 2>&1 || true
}

start_dolphin_gba_bottom_watcher() {
    stop_dolphin_gba_bottom_watcher
    touch "$DOLPHIN_GBA_PIDFILE"
    (
        while [ -f "$DOLPHIN_GBA_PIDFILE" ]; do
            move_dolphin_gba_window_to_bottom
            sleep 0.5
        done
    ) >/dev/null 2>&1 &
    echo "$!" > "$DOLPHIN_GBA_PIDFILE"
}

stop_dolphin_gba_bottom_watcher() {
    if [ -f "$DOLPHIN_GBA_PIDFILE" ]; then
        kill "$(cat "$DOLPHIN_GBA_PIDFILE" 2>/dev/null)" 2>/dev/null || true
        rm -f "$DOLPHIN_GBA_PIDFILE"
    fi
}

get_rgds_vertical_mode() {
    local SYSTEM_NAME="$1"
    local GAME_NAME="$2"
    local MODE=""

    if [ -n "${GAME_NAME}" ]; then
        MODE="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}[\"${GAME_NAME}\"].rgds_vertical_mode" 2>/dev/null)"
    fi

    [ -n "${MODE}" ] || MODE="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}.rgds_vertical_mode" 2>/dev/null)"
    [ -n "${MODE}" ] || MODE="auto"
    echo "${MODE}"
}

is_vertical_arcade_rom() {
    local ROM_STEM="$1"

    case "${ROM_STEM}" in
        punchout*|spnchout*|pc_*|mp_*)
            return 0
            ;;
    esac

    grep -q "id=\"${ROM_STEM}\".*vert=\"true\"" /usr/share/emulationstation/resources/arcaderoms.xml 2>/dev/null
}

is_rgds_vertical_arcade_launch() {
    local SYSTEM_NAME="$1"
    local EMULATOR_NAME="$2"
    local CORE_NAME="$3"
    local GAME_PATH="$4"
    local GAME_NAME
    local ROM_STEM
    local MODE

    [ "${EMULATOR_NAME}" = "libretro" ] || return 1
    is_rgds_vertical_arcade_core "${CORE_NAME}" || return 1

    GAME_NAME="${GAME_PATH##*/}"
    ROM_STEM="${GAME_NAME%.*}"
    MODE="$(get_rgds_vertical_mode "${SYSTEM_NAME}" "${GAME_NAME}")"

    case "${MODE}" in
        off|disabled|0)
            return 1
            ;;
        force|always|1)
            return 0
            ;;
    esac

    is_vertical_arcade_rom "${ROM_STEM}"
}

capture_backglass_cmd() {
    local pid
    pid="$(pgrep -f '/usr/bin/batocera-backglass-window' | head -n1)" || return 1
    [ -n "$pid" ] || return 1

    python3 - "$pid" "$STATE_FILE" <<'PY2'
import pathlib
import shlex
import sys

pid, out = sys.argv[1], sys.argv[2]
argv = pathlib.Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
args = [item.decode() for item in argv if item]
if args:
    pathlib.Path(out).write_text(shlex.join(args) + "\n")
PY2
}

stop_backglass() {
    capture_backglass_cmd || true
    if [ -f "$PARAMSFILE" ] && command -v batocera-backglass >/dev/null 2>&1; then
        batocera-backglass disable >/dev/null 2>&1 || true
        return 0
    fi
    pkill -f '/usr/bin/batocera-backglass-window' || true
    rm -f "$PIDFILE"
}

restore_backglass() {
    pgrep -f '/usr/bin/batocera-backglass-window' >/dev/null && return 0

    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/run/0-runtime-dir}"
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
    export SWAYSOCK="${SWAYSOCK:-/var/run/0-runtime-dir/sway-ipc.0.sock}"
    export I3SOCK="${I3SOCK:-$SWAYSOCK}"

    if [ -f "$PARAMSFILE" ] && command -v batocera-backglass >/dev/null 2>&1; then
        batocera-backglass restart >/dev/null 2>&1 || true
    elif [ -f "$STATE_FILE" ]; then
        sh -c "$(cat "$STATE_FILE")" >/dev/null 2>&1 &
        echo "$!" > "$PIDFILE"
    fi

    rm -f "$STATE_FILE"
}

switch_flycast_vmu_backglass() {
    local X Y WIDTH HEIGHT THEME BOTTOM_INFO

    command -v batocera-backglass >/dev/null 2>&1 || return 1

    if [ -f "$PARAMSFILE" ]; then
        read X Y WIDTH HEIGHT THEME < "$PARAMSFILE"
    else
        setup_sway_env
        BOTTOM_INFO="$(get_bottom_panel_info)" || return 1
        X="$(echo "${BOTTOM_INFO}" | awk '{ print $2 }')"
        Y="$(echo "${BOTTOM_INFO}" | awk '{ print $3 }')"
        WIDTH="$(echo "${BOTTOM_INFO}" | awk '{ print $4 }')"
        HEIGHT="$(echo "${BOTTOM_INFO}" | awk '{ print $5 }')"
        THEME="$(/usr/bin/batocera-settings-get-master backglass.theme 2>/dev/null)"
        [ -n "$THEME" ] || THEME="auto"
    fi

    [ -n "$X" ] && [ -n "$Y" ] && [ -n "$WIDTH" ] && [ -n "$HEIGHT" ] || return 1

    echo "$X $Y $WIDTH $HEIGHT $THEME" > "$FLYCAST_VMU_STATE_FILE"
    rm -f /var/run/flycast-vmu-*.raw /var/run/flycast-vmu.status 2>/dev/null || true
    batocera-backglass disable >/dev/null 2>&1 || true
    batocera-backglass enable "$X" "$Y" "$WIDTH" "$HEIGHT" backglass-flycast-vmu >/dev/null 2>&1 || true
}

restore_flycast_vmu_backglass() {
    local X Y WIDTH HEIGHT THEME

    [ -f "$FLYCAST_VMU_STATE_FILE" ] || return 1
    command -v batocera-backglass >/dev/null 2>&1 || return 1

    read X Y WIDTH HEIGHT THEME < "$FLYCAST_VMU_STATE_FILE"
    rm -f "$FLYCAST_VMU_STATE_FILE"
    [ -n "$X" ] && [ -n "$Y" ] && [ -n "$WIDTH" ] && [ -n "$HEIGHT" ] || return 1

    batocera-backglass disable >/dev/null 2>&1 || true
    batocera-backglass enable "$X" "$Y" "$WIDTH" "$HEIGHT" "$THEME" >/dev/null 2>&1 || true
}

case "$1" in
    gameStart)
        if is_dual_screen_handheld && is_dual_screen_emulator "$@"; then
            stop_backglass
        elif is_dual_screen_handheld && is_flycast_vmu_bottom_launch "$2" "$3" "$4" "$5"; then
            switch_flycast_vmu_backglass
        elif is_dual_screen_handheld && is_dolphin_gba_bottom_launch "$2" "$3" "$4" "$5"; then
            stop_backglass
            start_dolphin_gba_bottom_watcher
        fi
        ;;
    gameStop)
        stop_dolphin_gba_bottom_watcher
        restore_flycast_vmu_backglass || restore_backglass
        ;;
esac

exit 0
