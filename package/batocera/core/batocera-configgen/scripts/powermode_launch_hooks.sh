#!/bin/bash

STATE_DIR="/var/run/batocera-emulator-performance"
UCLAMP_WATCHER_PID="${STATE_DIR}/uclamp-watcher.pid"
ES_AUDIO_STATE="${STATE_DIR}/es-audio-sink-inputs"
BACKGLASS_STATE="${STATE_DIR}/backglass-disabled"
CPU_LIMIT_HELPER="/usr/bin/batocera-cpu-limit"
CPU_LIMIT_FPS_DIR="/var/run/batocera-cpu-limit/fps"
CPU_LIMIT_GAMESCOPE_FPS_PIPE="/var/run/batocera-cpu-limit/gamescope-stats.pipe"

HAS_CPUFREQ=0
if [ -e /sys/devices/system/cpu/cpufreq/policy0/scaling_governor ] &&
   [ -e /sys/devices/system/cpu/cpufreq/policy0/scaling_available_governors ]; then
    HAS_CPUFREQ=1
fi

ensure_state_dir() {
    mkdir -p "${STATE_DIR}"
}

check_governor() {
    local GOVERNOR_TO_CHECK="$1"
    local AVAILABLE_GOVERNORS

    [ "${HAS_CPUFREQ}" = "1" ] || return 1

    AVAILABLE_GOVERNORS="$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_available_governors 2>/dev/null)"

    [[ " ${AVAILABLE_GOVERNORS} " =~ [[:space:]]${GOVERNOR_TO_CHECK}[[:space:]] ]]
}

set_governor() {
    local GOVERNOR_NAME="$1"

    [ "${HAS_CPUFREQ}" = "1" ] || return 0

    for policy in /sys/devices/system/cpu/cpufreq/policy*; do
        if [ -e "${policy}/scaling_governor" ]; then
            echo "${GOVERNOR_NAME}" > "${policy}/scaling_governor" 2>/dev/null || true
        fi
    done
}

apply_cpu_profile() {
    local CPU_PROFILE="$1"

    case "${CPU_PROFILE}" in
        ""|"default"|"auto")
            return 0
            ;;
        "max"|"performance")
            check_governor "performance" && set_governor "performance"
            ;;
        "powersave")
            check_governor "powersave" && set_governor "powersave"
            ;;
        "schedutil")
            check_governor "schedutil" && set_governor "schedutil"
            ;;
        "ondemand")
            check_governor "ondemand" && set_governor "ondemand"
            ;;
        "balanced")
            if check_governor "schedutil"; then
                set_governor "schedutil"
            elif check_governor "ondemand"; then
                set_governor "ondemand"
            elif check_governor "conservative"; then
                set_governor "conservative"
            fi
            ;;
    esac
}

get_cpu_profile() {
    local SYSTEM_NAME="$1"
    local GAME_NAME="$2"
    local CPU_PROFILE=""

    if [ -n "${GAME_NAME}" ]; then
        CPU_PROFILE="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}[\"${GAME_NAME}\"].cpu_profile")"
    fi

    if [ -z "${CPU_PROFILE}" ] && [ -n "${SYSTEM_NAME}" ]; then
        CPU_PROFILE="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}.cpu_profile")"
    fi

    if [ -z "${CPU_PROFILE}" ]; then
        CPU_PROFILE="$(/usr/bin/batocera-settings-get-master global.cpu_profile)"
    fi

    echo "${CPU_PROFILE}"
}

get_cpu_max_freq() {
    local SYSTEM_NAME="$1"
    local GAME_NAME="$2"
    local CPU_MAX_FREQ=""

    if [ -n "${GAME_NAME}" ]; then
        CPU_MAX_FREQ="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}[\"${GAME_NAME}\"].cpu_max_freq" 2>/dev/null)"
        [ "${CPU_MAX_FREQ}" = "auto" ] && CPU_MAX_FREQ=""
    fi

    if [ -z "${CPU_MAX_FREQ}" ] && [ -n "${SYSTEM_NAME}" ]; then
        CPU_MAX_FREQ="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}.cpu_max_freq" 2>/dev/null)"
        [ "${CPU_MAX_FREQ}" = "auto" ] && CPU_MAX_FREQ=""
    fi

    if [ -z "${CPU_MAX_FREQ}" ]; then
        CPU_MAX_FREQ="$(/usr/bin/batocera-settings-get-master global.cpu_max_freq 2>/dev/null)"
    fi

    echo "${CPU_MAX_FREQ:-auto}"
}

