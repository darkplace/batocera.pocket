#!/bin/bash
set -euo pipefail

LOG="/userdata/system/logs/steam.log"
ES_SERVICE="/etc/init.d/S31emulationstation"
CLEANUP_DONE=0
STEAM_ROOT="${BATOCERA_STEAM_ROOT:-/userdata/system/.local/share/Steam}"
PROTON11_ARM64_DIR_NAME="${BATOCERA_STEAM_PROTON11_ARM64_DIR_NAME:-Proton 11.0 (ARM64)}"

mkdir -p "$(dirname "${LOG}")"

log() {
    echo "steam-direct-session: $*" >> "${LOG}"
}

flash_message() {
    local seconds="$1"
    local message="$2"
    local size="${3:-22}"

    if command -v batocera-flash-screen >/dev/null 2>&1; then
        /usr/bin/batocera-flash-screen "${seconds}" "#ffffff" "${message}" "${size}" >/dev/null 2>&1 || true
    fi
}

has_network() {
    if command -v ip >/dev/null 2>&1 && ! ip route get 1.1.1.1 >/dev/null 2>&1; then
        return 1
    fi

    if command -v ping >/dev/null 2>&1; then
        timeout 2 ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1
        return $?
    fi

    return 0
}

activate_wifi_for_steam() {
    local i

    if has_network; then
        return 0
    fi

    log "network unavailable before Steam setup; trying to enable Wi-Fi"
    flash_message 5 "Steam setup needs Wi-Fi. Enabling Wi-Fi..." 21

    if command -v connmanctl >/dev/null 2>&1; then
        connmanctl enable wifi >> "${LOG}" 2>&1 || true
        connmanctl scan wifi >> "${LOG}" 2>&1 || true
    fi

    for i in $(seq 1 "${BATOCERA_STEAM_WIFI_WAIT_SECS:-30}"); do
        if has_network; then
            log "network became available before Steam setup"
            return 0
        fi
        sleep 1
    done

    log "network still unavailable after Wi-Fi enable attempt"
    return 1
}

steam_setup_state() {
    local fex_config="/userdata/system/.config/fex-emu/Config.json"
    local fex_rootfs_dir="/userdata/system/.local/share/fex-emu/RootFS"
    local fex_rootfs_name

    if [[ ! -x "${STEAM_ROOT}/steamrtarm64/steam" ]]; then
        printf 'client\n'
        return 0
    fi

    if [[ ! -x "${STEAM_ROOT}/steamapps/common/${PROTON11_ARM64_DIR_NAME}/proton" ]]; then
        printf 'support\n'
        return 0
    fi

    if [[ ! -f "${fex_config}" ]]; then
        printf 'support\n'
        return 0
    fi
    fex_rootfs_name="$(sed -n 's/.*"RootFS"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${fex_config}" | head -n 1)"
    if [[ -z "${fex_rootfs_name}" || ! -e "${fex_rootfs_dir}/${fex_rootfs_name}" ]]; then
        printf 'support\n'
        return 0
    fi

    printf 'none\n'
}

prepare_visible_steam_setup() {
    local setup_state

    setup_state="$(steam_setup_state)"
    if [[ "${setup_state}" == "none" ]]; then
        return 0
    fi

    log "Steam/Proton/FEX setup is incomplete; refusing Gamescope launch before setup"
    if [[ "${setup_state}" == "client" ]]; then
        flash_message 8 "Steam is not installed yet." 22
    else
        flash_message 8 "Steam Proton/FEX setup is incomplete." 20
    fi
    flash_message 8 "Gamescope mode is not supported before setup completes." 17
    flash_message 8 "Launch Steam GamepadUI or Desktop without Gamescope first." 17
    exit 0
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

prepare_nested_wayland_runtime() {
    local parent_runtime="${XDG_RUNTIME_DIR:-/var/run}"
    local parent_wayland="${WAYLAND_DISPLAY:-wayland-1}"
    local parent_sway="${SWAYSOCK:-}"
    local runtime
    local sway_link

    ensure_runtime_dir
    runtime="${XDG_RUNTIME_DIR}"

    if [[ -S "${parent_runtime}/${parent_wayland}" ]]; then
        ln -sfn "${parent_runtime}/${parent_wayland}" "${runtime}/${parent_wayland}"
        export WAYLAND_DISPLAY="${parent_wayland}"
    fi

    if [[ -n "${parent_sway}" && -S "${parent_sway}" ]]; then
        sway_link="${runtime}/$(basename "${parent_sway}")"
        ln -sfn "${parent_sway}" "${sway_link}"
        export SWAYSOCK="${sway_link}"
    fi
}

gamescope_supports_rotation_shader() {
    command -v gamescope >/dev/null 2>&1 && gamescope --help 2>&1 | grep -q -- "--use-rotation-shader"
}

default_gamescope_backend() {
    local value
    local model=""

    if command -v batocera-settings-get >/dev/null 2>&1; then
        for value in \
            "$(batocera-settings-get steam.gamescope_backend 2>/dev/null || true)" \
            "$(batocera-settings-get steam.gamescope.backend 2>/dev/null || true)" \
            "$(batocera-settings-get gamescope_backend 2>/dev/null || true)"
        do
            case "${value}" in
                auto|drm|wayland|sdl|headless)
                    printf '%s\n' "${value}"
                    return 0
                    ;;
            esac
        done
    fi

    if command -v batocera-info >/dev/null 2>&1; then
        model="$(batocera-info 2>/dev/null | awk -F': ' '/^Model:/ {print $2; exit}')"
    fi
    case "${model}" in
        AYN_Thor)
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

    if command -v batocera-settings-get >/dev/null 2>&1; then
        for value in \
            "$(batocera-settings-get steam.gamescope.output 2>/dev/null || true)" \
            "$(batocera-settings-get global.videooutput 2>/dev/null || true)"
        do
            path="$(connected_drm_connector_path "${value}" || true)"
            if [[ -n "${path}" ]]; then
                printf '%s\n' "${value}"
                return 0
            fi
        done
    fi

    case "${model}" in
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

    if command -v batocera-settings-get >/dev/null 2>&1; then
        value="$(batocera-settings-get steam.gamescope.orientation 2>/dev/null || true)"
        if valid_gamescope_orientation "${value}"; then
            printf '%s\n' "${value}"
            return 0
        fi

        output="$(batocera-settings-get global.videooutput 2>/dev/null || true)"
        output2="$(batocera-settings-get global.videooutput2 2>/dev/null || true)"
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
            value="$(batocera-settings-get "${key}" 2>/dev/null || true)"
            if [[ "${value}" =~ ^[0-3]$ ]]; then
                rotation="${value}"
                break
            fi
        done
    fi

    value="$(display_rotation_to_orientation "${rotation}")"
    if [[ -n "${value}" ]]; then
        printf '%s\n' "${value}"
        return 0
    fi

    case "${model}" in
        AYN_Thor|AYN_Odin_2_Mini|AYN_Odin_2_Portal)
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
    pgrep -x emulationstation >/dev/null 2>&1 || \
    pgrep -x labwc >/dev/null 2>&1 || \
    pgrep -x sway >/dev/null 2>&1 || \
    pgrep -x openbox >/dev/null 2>&1
}

