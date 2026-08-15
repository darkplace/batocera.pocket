#!/bin/bash
set -euo pipefail

LOG="/userdata/system/logs/steam.log"
ES_SERVICE="/etc/init.d/S31emulationstation"
DIRECT_SESSION_LOCK="/var/run/batocera-steam-direct-session.lock"
DIRECT_SESSION_LOCK_DIR="/var/run/batocera-steam-direct-session.lock.d"
DIRECT_APP_SESSION_FLAG="/var/run/batocera-steam-direct-app-session"
GAMESCOPE_ES_SESSION_FLAG="/var/run/batocera-steam-es-gamescope-session"
CLEANUP_DONE=0
DIRECT_SESSION_LOCK_ACQUIRED=0
ES_PROCESS_PATTERN='(^|/)emulationstation([[:space:]]|$)'
ES_STANDALONE_PATTERN='(^|/)emulationstation-standalone([[:space:]]|$)'
DECKY_STACK_PATTERN='/userdata/system/homebrew/services/PluginLoader|Decky Loader|/userdata/system/homebrew/plugins/'
STEAM_HELPER_PATTERN='steamrtarm64/steam|steamwebhelper|steamwebhelper\.sh|steam-runtime-supervisor|steam-runtime-launcher-service|steamerrorreporter|pressure-vessel|srt-logger|steam-runtime-system-info|SteamLinuxRuntime|SteamLaunch AppId=|pw-audio-namespace|/proton waitforexitandrun|steam\.exe|wineserver|winedevice\.exe|services\.exe'
FEX_STACK_PATTERN='(^|[[:space:]/])(FEX|FEXServer|FEXLoader|FEXInterpreter)([[:space:]]|$)|/usr/share/fex-emu|/userdata/system/steam/rootfs|\.FEXMount|squashfuse'
STEAM_GPU_PROFILE_STATE=""

mkdir -p "$(dirname "${LOG}")"

log() {
    echo "steam-direct-session: $*" >> "${LOG}"
}

apply_steam_launch_environment() {
    case "${BATOCERA_STEAM_UNSET_MESA_LOADER_DRIVER_OVERRIDE:-0}" in
        1|true|TRUE|True|yes|YES|Yes|on|ON|On)
            unset MESA_LOADER_DRIVER_OVERRIDE
            log "unset MESA_LOADER_DRIVER_OVERRIDE"
            ;;
    esac

    if [[ "${PROTON_LOG:-0}" == "1" ]]; then
        export PROTON_LOG_DIR="${PROTON_LOG_DIR:-/userdata/system/logs}"
        mkdir -p "${PROTON_LOG_DIR}" 2>/dev/null || true
        log "Proton logging enabled at ${PROTON_LOG_DIR}"
    fi
}

acquire_direct_session_lock() {
    if command -v flock >/dev/null 2>&1; then
        exec 8>"${DIRECT_SESSION_LOCK}"
        if ! flock -n 8; then
            log "another Steam direct session is already running; ignoring duplicate launch"
            exit 0
        fi
        printf '%s\n' "$$" 1>&8 || true
        DIRECT_SESSION_LOCK_ACQUIRED=1
        return 0
    fi

    if ! mkdir "${DIRECT_SESSION_LOCK_DIR}" 2>/dev/null; then
        log "another Steam direct session is already running; ignoring duplicate launch"
        exit 0
    fi
    printf '%s\n' "$$" > "${DIRECT_SESSION_LOCK_DIR}/pid" 2>/dev/null || true
    DIRECT_SESSION_LOCK_ACQUIRED=1
}

release_direct_session_lock() {
    [[ "${DIRECT_SESSION_LOCK_ACQUIRED}" == "1" ]] || return 0
    flock -u 8 >/dev/null 2>&1 || true
    exec 8>&- 2>/dev/null || true
    rm -f "${DIRECT_SESSION_LOCK}" 2>/dev/null || true
    rm -rf "${DIRECT_SESSION_LOCK_DIR}" 2>/dev/null || true
    DIRECT_SESSION_LOCK_ACQUIRED=0
}

apply_sm8550_gpu_profile() {
    case "$(cat /usr/share/batocera/batocera.arch 2>/dev/null || true)" in
        sm8550|sm8750) ;;
        *) return 0 ;;
    esac
    command -v batocera-gpu-profile >/dev/null 2>&1 || return 0

    STEAM_GPU_PROFILE_STATE="/var/run/batocera-gpu-profile/steam-direct-session.$$"
    batocera-gpu-profile highperformance "${STEAM_GPU_PROFILE_STATE}" >> "${LOG}" 2>&1 || true
    log "pinned sm8x50 GPU profile"
}

restore_sm8550_gpu_profile() {
    [[ -n "${STEAM_GPU_PROFILE_STATE}" ]] || return 0
    command -v batocera-gpu-profile >/dev/null 2>&1 || return 0

    batocera-gpu-profile restore "${STEAM_GPU_PROFILE_STATE}" >> "${LOG}" 2>&1 || true
    STEAM_GPU_PROFILE_STATE=""
    log "restored sm8x50 GPU profile"
}

normalize_bool() {
    case "${1,,}" in
        1|true|yes|on)
            printf '1\n'
            return 0
            ;;
        0|false|no|off)
            printf '0\n'
            return 0
            ;;
    esac

    return 1
}

trim_value() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s\n' "${value}"
}

settings_get_effective() {
    local key="$1"

    if command -v batocera-settings-get-master >/dev/null 2>&1; then
        batocera-settings-get-master "${key}" 2>/dev/null && return 0
    fi

    if command -v batocera-settings-get >/dev/null 2>&1; then
        batocera-settings-get "${key}" 2>/dev/null && return 0
    fi

    return 1
}