get_cpu_limit_target_fps() {
    local SYSTEM_NAME="$1"
    local GAME_NAME="$2"
    local TARGET_FPS=""

    if [ -n "${GAME_NAME}" ]; then
        TARGET_FPS="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}[\"${GAME_NAME}\"].cpu_limit_target_fps" 2>/dev/null)"
        [ "${TARGET_FPS}" = "auto" ] && TARGET_FPS=""
    fi

    if [ -z "${TARGET_FPS}" ] && [ -n "${SYSTEM_NAME}" ]; then
        TARGET_FPS="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}.cpu_limit_target_fps" 2>/dev/null)"
        [ "${TARGET_FPS}" = "auto" ] && TARGET_FPS=""
    fi

    if [ -z "${TARGET_FPS}" ]; then
        TARGET_FPS="$(/usr/bin/batocera-settings-get-master global.cpu_limit_target_fps 2>/dev/null)"
    fi

    echo "${TARGET_FPS:-auto}"
}

apply_cpu_limit() {
    local CPU_MAX_FREQ="$1"
    local TARGET_FPS="$2"
    local SYSTEM_NAME="$3"
    local FPS_PATH="${CPU_LIMIT_FPS_DIR}"

    [ -x "${CPU_LIMIT_HELPER}" ] || return 0
    [ "${SYSTEM_NAME}" = "steam" ] && FPS_PATH="${CPU_LIMIT_GAMESCOPE_FPS_PIPE}"
    "${CPU_LIMIT_HELPER}" game-start "${CPU_MAX_FREQ:-auto}" "${FPS_PATH}" "${TARGET_FPS:-auto}" >/dev/null 2>&1 || true
}

restore_cpu_limit() {
    [ -x "${CPU_LIMIT_HELPER}" ] || return 0
    "${CPU_LIMIT_HELPER}" game-stop >/dev/null 2>&1 || true
}

uclamp_profile_values() {
    local CPU_PROFILE="$1"

    case "${CPU_PROFILE}" in
        "max")
            echo "80 100 -10"
            ;;
        "performance")
            echo "60 100 -5"
            ;;
    esac
}

candidate_process_names() {
    local SYSTEM_NAME="$1"
    local EMULATOR_NAME="$2"
    local CORE_NAME="$3"

    case "${EMULATOR_NAME}:${CORE_NAME}:${SYSTEM_NAME}" in
        libretro:*)
            echo "retroarch"
            ;;
        azahar:*|*:azahar:*|*:azahar)
            echo "azahar"
            ;;
        melonds:*|*:melonds:*|*:melonds)
            echo "melonDS melonds"
            ;;
        flycast:*|*:flycast:*|*:flycast)
            echo "flycast"
            ;;
        dolphin*|*:dolphin:*|*:dolphin)
            echo "dolphin-emu dolphin-nogui dolphin-emu-nogui"
            ;;
        ppsspp:*|*:ppsspp:*|*:ppsspp)
            echo "PPSSPP PPSSPPSDL"
            ;;
        duckstation:*|*:swanstation:*|*:duckstation:*|*:duckstation)
            echo "duckstation"
            ;;
        *)
            echo "${EMULATOR_NAME} ${CORE_NAME}"
            ;;
    esac
}

emulator_pids() {
    local SYSTEM_NAME="$1"
    local EMULATOR_NAME="$2"
    local CORE_NAME="$3"
    local NAME

    for NAME in $(candidate_process_names "${SYSTEM_NAME}" "${EMULATOR_NAME}" "${CORE_NAME}"); do
        [ -n "${NAME}" ] || continue
        pidof "${NAME}" 2>/dev/null || true
    done | tr ' ' '\n' | sed '/^$/d' | sort -u
}

apply_uclamp_to_pid() {
    local PID="$1"
    local UCLAMP_MIN="$2"
    local UCLAMP_MAX="$3"
    local NICE_VALUE="$4"
    local TASK
    local TID

    [ -d "/proc/${PID}" ] || return 0

    if command -v uclampset >/dev/null 2>&1; then
        uclampset -p -m "${UCLAMP_MIN}" -M "${UCLAMP_MAX}" "${PID}" >/dev/null 2>&1 || true
        for TASK in /proc/"${PID}"/task/*; do
            [ -e "${TASK}" ] || continue
            TID="${TASK##*/}"
            uclampset -p -m "${UCLAMP_MIN}" -M "${UCLAMP_MAX}" "${TID}" >/dev/null 2>&1 || true
        done
    fi

    renice -n "${NICE_VALUE}" -p "${PID}" >/dev/null 2>&1 || true
}