emulationstation_running() {
    pgrep -f '(^|/)emulationstation([[:space:]]|$)' >/dev/null 2>&1
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
        if ! emulationstation_running; then
            return 0
        fi
        sleep 0.1
    done

    return 1
}

restore_frontend() {
    if pgrep -x sway >/dev/null 2>&1 || pgrep -x labwc >/dev/null 2>&1 || pgrep -x openbox >/dev/null 2>&1; then
        if emulationstation_running; then
            log "EmulationStation already running after Steam exit"
            return 0
        fi
        log "starting EmulationStation frontend after Steam exit"
        nohup /usr/bin/emulationstation-standalone >> "${LOG}" 2>&1 &
        return 0
    fi

    if emulationstation_running; then
        log "killing orphaned EmulationStation before service restart"
        pkill -KILL -x emulationstation >/dev/null 2>&1 || true
    fi

    if frontend_running; then
        log "frontend already running after Steam exit"
        return 0
    fi

    if [[ -x "${ES_SERVICE}" ]]; then
        log "starting EmulationStation service after Steam exit"
        "${ES_SERVICE}" start >/dev/null 2>&1 || "${ES_SERVICE}" restart >/dev/null 2>&1 || true
    fi
}

cleanup() {
    local rc=$?

    trap - EXIT INT TERM
    if [[ "${CLEANUP_DONE}" == "1" ]]; then
        exit "${rc}"
    fi
    CLEANUP_DONE=1

    log "Steam session exited with status ${rc}"
    restore_sway_display_config
    if [[ "${BATOCERA_STEAM_GS_BACKEND:-}" == "drm" && "${BATOCERA_STEAM_RESET_DSI_AFTER_GAMESCOPE:-0}" == "1" ]]; then
        log "resetting DSI connector state after DRM gamescope exit"
        reset_dsi_connectors
    fi
    restore_frontend
    exit "${rc}"
}

trap cleanup EXIT INT TERM

log "requested direct Steam session launch"

export BATOCERA_STEAM_GS_BACKEND="${BATOCERA_STEAM_GS_BACKEND:-$(default_gamescope_backend)}"

prepare_visible_steam_setup

if [[ "${BATOCERA_STEAM_GS_BACKEND}" == "wayland" ]]; then
    log "keeping Wayland compositor alive for nested gamescope backend"
    pkill -TERM -x emulationstation >/dev/null 2>&1 || true
    if ! wait_for_emulationstation_stop; then
        log "EmulationStation did not stop cleanly before Steam launch"
        if [[ "${BATOCERA_STEAM_FORCE_KILL_ES_FOR_WAYLAND:-0}" == "1" ]]; then
            pkill -KILL -x emulationstation >/dev/null 2>&1 || true
        fi
    fi
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
if [[ "${BATOCERA_STEAM_FORCE_DISABLE_MANGOAPP:-0}" != "1" ]]; then
    export BATOCERA_STEAM_GS_MANGOAPP="1"
fi
if [[ "${BATOCERA_STEAM_GS_BACKEND}" == "drm" ]]; then
    export BATOCERA_STEAM_GS_FORCE_ORIENTATION="${BATOCERA_STEAM_GS_FORCE_ORIENTATION:-${detected_orientation}}"
    export BATOCERA_STEAM_GS_XWAYLAND_COUNT="${BATOCERA_STEAM_GS_XWAYLAND_COUNT:-2}"
    export BATOCERA_STEAM_GS_USE_ROTATION_SHADER="${BATOCERA_STEAM_GS_USE_ROTATION_SHADER:-1}"
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

steam_args=()
case "${1:-}" in
    gameStart|gameStop|systemSelected|systemDeselected)
        log "ignoring Batocera launcher hook arguments: $*"
        ;;
    "")
        ;;
    *)
        steam_args=("$@")
        ;;
esac

log "launching batocera-steam with mode=${BATOCERA_STEAM_MODE} args=${steam_args[*]:-<none>}"
if command -v dbus-run-session >/dev/null 2>&1; then
    dbus-run-session -- /usr/bin/batocera-steam "${steam_args[@]}"
else
    /usr/bin/batocera-steam "${steam_args[@]}"
fi