apply_steam_launcher_overrides() {
    local launcher
    local line
    local key
    local value
    local normalized

    for launcher in "$@"; do
        [[ -f "${launcher}" && "${launcher}" == *.steam ]] || continue

        log "reading Steam launcher overrides from ${launcher}"
        while IFS= read -r line || [[ -n "${line}" ]]; do
            line="$(trim_value "${line}")"
            [[ -n "${line}" && "${line}" != \#* && "${line}" == *=* ]] || continue
            key="$(trim_value "${line%%=*}")"
            key="${key,,}"
            value="$(trim_value "${line#*=}")"

            case "${key}" in
                visible_update_preflight|update_preflight)
                    normalized="$(normalize_bool "${value}" || true)"
                    if [[ -n "${normalized}" ]]; then
                        export BATOCERA_STEAM_VISIBLE_UPDATE_PREFLIGHT="${normalized}"
                    fi
                    ;;
                update_preflight_no_update_secs|preflight_no_update_secs)
                    if [[ "${value}" =~ ^[0-9]+$ && "${value}" -gt 0 ]]; then
                        export BATOCERA_STEAM_PREFLIGHT_NO_UPDATE_SECS="${value}"
                    fi
                    ;;
            esac
        done < "${launcher}"
    done
}

ensure_runtime_dir() {
    local uid
    local candidate

    uid="$(id -u)"
    candidate="/run/user/${uid}"
    mkdir -p "${candidate}"
    chmod 700 "${candidate}" 2>/dev/null || true
    export XDG_RUNTIME_DIR="${candidate}"
}

find_wayland_socket() {
    local runtime
    local display
    local path

    for runtime in /var/run /run "${XDG_RUNTIME_DIR:-}"; do
        [[ -n "${runtime}" ]] || continue
        for display in "${WAYLAND_DISPLAY:-}" wayland-1 wayland-0; do
            [[ -n "${display}" ]] || continue
            if [[ "${display}" == /* ]]; then
                path="${display}"
                display="$(basename "${display}")"
            else
                path="${runtime}/${display}"
            fi
            [[ -S "${path}" ]] || continue
            printf '%s\t%s\n' "$(dirname "${path}")" "${display}"
            return 0
        done
    done

    return 1
}

find_sway_socket() {
    local socket

    for socket in /var/run/sway-ipc.0.sock /run/sway-ipc.0.sock "${SWAYSOCK:-}" "${I3SOCK:-}"; do
        [[ -n "${socket}" ]] || continue
        [[ -S "${socket}" ]] || continue
        printf '%s\n' "${socket}"
        return 0
    done

    return 1
}

prepare_nested_wayland_runtime() {
    local parent_info
    local parent_runtime=""
    local parent_wayland=""
    local parent_sway=""
    local runtime
    local sway_link

    parent_info="$(find_wayland_socket || true)"
    if [[ -n "${parent_info}" ]]; then
        parent_runtime="${parent_info%%	*}"
        parent_wayland="${parent_info#*	}"
    fi
    parent_sway="$(find_sway_socket || true)"

    ensure_runtime_dir
    runtime="${XDG_RUNTIME_DIR}"

    if [[ -n "${parent_runtime}" && -n "${parent_wayland}" && -S "${parent_runtime}/${parent_wayland}" ]]; then
        if [[ "${parent_runtime}" != "${runtime}" ]]; then
            rm -f "${runtime}/${parent_wayland}"
            ln -sfn "${parent_runtime}/${parent_wayland}" "${runtime}/${parent_wayland}"
        fi
        export WAYLAND_DISPLAY="${parent_wayland}"
    fi

    if [[ -n "${parent_sway}" ]]; then
        if [[ "$(dirname "${parent_sway}")" == "${runtime}" ]]; then
            export SWAYSOCK="${parent_sway}"
        else
            sway_link="${runtime}/$(basename "${parent_sway}")"
            rm -f "${sway_link}"
            ln -sfn "${parent_sway}" "${sway_link}"
            export SWAYSOCK="${sway_link}"
        fi
        export I3SOCK="${SWAYSOCK}"
    fi

    if [[ -S /tmp/.X11-unix/X0 ]]; then
        export DISPLAY="${DISPLAY:-:0}"
    fi
}

gamescope_supports_rotation_shader() {
    command -v gamescope >/dev/null 2>&1 && gamescope --help 2>&1 | grep -q -- "--use-rotation-shader"
}

default_gamescope_backend() {
    local value
    local model=""

    for value in \
        "$(settings_get_effective steam.gamescope_backend || true)" \
        "$(settings_get_effective steam.gamescope.backend || true)" \
        "$(settings_get_effective gamescope_backend || true)"
    do
        case "${value}" in
            auto|drm|wayland|sdl|headless)
                printf '%s\n' "${value}"
                return 0
                ;;
        esac
    done

    if command -v batocera-info >/dev/null 2>&1; then
        model="$(batocera-info 2>/dev/null | awk -F': ' '/^Model:/ {print $2; exit}')"
    fi
    case "${model}" in
        AYN_Thor|AYN_Odin_3)
            printf 'wayland\n'
            return 0
            ;;
    esac

    if gamescope_supports_rotation_shader; then
        printf 'drm\n'
    else
        printf 'wayland\n'
    fi
}

reset_dsi_connectors() {
    local status_path

    touch /tmp/no-hotplug
    for status_path in /sys/class/drm/card*-DSI-*/status; do
        [[ -e "${status_path}" ]] || continue
        echo off > "${status_path}" 2>/dev/null || true
        sleep 0.2
        echo on > "${status_path}" 2>/dev/null || true
    done
    rm -f /tmp/no-hotplug
}

parse_resolution() {
    local value="${1:-}"

    if [[ "${value}" =~ ^([0-9]+)x([0-9]+)$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}x${BASH_REMATCH[2]}"
        return 0
    fi

    return 1
}

detect_resolution() {
    local parsed

    parsed="$(parse_resolution "${BATOCERA_STEAM_GS_DEFAULT_RES:-}" || true)"
    if [[ -n "${parsed}" ]]; then
        printf '%s\n' "${parsed}"
        return 0
    fi

    if command -v batocera-resolution >/dev/null 2>&1; then
        parsed="$(parse_resolution "$(batocera-resolution currentResolution 2>/dev/null || true)" || true)"
        if [[ -n "${parsed}" ]]; then
            printf '%s\n' "${parsed}"
            return 0
        fi
    fi

    printf '1280x720\n'
}

connected_drm_connector_path() {
    local connector="$1"
    local path

    [[ -n "${connector}" ]] || return 1

    for path in "/sys/class/drm/card-${connector}" "/sys/class/drm/card"*"-${connector}"; do
        [[ -e "${path}" ]] || continue
        [[ -r "${path}/status" ]] || continue
        [[ "$(cat "${path}/status" 2>/dev/null)" == "connected" ]] || continue
        [[ -r "${path}/modes" ]] || continue
        printf '%s\n' "${path}"
        return 0
    done

    return 1
}

connector_first_mode() {
    local path="$1"
    local mode
    local parsed

    [[ -r "${path}/modes" ]] || return 1

    while IFS= read -r mode; do
        parsed="$(parse_resolution "${mode}" || true)"
        if [[ -n "${parsed}" ]]; then
            printf '%s\n' "${parsed}"
            return 0
        fi
    done < "${path}/modes"

    return 1
}

detect_preferred_drm_connector() {
    local value
    local model=""
    local path

    if command -v batocera-info >/dev/null 2>&1; then
        model="$(batocera-info 2>/dev/null | awk -F': ' '/^Model:/ {print $2; exit}')"
    fi

    for value in "${BATOCERA_STEAM_GS_PREFER_OUTPUT:-}" "${BATOCERA_STEAM_GS_OUTPUT_CONNECTOR:-}"; do
        path="$(connected_drm_connector_path "${value}" || true)"
        if [[ -n "${path}" ]]; then
            printf '%s\n' "${value}"
            return 0
        fi
    done

    for value in \
        "$(settings_get_effective steam.gamescope.output || true)" \
        "$(settings_get_effective global.videooutput || true)"
    do
        path="$(connected_drm_connector_path "${value}" || true)"
        if [[ -n "${path}" ]]; then
            printf '%s\n' "${value}"
            return 0
        fi
    done

    case "${model}" in
        AYN_Odin_3)
            path="$(connected_drm_connector_path "DSI-1" || true)"
            if [[ -n "${path}" ]]; then
                printf 'DSI-1\n'
                return 0
            fi
            ;;
        AYN_Thor)
            path="$(connected_drm_connector_path "DSI-2" || true)"
            if [[ -n "${path}" ]]; then
                printf 'DSI-2\n'
                return 0
            fi
            ;;
    esac

    return 1
}

detect_drm_resolution() {
    local connector
    local connector_path
    local parsed

    connector="$(detect_preferred_drm_connector || true)"
    connector_path="$(connected_drm_connector_path "${connector}" || true)"
    if [[ -n "${connector_path}" ]]; then
        parsed="$(connector_first_mode "${connector_path}" || true)"
        if [[ -n "${parsed}" ]]; then
            printf '%s\n' "${parsed}"
            return 0
        fi
    fi

    for connector in /sys/class/drm/card*-DSI-* /sys/class/drm/card*-eDP-* /sys/class/drm/card*-HDMI-A-* /sys/class/drm/card*-DP-*; do
        [[ -e "${connector}" ]] || continue
        [[ -r "${connector}/status" ]] || continue
        [[ "$(cat "${connector}/status" 2>/dev/null)" == "connected" ]] || continue
        [[ -r "${connector}/modes" ]] || continue

        parsed="$(connector_first_mode "${connector}" || true)"
        if [[ -n "${parsed}" ]]; then
            printf '%s\n' "${parsed}"
            return 0
        fi
    done

    return 1
}

detect_refresh_rate() {
    local value

    if [[ "${BATOCERA_STEAM_GS_NESTED_REFRESH:-}" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "${BATOCERA_STEAM_GS_NESTED_REFRESH}"
        return 0
    fi

    if command -v batocera-resolution >/dev/null 2>&1; then
        value="$(batocera-resolution refreshRate 2>/dev/null || true)"
        if [[ "${value}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            awk -v rate="${value}" 'BEGIN { printf "%d\n", int(rate + 0.5) }'
            return 0
        fi
    fi

    printf '60\n'
}

display_rotation_to_orientation() {
    case "$1" in
        0)
            printf 'normal\n'
            ;;
        1)
            printf 'right\n'
            ;;
        2)
            printf 'upsidedown\n'
            ;;
        3)
            printf 'left\n'
            ;;
    esac
}

valid_gamescope_orientation() {
    case "$1" in
        normal|right|upsidedown|left)
            return 0
            ;;
    esac

    return 1
}

detect_gamescope_orientation() {
    local rotation=""
    local output=""
    local output2=""
    local value=""
    local model=""

    if command -v batocera-info >/dev/null 2>&1; then
        model="$(batocera-info 2>/dev/null | awk -F': ' '/^Model:/ {print $2; exit}')"
    fi

    value="$(settings_get_effective steam.gamescope.orientation || true)"
    if valid_gamescope_orientation "${value}"; then
        printf '%s\n' "${value}"
        return 0
    fi

    output="$(settings_get_effective global.videooutput || true)"
    output2="$(settings_get_effective global.videooutput2 || true)"
    for key in \
        "display.rotate.${output}" \
        "display.rotate2.${output}" \
        "display.rotate2.${output2}" \
        "display.rotate.DSI-2" \
        "display.rotate.DSI-1" \
        "display.rotate.DSI" \
        "display.rotate"
    do
        [[ "${key}" != "display.rotate." ]] || continue
        value="$(settings_get_effective "${key}" || true)"
        if [[ "${value}" =~ ^[0-3]$ ]]; then
            rotation="${value}"
            break
        fi
    done

    value="$(display_rotation_to_orientation "${rotation}")"
    if [[ -n "${value}" ]]; then
        printf '%s\n' "${value}"
        return 0
    fi

    case "${model}" in
        AYN_Thor|AYN_Odin_2_Mini|AYN_Odin_2_Portal|AYN_Odin_3)
            printf 'right\n'
            return 0
            ;;
        AYN_Odin_2)
            printf 'right\n'
            return 0
            ;;
    esac
}