stop_uclamp_watcher() {
    if [ -s "${UCLAMP_WATCHER_PID}" ]; then
        kill "$(cat "${UCLAMP_WATCHER_PID}")" >/dev/null 2>&1 || true
        rm -f "${UCLAMP_WATCHER_PID}"
    fi
}

start_uclamp_watcher() {
    local CPU_PROFILE="$1"
    local SYSTEM_NAME="$2"
    local EMULATOR_NAME="$3"
    local CORE_NAME="$4"
    local VALUES
    local UCLAMP_MIN
    local UCLAMP_MAX
    local NICE_VALUE

    VALUES="$(uclamp_profile_values "${CPU_PROFILE}")"
    [ -n "${VALUES}" ] || return 0

    read -r UCLAMP_MIN UCLAMP_MAX NICE_VALUE <<EOF
${VALUES}
EOF

    ensure_state_dir
    stop_uclamp_watcher

    (
        COUNT=0
        while [ "${COUNT}" -lt 45 ]; do
            for PID in $(emulator_pids "${SYSTEM_NAME}" "${EMULATOR_NAME}" "${CORE_NAME}"); do
                [ "${PID}" != "$$" ] || continue
                apply_uclamp_to_pid "${PID}" "${UCLAMP_MIN}" "${UCLAMP_MAX}" "${NICE_VALUE}"
            done
            COUNT=$((COUNT + 1))
            sleep 1
        done
    ) >/dev/null 2>&1 &

    echo "$!" > "${UCLAMP_WATCHER_PID}"
}

es_sink_inputs() {
    command -v pactl >/dev/null 2>&1 || return 0

    pactl list sink-inputs 2>/dev/null | awk '
        /^Sink Input #/ {
            if (id != "" && hit) {
                print id
            }
            id = $3
            sub(/^#/, "", id)
            hit = 0
            next
        }
        {
            line = tolower($0)
            if (line ~ /application\.name/ && line ~ /emulationstation/) {
                hit = 1
            }
            if (line ~ /application\.process\.binary/ && line ~ /emulationstation/) {
                hit = 1
            }
        }
        END {
            if (id != "" && hit) {
                print id
            }
        }'
}

pause_es_audio() {
    local CPU_PROFILE="$1"
    local INPUT_ID

    case "${CPU_PROFILE}" in
        "max"|"performance")
            ;;
        *)
            return 0
            ;;
    esac

    ensure_state_dir
    : > "${ES_AUDIO_STATE}"

    for INPUT_ID in $(es_sink_inputs); do
        pactl set-sink-input-mute "${INPUT_ID}" 1 >/dev/null 2>&1 || true
        echo "${INPUT_ID}" >> "${ES_AUDIO_STATE}"
    done
}

restore_es_audio() {
    local INPUT_ID

    [ -f "${ES_AUDIO_STATE}" ] || return 0

    while read -r INPUT_ID; do
        [ -n "${INPUT_ID}" ] || continue
        pactl set-sink-input-mute "${INPUT_ID}" 0 >/dev/null 2>&1 || true
    done < "${ES_AUDIO_STATE}"

    rm -f "${ES_AUDIO_STATE}"
}

is_dual_screen_handheld() {
    [ "$(/usr/bin/batocera-settings-get-master display.position)" = "top-bottom" ] || return 1
    [ -n "$(/usr/bin/batocera-settings-get-master global.videooutput2)" ] && return 0
    [ "$(batocera-model 2>/dev/null)" = "Anbernic_RG_DS" ] && return 0
    tr '\0' '\n' < /sys/firmware/devicetree/base/compatible 2>/dev/null | grep -qx "anbernic,rg-ds"
}

is_dual_screen_emulator() {
    local SYSTEM_NAME="$1"
    local EMULATOR_NAME="$2"
    local CORE_NAME="$3"
    local GAME_PATH="$4"

    case "${SYSTEM_NAME}:${EMULATOR_NAME}:${CORE_NAME}" in
        nds:drastic:drastic|nds:melonds:melonds|3ds:azahar:azahar|n3ds:azahar:azahar|wiiu:cemu:cemu)
            return 0
            ;;
    esac

    is_rgds_vertical_arcade_launch "${SYSTEM_NAME}" "${EMULATOR_NAME}" "${CORE_NAME}" "${GAME_PATH}"
}

