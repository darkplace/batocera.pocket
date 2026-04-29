#!/bin/bash
set -euo pipefail

RUNTIME_DIR="/userdata/system/.runtime-waydroid"

mkdir -p "${RUNTIME_DIR}"
chmod 700 "${RUNTIME_DIR}"

export WAYLAND_DISPLAY="/run/wayland-0"
export XDG_RUNTIME_DIR="${RUNTIME_DIR}"
export PULSE_RUNTIME_PATH="/run/pulse"

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