ensure_cef_remote_debugging_markers() {
    local marker

    for marker in \
        "/userdata/system/steam/.cef-enable-remote-debugging" \
        "/userdata/system/.steam/steam/.cef-enable-remote-debugging" \
        "/userdata/system/.local/share/Steam/.cef-enable-remote-debugging"
    do
        mkdir -p "$(dirname "${marker}")"
        touch "${marker}"
    done
}

frontend_running() {
    emulationstation_running || \
    pgrep -x labwc >/dev/null 2>&1 || \
    pgrep -x sway >/dev/null 2>&1 || \
    pgrep -x openbox >/dev/null 2>&1
}

emulationstation_running() {
    pgrep -f "${ES_PROCESS_PATTERN}" >/dev/null 2>&1
}

emulationstation_standalone_running() {
    pgrep -f "${ES_STANDALONE_PATTERN}" >/dev/null 2>&1
}

stop_emulationstation() {
    local signal="${1:-TERM}"

    /usr/bin/emulationstation-standalone --stop-rebooting >/dev/null 2>&1 || true
    pkill "-${signal}" -f "${ES_PROCESS_PATTERN}" >/dev/null 2>&1 || true
    pkill "-${signal}" -f "${ES_STANDALONE_PATTERN}" >/dev/null 2>&1 || true
}