is_rgds_vertical_arcade_core() {
    case "$1" in
        fbneo|fbalpha|mame|mame078plus|mame0139|mame0160|mamevirtual|imame4all)
            return 0
            ;;
    esac

    return 1
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
    local GAME_NAME="$4"

    [ "${EMULATOR_NAME}" = "flycast" ] || return 1
    [ "${CORE_NAME}" = "flycast" ] || return 1
    [ "$(get_flycast_vmu_display "${SYSTEM_NAME}" "${GAME_NAME}")" = "bottom" ]
}

get_lower_screen_controls() {
    local SYSTEM_NAME="$1"
    local GAME_NAME="$2"
    local MODE=""

    if [ -n "${GAME_NAME}" ]; then
        MODE="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}[\"${GAME_NAME}\"].lower_screen_controls" 2>/dev/null)"
    fi

    [ -n "${MODE}" ] || MODE="$(/usr/bin/batocera-settings-get-master "${SYSTEM_NAME}.lower_screen_controls" 2>/dev/null)"
    [ -n "${MODE}" ] || MODE="off"
    echo "${MODE}"
}

is_game_controls_bottom_launch() {
    local SYSTEM_NAME="$1"
    local EMULATOR_NAME="$2"
    local CORE_NAME="$3"
    local GAME_NAME="$4"

    [ "${EMULATOR_NAME}" = "libretro" ] || return 1
    [ "$(get_lower_screen_controls "${SYSTEM_NAME}" "${GAME_NAME}")" = "retroarch" ]
}

is_steam_launch() {
    local SYSTEM_NAME="$1"
    local EMULATOR_NAME="$2"
    local CORE_NAME="$3"
    local GAME_NAME="$4"

    case "${SYSTEM_NAME}:${EMULATOR_NAME}:${CORE_NAME}" in
        steam:*|*:steam:*|*:*:steam)
            return 0
            ;;
    esac

    case "${GAME_NAME}" in
        *.steam)
            return 0
            ;;
    esac

    return 1
}

pause_aux_display() {
    local CPU_PROFILE="$1"
    local SYSTEM_NAME="$2"
    local EMULATOR_NAME="$3"
    local CORE_NAME="$4"
    local GAME_NAME="$5"

    [ "${CPU_PROFILE}" = "max" ] || return 0
    is_dual_screen_handheld || return 0
    is_dual_screen_emulator "${SYSTEM_NAME}" "${EMULATOR_NAME}" "${CORE_NAME}" "${GAME_NAME}" && return 0
    is_flycast_vmu_bottom_launch "${SYSTEM_NAME}" "${EMULATOR_NAME}" "${CORE_NAME}" "${GAME_NAME}" && return 0
    is_game_controls_bottom_launch "${SYSTEM_NAME}" "${EMULATOR_NAME}" "${CORE_NAME}" "${GAME_NAME}" && return 0
    is_steam_launch "${SYSTEM_NAME}" "${EMULATOR_NAME}" "${CORE_NAME}" "${GAME_NAME}" && return 0
    command -v batocera-backglass >/dev/null 2>&1 || return 0
    case "$(/usr/bin/batocera-settings-get-master backglass.theme 2>/dev/null)" in
        control-center|waydroid|kodi)
            return 0
            ;;
    esac

    if pgrep -f '/usr/bin/batocera-backglass-window' >/dev/null 2>&1 ||
       [ -e /var/run/batocera-lower-screen-kodi.pid ] ||
       [ -e /var/run/batocera-lower-screen-waydroid.pid ] ||
       [ -s /var/run/batocera-backglass.params ]; then
        ensure_state_dir
        touch "${BACKGLASS_STATE}"
        batocera-backglass disable >/dev/null 2>&1 || true
    fi
}

restore_aux_display() {
    [ -f "${BACKGLASS_STATE}" ] || return 0
    command -v batocera-backglass >/dev/null 2>&1 && batocera-backglass restart >/dev/null 2>&1 || true
    rm -f "${BACKGLASS_STATE}"
}

refresh_controlcenter_backglass() {
    local SYSTEM_NAME="$1"
    local EMULATOR_NAME="$2"
    local CORE_NAME="$3"
    local GAME_NAME="$4"

    [ "$(/usr/bin/batocera-settings-get-master backglass.theme 2>/dev/null)" = "control-center" ] || return 0
    is_dual_screen_emulator "${SYSTEM_NAME}" "${EMULATOR_NAME}" "${CORE_NAME}" "${GAME_NAME}" && return 0
    command -v batocera-controlcenter >/dev/null 2>&1 || return 0

    (
        sleep 1
        batocera-controlcenter visible >/dev/null 2>&1 || true
    ) &
}

