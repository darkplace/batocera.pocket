#!/bin/bash
set -euo pipefail

RUNTIME_DIR="/userdata/system/.runtime-waydroid"

mkdir -p "${RUNTIME_DIR}"
chmod 700 "${RUNTIME_DIR}"

configure_display_runtime() {
    local candidate

    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        if [ "${WAYLAND_DISPLAY#/}" != "${WAYLAND_DISPLAY}" ]; then
            if [ -S "${WAYLAND_DISPLAY}" ]; then
                export XDG_RUNTIME_DIR="$(dirname "${WAYLAND_DISPLAY}")"
                export WAYLAND_DISPLAY="$(basename "${WAYLAND_DISPLAY}")"
                return
            fi
        elif [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]; then
            ln -snf "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" "${RUNTIME_DIR}/${WAYLAND_DISPLAY}"
            export XDG_RUNTIME_DIR="${RUNTIME_DIR}"
            return
        fi
    fi

    for candidate in /var/run/wayland-* /run/wayland-*; do
        [ -S "${candidate}" ] || continue
        ln -snf "${candidate}" "${RUNTIME_DIR}/$(basename "${candidate}")"
        export XDG_RUNTIME_DIR="${RUNTIME_DIR}"
        export WAYLAND_DISPLAY="$(basename "${candidate}")"
        return
    done

    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/run}"
}

configure_waydroid_runtime_compat() {
    local source_socket
    local pulse_socket

    if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ]; then
        source_socket="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
        if [ -S "${source_socket}" ] && { [ ! -S "/run/${WAYLAND_DISPLAY}" ] || [ -L "/run/${WAYLAND_DISPLAY}" ]; }; then
            ln -snf "${source_socket}" "/run/${WAYLAND_DISPLAY}"
        fi
    fi

    mkdir -p /run/pulse
    for pulse_socket in \
        "${XDG_RUNTIME_DIR:-}/pulse/native" \
        /var/run/0-runtime-dir/pulse/native \
        /run/0-runtime-dir/pulse/native \
        /run/user/0/pulse/native \
        /run/pulse/native
    do
        [ -S "${pulse_socket}" ] || continue
        if [ "${pulse_socket}" != "/run/pulse/native" ] && { [ ! -S /run/pulse/native ] || [ -L /run/pulse/native ]; }; then
            ln -snf "${pulse_socket}" /run/pulse/native
        fi
        export PULSE_RUNTIME_PATH=/run/pulse
        return
    done

    export PULSE_RUNTIME_PATH="${PULSE_RUNTIME_PATH:-/run/pulse}"
}

configure_display_runtime
configure_waydroid_runtime_compat

if [ -z "${DISPLAY:-}" ] && command -v getLocalXDisplay >/dev/null 2>&1; then
    export DISPLAY="$(getLocalXDisplay)"
fi

# Reset stale sessions before starting a fresh UI instance.
status_out="$(waydroid status 2>/dev/null || true)"
if printf '%s\n' "$status_out" | grep -Eq 'Session:[[:space:]]+RUNNING|Container:[[:space:]]+(RUNNING|FROZEN)'; then
    waydroid session stop >/dev/null 2>&1 || true
    waydroid container stop >/dev/null 2>&1 || true
    sleep 2
fi

exec /usr/bin/batocera-waydroid-session