restore_sway_display_config() {
    if [[ "${BATOCERA_STEAM_GS_BACKEND:-}" != "wayland" ]]; then
        return 0
    fi
    if ! command -v swaymsg >/dev/null 2>&1; then
        return 0
    fi
    if ! pgrep -x sway >/dev/null 2>&1; then
        return 0
    fi

    log "reloading Sway display config after Steam exit"
    swaymsg reload >/dev/null 2>&1 || true
}

wait_for_frontend_stop() {
    local i

    for i in $(seq 1 100); do
        if ! frontend_running; then
            return 0
        fi
        sleep 0.1
    done

    return 1
}

wait_for_emulationstation_stop() {
    local i

    for i in $(seq 1 50); do
        if ! emulationstation_running && ! emulationstation_standalone_running; then
            return 0
        fi
        sleep 0.1
    done

    return 1
}

session_select_return_active() {
    pgrep -f '(^|[[:space:]/])steamos-session-select[[:space:]]+(plasma|desktop)([[:space:]]|$)' >/dev/null 2>&1
}

is_thor_top_bottom_display() {
    local model=""

    if command -v batocera-info >/dev/null 2>&1; then
        model="$(batocera-info 2>/dev/null | awk -F': ' '/^Model:/ {print $2; exit}')"
    fi
    [[ "${model}" == "AYN_Thor" ]] || return 1
    [[ "$(batocera-settings-get-master display.position 2>/dev/null || true)" == "top-bottom" ]] || return 1
    [[ -n "$(batocera-settings-get-master global.videooutput2 2>/dev/null || true)" ]]
}

keep_emulationstation_during_preflight() {
    case "${BATOCERA_STEAM_KEEP_ES_DURING_PREFLIGHT:-0}" in
        1|true|TRUE|yes|YES|on|ON)
            is_thor_top_bottom_display
            ;;
        *)
            return 1
            ;;
    esac
}

restore_backglass_widget() {
    is_thor_top_bottom_display || return 0
    [[ -s /var/run/batocera-backglass.params ]] || return 0
    command -v batocera-backglass >/dev/null 2>&1 || return 0

    log "restoring Thor backglass widget"
    (
        exec 8>&- 2>/dev/null || true
        env \
            XDG_CURRENT_DESKTOP=sway \
            XDG_SESSION_TYPE=wayland \
            XDG_RUNTIME_DIR=/var/run \
            WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" \
            SWAYSOCK="${SWAYSOCK:-/var/run/sway-ipc.0.sock}" \
            WLR_XWAYLAND_NO_AUTH=1 \
            batocera-backglass restart >/dev/null 2>&1 || true
    )
}

run_frontend_env() {
    local frontend_runtime="/var/run"
    local frontend_wayland="${WAYLAND_DISPLAY:-wayland-1}"
    local frontend_sway="/var/run/sway-ipc.0.sock"
    local frontend_info
    local steam_env

    if [[ ! -S "${frontend_runtime}/${frontend_wayland}" ]]; then
        frontend_info="$(find_wayland_socket || true)"
        if [[ -n "${frontend_info}" ]]; then
            frontend_runtime="${frontend_info%%	*}"
            frontend_wayland="${frontend_info#*	}"
        fi
    fi
    if [[ ! -S "${frontend_sway}" ]]; then
        frontend_sway="$(find_sway_socket || true)"
    fi

    (
        for steam_env in ${!BATOCERA_STEAM_@}; do
            unset "${steam_env}"
        done

        env \
            -u MANGOHUD \
            -u MANGOHUD_CONFIG \
            -u MANGOHUD_CONFIGFILE \
            -u MANGOHUD_DLSYM \
            -u MANGOAPP_CONFIG \
            -u LD_PRELOAD \
            -u LD_AUDIT \
            -u GAMESCOPE_DISPLAY \
            -u GAMESCOPE_WAYLAND_DISPLAY \
            -u GAMESCOPE_SESSION \
            -u STEAM_GAME_DISPLAY_0 \
            -u STEAM_MULTIPLE_XWAYLANDS \
            -u DESKTOP_STARTUP_ID \
            -u XKB_LAYOUT \
            -u XKB_DEFAULT_LAYOUT \
            -u XKB_VARIANT \
            -u XKB_DEFAULT_VARIANT \
            XDG_CURRENT_DESKTOP=sway \
            XDG_SESSION_TYPE=wayland \
            XDG_RUNTIME_DIR="${frontend_runtime}" \
            WAYLAND_DISPLAY="${frontend_wayland}" \
            DISPLAY="${DISPLAY:-:0}" \
            SWAYSOCK="${frontend_sway}" \
            I3SOCK="${frontend_sway}" \
            WLR_XWAYLAND_NO_AUTH=1 \
            "$@"
    )
}

run_frontend_service_cmd() {
    run_frontend_env "$@" >/dev/null 2>&1
}