is_power_connected() {
    # Detect battery directory
    BATTERY_DIR=$(ls -d /sys/class/power_supply/*{BAT,bat}* 2>/dev/null | head -1)

    if [ -z "${BATTERY_DIR}" ]; then
        # If no battery directory, assume power supply is connected
        return 0
    fi

    # Check the battery status
    BATTERY_STATUS=$(cat "${BATTERY_DIR}/status" 2>/dev/null)

    if [[ "${BATTERY_STATUS}" == "Discharging" ]]; then
        # Battery is discharging
        return 1
    else
        # Battery is not discharging, assume power supply is connected
        return 0
    fi
}

handle_game_stop() {
    stop_uclamp_watcher
    restore_cpu_limit
    restore_es_audio
    restore_aux_display
    refresh_controlcenter_backglass

    # Check if power connected
    if is_power_connected; then
        POWER_MODE="$(/usr/bin/batocera-settings-get-master global.powermode)"
    else
        POWER_MODE="$(/usr/bin/batocera-settings-get-master global.batterymode)"
    fi

    # Apply global power mode or fall back to default
    /usr/bin/batocera-power-mode "${POWER_MODE:-default}"
    apply_cpu_profile "$(/usr/bin/batocera-settings-get-master global.cpu_profile)"
}

handle_game_start() {
    local SYSTEM_NAME="$1"
    local EMULATOR_NAME="$2"
    local CORE_NAME="$3"
    local GAME_NAME="$4"
    local CPU_PROFILE
    local CPU_MAX_FREQ
    local TARGET_FPS

    # Extract the base game name
    GAME_NAME="${GAME_NAME##*/}"

    # Check for user set game-specific setting
    if [ -n "${GAME_NAME}" ]; then
        POWER_MODE_SETTING="${SYSTEM_NAME}[\"${GAME_NAME}\"].powermode"
        POWER_MODE="$(/usr/bin/batocera-settings-get-master "${POWER_MODE_SETTING}")"
    fi

    # If no user set game-specific setting, check for system-specific setting
    if [ -z "${POWER_MODE}" ] && [ -n "${SYSTEM_NAME}" ]; then
        POWER_MODE_SETTING="${SYSTEM_NAME}.powermode"
        POWER_MODE="$(/usr/bin/batocera-settings-get-master "${POWER_MODE_SETTING}")"
    fi

    # If no system-specific setting, check for global setting
    if [ -z "${POWER_MODE}" ]; then
        if is_power_connected; then
            POWER_MODE="$(/usr/bin/batocera-settings-get-master global.powermode)"
        else
            POWER_MODE="$(/usr/bin/batocera-settings-get-master global.batterymode)"
        fi
    fi

    # Apply power mode or fall back to default
    /usr/bin/batocera-power-mode "${POWER_MODE:-default}"
    CPU_PROFILE="$(get_cpu_profile "${SYSTEM_NAME}" "${GAME_NAME}")"
    apply_cpu_profile "${CPU_PROFILE}"
    CPU_MAX_FREQ="$(get_cpu_max_freq "${SYSTEM_NAME}" "${GAME_NAME}")"
    TARGET_FPS="$(get_cpu_limit_target_fps "${SYSTEM_NAME}" "${GAME_NAME}")"
    apply_cpu_limit "${CPU_MAX_FREQ}" "${TARGET_FPS}" "${SYSTEM_NAME}"
    start_uclamp_watcher "${CPU_PROFILE}" "${SYSTEM_NAME}" "${EMULATOR_NAME}" "${CORE_NAME}"
    pause_es_audio "${CPU_PROFILE}"
    pause_aux_display "${CPU_PROFILE}" "${SYSTEM_NAME}" "${EMULATOR_NAME}" "${CORE_NAME}" "${GAME_NAME}"
    refresh_controlcenter_backglass "${SYSTEM_NAME}" "${EMULATOR_NAME}" "${CORE_NAME}" "${GAME_NAME}"
}

# Check for events
SYSTEM_NAME="$2"
EMULATOR_NAME="$3"
CORE_NAME="$4"
GAME_NAME="$5"

case "$1" in
    gameStart)
        handle_game_start "$SYSTEM_NAME" "$EMULATOR_NAME" "$CORE_NAME" "$GAME_NAME"
        ;;
    gameStop)
        handle_game_stop
        ;;
    *)
        exit 0
        ;;
esac

exit 0