sway_emulationstation_window_ready() {
    command -v swaymsg >/dev/null 2>&1 || return 1
    command -v jq >/dev/null 2>&1 || return 1
    pgrep -x sway >/dev/null 2>&1 || return 1

    env \
        XDG_RUNTIME_DIR=/var/run \
        SWAYSOCK="${SWAYSOCK:-/var/run/sway-ipc.0.sock}" \
        WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" \
        WLR_XWAYLAND_NO_AUTH=1 \
        swaymsg -t get_tree 2>/dev/null | \
        jq -e '
            .. | objects |
            select(
                ((.app_id? // "") == "emulationstation") or
                ((.name? // "") | contains("EmulationStation")) or
                ((.name? // "") | contains("ES-DE"))
            )
        ' >/dev/null 2>&1
}

emulationstation_display_ready() {
    emulationstation_running || return 1

    if pgrep -x sway >/dev/null 2>&1; then
        sway_emulationstation_window_ready || return 1
    fi
}

wait_for_emulationstation_ready() {
    local max_tries="${1:-160}"
    local i

    for i in $(seq 1 "${max_tries}"); do
        emulationstation_display_ready && return 0
        sleep 0.25
    done

    return 1
}

wait_for_emulationstation_standalone_stop() {
    local i

    for i in $(seq 1 40); do
        emulationstation_standalone_running || return 0
        sleep 0.1
    done

    return 1
}

stop_stale_emulationstation_standalone() {
    emulationstation_standalone_running || return 0

    log "stopping stale EmulationStation standalone wrapper"
    pkill -TERM -f "${ES_STANDALONE_PATTERN}" >/dev/null 2>&1 || true
    if ! wait_for_emulationstation_standalone_stop; then
        pkill -KILL -f "${ES_STANDALONE_PATTERN}" >/dev/null 2>&1 || true
        wait_for_emulationstation_standalone_stop || true
    fi
}

start_emulationstation_standalone() {
    command -v emulationstation-standalone >/dev/null 2>&1 || return 1

    log "starting EmulationStation frontend inside existing compositor"
    if command -v setsid >/dev/null 2>&1; then
        run_frontend_env setsid /bin/sh -c \
            'exec 8>&- 2>/dev/null || true; nohup /usr/bin/emulationstation-standalone </dev/null >> "$1" 2>&1 &' \
            sh "${LOG}" >/dev/null 2>&1 &
    else
        run_frontend_env /bin/sh -c \
            'exec 8>&- 2>/dev/null || true; nohup /usr/bin/emulationstation-standalone </dev/null >> "$1" 2>&1 &' \
            sh "${LOG}" >/dev/null 2>&1 &
    fi
    disown "$!" 2>/dev/null || true
}

steam_stack_alive() {
    pgrep -f '(^|[[:space:]/])batocera-steam([[:space:]]|$)' >/dev/null 2>&1 || \
    pgrep -f '(^|[[:space:]/])batocera-steam-session([[:space:]]|$)' >/dev/null 2>&1 || \
    pgrep -f '(^|[[:space:]/])batocera-steam-uimode-watch([[:space:]]|$)' >/dev/null 2>&1 || \
    pgrep -f '(^|[[:space:]/])batocera-steam-nightmode-watch([[:space:]]|$)' >/dev/null 2>&1 || \
    pgrep -f '(^|[[:space:]/])batocera-steam-update-terminal([[:space:]]|$)' >/dev/null 2>&1 || \
    pgrep -x steam >/dev/null 2>&1 || \
    pgrep -x steamwebhelper >/dev/null 2>&1 || \
    pgrep -x steam-runtime-supervisor >/dev/null 2>&1 || \
    pgrep -x FEX >/dev/null 2>&1 || \
    pgrep -f '(^|[[:space:]/])gamescope([[:space:]]|$)' >/dev/null 2>&1 || \
    pgrep -x gamescopereaper >/dev/null 2>&1 || \
    pgrep -x gamescopestream >/dev/null 2>&1 || \
    pgrep -x gamescopectl >/dev/null 2>&1 || \
    pgrep -x mangoapp >/dev/null 2>&1 || \
    pgrep -x wineserver >/dev/null 2>&1 || \
    pgrep -f "${STEAM_HELPER_PATTERN}" >/dev/null 2>&1 || \
    pgrep -f "${FEX_STACK_PATTERN}" >/dev/null 2>&1 || \
    pgrep -f "${DECKY_STACK_PATTERN}" >/dev/null 2>&1 || \
    pgrep -f '/userdata/system/steam/steam.sh|/usr/share/steam/bin_steam.sh|emulatorlauncher.*-system steam|Steam GamepadUI\.steam|Steam Desktop\.steam' >/dev/null 2>&1
}

cleanup_fex_mounts() {
    local mount

    for mount in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/.FEXMount* /run/user/*/.FEXMount*; do
        [[ -e "${mount}" ]] || continue
        fusermount3 -uz "${mount}" >/dev/null 2>&1 || \
            fusermount -uz "${mount}" >/dev/null 2>&1 || \
            umount -l "${mount}" >/dev/null 2>&1 || true
    done
}

terminate_steam_stack() {
    local i

    log "cleaning residual Steam/gamescope process stack after Steam exit"
    if command -v killall >/dev/null 2>&1; then
        killall -q -9 batocera-steam steam steamwebhelper steam-runtime-supervisor \
            steam-runtime-launcher-service steamerrorreporter pressure-vessel \
            FEX FEXServer FEXLoader FEXInterpreter squashfuse squashfuse_ll \
            gamescope gamescopereaper gamescopestream gamescopectl mangoapp \
            wineserver winedevice.exe services.exe PluginLoader >/dev/null 2>&1 || true
    fi
    pkill -KILL -f "${STEAM_HELPER_PATTERN}" >/dev/null 2>&1 || true
    pkill -KILL -f "${FEX_STACK_PATTERN}" >/dev/null 2>&1 || true
    pkill -KILL -f '(^|[[:space:]/])batocera-steam([[:space:]]|$)' >/dev/null 2>&1 || true
    pkill -KILL -f '(^|[[:space:]/])batocera-steam-session([[:space:]]|$)' >/dev/null 2>&1 || true
    pkill -KILL -f '(^|[[:space:]/])batocera-steam-uimode-watch([[:space:]]|$)' >/dev/null 2>&1 || true
    pkill -KILL -f '(^|[[:space:]/])batocera-steam-nightmode-watch([[:space:]]|$)' >/dev/null 2>&1 || true
    pkill -KILL -f '(^|[[:space:]/])batocera-steam-update-terminal([[:space:]]|$)' >/dev/null 2>&1 || true
    pkill -KILL -x steam >/dev/null 2>&1 || true
    pkill -KILL -x steamwebhelper >/dev/null 2>&1 || true
    pkill -KILL -x steam-runtime-supervisor >/dev/null 2>&1 || true
    pkill -KILL -x FEX >/dev/null 2>&1 || true
    pkill -KILL -x FEXServer >/dev/null 2>&1 || true
    pkill -KILL -x FEXLoader >/dev/null 2>&1 || true
    pkill -KILL -x FEXInterpreter >/dev/null 2>&1 || true
    pkill -KILL -x squashfuse >/dev/null 2>&1 || true
    pkill -KILL -x squashfuse_ll >/dev/null 2>&1 || true
    pkill -KILL -f '(^|[[:space:]/])gamescope([[:space:]]|$)' >/dev/null 2>&1 || true
    pkill -KILL -x gamescope >/dev/null 2>&1 || true
    pkill -KILL -x gamescopereaper >/dev/null 2>&1 || true
    pkill -KILL -x gamescopestream >/dev/null 2>&1 || true
    pkill -KILL -x gamescopectl >/dev/null 2>&1 || true
    pkill -KILL -x mangoapp >/dev/null 2>&1 || true
    pkill -KILL -x wineserver >/dev/null 2>&1 || true
    pkill -KILL -f "${DECKY_STACK_PATTERN}" >/dev/null 2>&1 || true
    pkill -KILL -f '/userdata/system/steam/steam.sh|/usr/share/steam/bin_steam.sh|emulatorlauncher.*-system steam|Steam GamepadUI\.steam|Steam Desktop\.steam' >/dev/null 2>&1 || true
    cleanup_fex_mounts

    for i in $(seq 1 8); do
        steam_stack_alive || return 0
        pkill -KILL -f "${STEAM_HELPER_PATTERN}" >/dev/null 2>&1 || true
        pkill -KILL -f "${FEX_STACK_PATTERN}" >/dev/null 2>&1 || true
        cleanup_fex_mounts
        sleep 0.2
    done
}

restore_frontend() {
    if pgrep -x sway >/dev/null 2>&1 || pgrep -x labwc >/dev/null 2>&1 || pgrep -x openbox >/dev/null 2>&1; then
        if emulationstation_display_ready; then
            log "EmulationStation display is ready after Steam exit"
            return 0
        fi

        if emulationstation_standalone_running && ! emulationstation_running; then
            stop_stale_emulationstation_standalone
        fi

        if ! emulationstation_standalone_running; then
            start_emulationstation_standalone || true
        else
            log "waiting for existing EmulationStation standalone wrapper after Steam exit"
        fi

        if wait_for_emulationstation_ready "${BATOCERA_STEAM_ES_RESTORE_WAIT_TRIES:-32}"; then
            log "EmulationStation display became ready after Steam exit"
            return 0
        fi

        log "EmulationStation standalone did not become ready after Steam exit"
        stop_stale_emulationstation_standalone
        start_emulationstation_standalone || true
        if wait_for_emulationstation_ready "${BATOCERA_STEAM_ES_RESTORE_WAIT_TRIES:-32}"; then
            log "EmulationStation display became ready after standalone retry"
            return 0
        fi

        log "EmulationStation display restore failed inside existing compositor"
        return 1
    fi

    if emulationstation_running; then
        log "killing orphaned EmulationStation before service restart"
        stop_emulationstation KILL
    fi

    if frontend_running; then
        log "frontend already running after Steam exit"
        return 0
    fi

    if [[ -x "${ES_SERVICE}" ]]; then
        log "starting EmulationStation service after Steam exit"
        run_frontend_service_cmd "${ES_SERVICE}" start || run_frontend_service_cmd "${ES_SERVICE}" restart || true
    fi

    if wait_for_emulationstation_ready "${BATOCERA_STEAM_ES_RESTORE_WAIT_TRIES:-32}"; then
        log "EmulationStation display became ready after service start"
        return 0
    fi

    log "EmulationStation service start did not restore display; retrying service start"
    pkill -KILL -x mangoapp >/dev/null 2>&1 || true
    if [[ -x "${ES_SERVICE}" ]]; then
        run_frontend_service_cmd "${ES_SERVICE}" start || true
    fi
    if wait_for_emulationstation_ready "${BATOCERA_STEAM_ES_RESTORE_RETRY_WAIT_TRIES:-32}"; then
        log "EmulationStation display became ready after service start retry"
        return 0
    fi

    log "EmulationStation display restore failed after service start retry"
    return 1
}

start_frontend_recover_monitor() {
    command -v batocera-steam-frontend-recover >/dev/null 2>&1 || return 0

    log "starting Steam frontend recovery monitor: ${1:-steam-direct-session}"
    if command -v setsid >/dev/null 2>&1; then
        setsid batocera-steam-frontend-recover \
            --wait-steam-exit \
            --reason "${1:-steam-direct-session}" >/dev/null 2>&1 &
    else
        batocera-steam-frontend-recover \
            --wait-steam-exit \
            --reason "${1:-steam-direct-session}" >/dev/null 2>&1 &
    fi
    disown "$!" 2>/dev/null || true
}

start_session_supervisor() {
    command -v batocera-steam-session-supervisor >/dev/null 2>&1 || return 0

    log "starting Steam session supervisor: ${1:-steam-direct-session}"
    batocera-steam-session-supervisor start "${1:-steam-direct-session}" >/dev/null 2>&1 || true
}

stop_session_supervisor() {
    command -v batocera-steam-session-supervisor >/dev/null 2>&1 || return 0

    log "stopping Steam session supervisor before direct-session frontend restore"
    batocera-steam-session-supervisor stop >/dev/null 2>&1 || true
}

refresh_steam_es_entries() {
    command -v batocera-steam-update >/dev/null 2>&1 || return 0

    log "refreshing Steam ES launchers after Steam exit"
    if ! /usr/bin/batocera-steam-update >> "${LOG}" 2>&1; then
        log "Steam ES launcher refresh failed after Steam exit"
    fi
}

cleanup() {
    local rc=$?
    local es_gamescope_session=0

    trap - EXIT INT TERM
    if [[ "${CLEANUP_DONE}" == "1" ]]; then
        exit "${rc}"
    fi
    CLEANUP_DONE=1

    log "Steam session exited with status ${rc}"
    # Drop pad grab before DRM/gamescope teardown — mouse-mode in Steam can
    # leave the session half-dead and freeze on the Batocera splash.
    if command -v batocera-mouse-mode >/dev/null 2>&1; then
        batocera-mouse-mode disable >/dev/null 2>&1 || true
    fi
    pkill -KILL -f '(^|[[:space:]/])batocera-mouse-mode([[:space:]]|$)' >/dev/null 2>&1 || true
    rm -f /var/run/batocera-mouse-mode.enabled /var/run/batocera-mouse-mode.pid /var/run/batocera-mouse-mode.cmd
    [[ -e "${GAMESCOPE_ES_SESSION_FLAG}" ]] && es_gamescope_session=1
    rm -f "${DIRECT_APP_SESSION_FLAG}"
    rm -f "${GAMESCOPE_ES_SESSION_FLAG}"
    stop_session_supervisor
    restore_sway_display_config
    if [[ "${BATOCERA_STEAM_GS_BACKEND:-}" == "drm" && "${BATOCERA_STEAM_RESET_DSI_AFTER_GAMESCOPE:-0}" == "1" ]]; then
        log "resetting DSI connector state after DRM gamescope exit"
        reset_dsi_connectors
    fi
    if [[ "${es_gamescope_session}" != "1" ]] && session_select_return_active; then
        log "frontend restore deferred to steamos-session-select"
        restore_sm8550_gpu_profile
        release_direct_session_lock
        exit "${rc}"
    fi
    terminate_steam_stack
    refresh_steam_es_entries
    if ! restore_frontend; then
        start_frontend_recover_monitor "steam-direct-session-cleanup"
    fi
    restore_backglass_widget
    restore_sm8550_gpu_profile
    release_direct_session_lock
    exit "${rc}"
}

log "requested direct Steam session launch"

case "${1:-}" in
    gameStop|systemSelected|systemDeselected)
        log "ignoring Batocera launcher hook event without launching: $*"
        exit 0
        ;;
esac

acquire_direct_session_lock
trap cleanup EXIT INT TERM
apply_sm8550_gpu_profile
apply_steam_launch_environment

export BATOCERA_STEAM_GS_BACKEND="${BATOCERA_STEAM_GS_BACKEND:-$(default_gamescope_backend)}"

# After exclusive DRM sessions on DSI panels (Odin3), force a connector reset so ES recovers.
if [[ -z "${BATOCERA_STEAM_RESET_DSI_AFTER_GAMESCOPE:-}" ]]; then
    _reset_dsi="$(settings_get_effective steam.gamescope.reset_dsi_after || true)"
    case "${_reset_dsi}" in
        1|true|TRUE|yes|YES|on|ON)
            export BATOCERA_STEAM_RESET_DSI_AFTER_GAMESCOPE="1"
            ;;
        0|false|FALSE|no|NO|off|OFF)
            export BATOCERA_STEAM_RESET_DSI_AFTER_GAMESCOPE="0"
            ;;
        *)
            case "$(batocera-info 2>/dev/null | awk -F': ' '/^Model:/ {print $2; exit}')" in
                AYN_Odin_3|AYN_Thor)
                    if [[ "${BATOCERA_STEAM_GS_BACKEND}" == "drm" ]]; then
                        export BATOCERA_STEAM_RESET_DSI_AFTER_GAMESCOPE="1"
                    fi
                    ;;
            esac
            ;;
    esac
fi
unset _reset_dsi

apply_steam_launcher_overrides "$@"

steam_args=()
direct_app_session=0
case "${1:-}" in
    gameStart)
        log "ignoring Batocera launcher hook arguments: $*"
        ;;
    "")
        ;;
    *)
        steam_args=("$@")
        direct_app_session=1
        ;;
esac

if [[ "${direct_app_session}" == "1" ]]; then
    printf '%s\n' "${steam_args[*]}" > "${DIRECT_APP_SESSION_FLAG}" || true
else
    printf '%s\n' "$$" > "${GAMESCOPE_ES_SESSION_FLAG}" || true
fi

start_session_supervisor "steam-direct-session"
if [ -x /usr/bin/batocera-steam-back-qam ]; then
    /usr/bin/batocera-steam-back-qam start >/dev/null 2>&1 || true
fi

if [[ "${BATOCERA_STEAM_VISIBLE_UPDATE_PREFLIGHT:-0}" != "0" && -x /usr/bin/batocera-steam-update-preflight ]]; then
    if [[ "${BATOCERA_STEAM_PREFLIGHT_STEAM_UPDATER:-auto}" == "auto" &&
          "${BATOCERA_STEAM_MODE:-steamos}" == "steamos" &&
          "${BATOCERA_STEAM_USE_GAMESCOPE:-1}" != "0" ]]; then
        export BATOCERA_STEAM_PREFLIGHT_STEAM_UPDATER="external"
        log "using external graphical Steam updater preflight before Gamescope"
    fi
    case "${BATOCERA_STEAM_PREFLIGHT_STEAM_UPDATER:-auto}" in
        external|desktop)
            export BATOCERA_STEAM_PREFLIGHT_SUPPRESS_CHILD_UI="${BATOCERA_STEAM_PREFLIGHT_SUPPRESS_CHILD_UI:-0}"
            export BATOCERA_STEAM_PREFLIGHT_STATUS_XTERM="${BATOCERA_STEAM_PREFLIGHT_STATUS_XTERM:-0}"
            ;;
    esac
    if emulationstation_running; then
        if keep_emulationstation_during_preflight; then
            log "keeping EmulationStation running during visible Steam updater preflight"
        else
            log "stopping EmulationStation before visible Steam updater preflight"
            stop_emulationstation TERM
            if ! wait_for_emulationstation_stop; then
                log "EmulationStation did not stop cleanly before visible Steam updater preflight"
                stop_emulationstation KILL
                wait_for_emulationstation_stop || true
            fi
        fi
    fi
    log "running visible Steam updater preflight before Gamescope"
    if /usr/bin/batocera-steam-update-preflight launch >> "${LOG}" 2>&1; then
        case "${BATOCERA_STEAM_STARTUP_ARGS:-auto}" in
            auto|AUTO|Auto|"")
                export BATOCERA_STEAM_STARTUP_ARGS=1
                log "visible Steam updater preflight completed; suppressing Steam bootstrap/update during Gamescope handoff"
                ;;
        esac
    else
        log "visible Steam updater preflight failed; continuing to Gamescope"
    fi
    restore_backglass_widget
fi

if [[ "${BATOCERA_STEAM_GS_BACKEND}" == "wayland" ]]; then
    log "keeping Wayland compositor alive for nested gamescope backend"
    stop_emulationstation TERM
    if ! wait_for_emulationstation_stop; then
        log "EmulationStation did not stop cleanly before Steam launch"
        if [[ "${BATOCERA_STEAM_FORCE_KILL_ES_FOR_WAYLAND:-0}" == "1" ]]; then
            stop_emulationstation KILL
            wait_for_emulationstation_stop || true
        fi
    fi
    restore_backglass_widget
elif [[ -x "${ES_SERVICE}" ]]; then
    log "stopping EmulationStation frontend before Steam launch"
    "${ES_SERVICE}" stop >/dev/null 2>&1 || true
    if ! wait_for_frontend_stop; then
        log "frontend did not stop cleanly before Steam launch"
    fi
fi

if [[ "${BATOCERA_STEAM_GS_BACKEND}" != "wayland" ]]; then
    unset DISPLAY
    unset WAYLAND_DISPLAY
    unset SWAYSOCK
    unset XAUTHORITY
    unset LABWC_PID
    unset WLR_XWAYLAND_NO_AUTH
    unset DBUS_SESSION_BUS_ADDRESS
fi
unset GAMESCOPE_DISPLAY
unset GAMESCOPE_WAYLAND_DISPLAY
unset GAMESCOPE_SESSION

if [[ "${BATOCERA_STEAM_GS_BACKEND}" == "wayland" ]]; then
    log "using existing Wayland display=${WAYLAND_DISPLAY:-<unset>} runtime=${XDG_RUNTIME_DIR:-<unset>}"
    prepare_nested_wayland_runtime
else
    ensure_runtime_dir
fi

export XKB_DEFAULT_LAYOUT="${BATOCERA_STEAM_XKB_LAYOUT:-us}"
export XKB_LAYOUT="${BATOCERA_STEAM_XKB_LAYOUT:-us}"

detected_resolution="$(detect_resolution)"
detected_drm_resolution="$(detect_drm_resolution || true)"
detected_drm_connector="$(detect_preferred_drm_connector || true)"
detected_refresh="$(detect_refresh_rate)"
detected_orientation="$(detect_gamescope_orientation || true)"

export BATOCERA_STEAM_MODE="${BATOCERA_STEAM_MODE:-steamos}"
export BATOCERA_STEAM_USE_GAMESCOPE="1"
export BATOCERA_STEAM_GAMEPADUI="${BATOCERA_STEAM_GAMEPADUI:-1}"
export BATOCERA_STEAM_GS_DEFAULT_RES="${BATOCERA_STEAM_GS_DEFAULT_RES:-${detected_resolution}}"
if [[ -z "${BATOCERA_STEAM_GS_OUTPUT_RES:-}" && "${BATOCERA_STEAM_GS_BACKEND}" == "drm" && -n "${detected_drm_resolution}" ]]; then
    export BATOCERA_STEAM_GS_OUTPUT_RES="${detected_drm_resolution}"
else
    export BATOCERA_STEAM_GS_OUTPUT_RES="${BATOCERA_STEAM_GS_OUTPUT_RES:-${BATOCERA_STEAM_GS_DEFAULT_RES}}"
fi
if [[ "${BATOCERA_STEAM_GS_BACKEND}" == "drm" && -n "${detected_drm_connector}" ]]; then
    export BATOCERA_STEAM_GS_PREFER_OUTPUT="${BATOCERA_STEAM_GS_PREFER_OUTPUT:-${detected_drm_connector}}"
fi
export BATOCERA_STEAM_GS_NESTED_RES="${BATOCERA_STEAM_GS_NESTED_RES:-${BATOCERA_STEAM_GS_DEFAULT_RES}}"
export BATOCERA_STEAM_GS_NESTED_REFRESH="${BATOCERA_STEAM_GS_NESTED_REFRESH:-${detected_refresh}}"
# Nested Wayland (Odin3/Thor) drops game frames when Steam QAM steals focus.
# Match unfocused refresh to nested refresh (was hard-coded 30 → tiny-square /
# frozen clients on some Proton/DX12 titles). Do not enable
# --force-windows-fullscreen here; it makes QAM/chords flakier.
if [[ -z "${BATOCERA_STEAM_GS_NESTED_UNFOCUSED_REFRESH:-}" ]]; then
    case "${BATOCERA_STEAM_GS_BACKEND}" in
        wayland|sdl)
            case "$(batocera-info 2>/dev/null | awk -F': ' '/^Model:/ {print $2; exit}')" in
                AYN_Odin_3|AYN_Thor)
                    export BATOCERA_STEAM_GS_NESTED_UNFOCUSED_REFRESH="${BATOCERA_STEAM_GS_NESTED_REFRESH}"
                    ;;
            esac
            ;;
    esac
fi
if [[ "${BATOCERA_STEAM_FORCE_DISABLE_MANGOAPP:-0}" == "1" ]]; then
    export BATOCERA_STEAM_GS_MANGOAPP="0"
else
    # aarch64 SteamOS needs MangoApp alive so Steam's performance-overlay
    # slider (and mangohudctl / Decky paddle toggle) can show/hide the HUD.
    _mango_default="0"
    case "$(uname -m)" in
        aarch64|arm64) _mango_default="1" ;;
    esac
    export BATOCERA_STEAM_GS_MANGOAPP="${BATOCERA_STEAM_GS_MANGOAPP:-${_mango_default}}"
    unset _mango_default
fi
if [[ "${BATOCERA_STEAM_GS_BACKEND}" == "drm" ]]; then
    export BATOCERA_STEAM_GS_FORCE_ORIENTATION="${BATOCERA_STEAM_GS_FORCE_ORIENTATION:-${detected_orientation}}"
    export BATOCERA_STEAM_GS_XWAYLAND_COUNT="${BATOCERA_STEAM_GS_XWAYLAND_COUNT:-2}"
    case "$(batocera-info 2>/dev/null | awk -F': ' '/^Model:/ {print $2; exit}')" in
        AYN_Odin_3)
            export BATOCERA_STEAM_GS_USE_ROTATION_SHADER="${BATOCERA_STEAM_GS_USE_ROTATION_SHADER:-0}"
            ;;
        *)
            export BATOCERA_STEAM_GS_USE_ROTATION_SHADER="${BATOCERA_STEAM_GS_USE_ROTATION_SHADER:-1}"
            ;;
    esac
    export BATOCERA_STEAM_GS_BORDERLESS="${BATOCERA_STEAM_GS_BORDERLESS:-1}"
    unset BATOCERA_STEAM_GS_DISABLE_HW_COMPOSITION
    unset BATOCERA_STEAM_GS_FORCE_COMPOSITION_PIPELINE
    unset BATOCERA_STEAM_GS_FORCE_WINDOWS_FULLSCREEN
else
    unset BATOCERA_STEAM_GS_DISABLE_HW_COMPOSITION
    unset BATOCERA_STEAM_GS_FORCE_COMPOSITION_PIPELINE
    unset BATOCERA_STEAM_GS_FORCE_WINDOWS_FULLSCREEN
    unset BATOCERA_STEAM_GS_FORCE_ORIENTATION
    unset BATOCERA_STEAM_GS_USE_ROTATION_SHADER
    unset BATOCERA_STEAM_GS_BORDERLESS
fi
export BATOCERA_STEAM_GS_SCALER="${BATOCERA_STEAM_GS_SCALER:-stretch}"
export BATOCERA_STEAM_GS_FILTER="${BATOCERA_STEAM_GS_FILTER:-linear}"

log "using gamescope defaults backend=${BATOCERA_STEAM_GS_BACKEND} connector=${BATOCERA_STEAM_GS_PREFER_OUTPUT:-none} res=${BATOCERA_STEAM_GS_DEFAULT_RES} output=${BATOCERA_STEAM_GS_OUTPUT_RES} nested=${BATOCERA_STEAM_GS_NESTED_RES} refresh=${BATOCERA_STEAM_GS_NESTED_REFRESH} orientation=${BATOCERA_STEAM_GS_FORCE_ORIENTATION:-none}"

ensure_cef_remote_debugging_markers

log "launching batocera-steam with mode=${BATOCERA_STEAM_MODE} args=${steam_args[*]:-<none>}"
(
    exec 8>&- 2>/dev/null || true
    if command -v dbus-run-session >/dev/null 2>&1; then
        dbus-run-session -- /usr/bin/batocera-steam "${steam_args[@]}"
    else
        /usr/bin/batocera-steam "${steam_args[@]}"
    fi
)
