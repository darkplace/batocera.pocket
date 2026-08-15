#!/bin/sh
# Odin2/Odin3 hotkey profile swaps for Steam + mouse-mode safety.
# - gameStart(steam): apply *.mapping.steam (no mousemode) and disable mouse-mode
# - gameStop/forcekill: restore ES mapping and disable mouse-mode
# Abrupt emukill (L1+R1+Select+Start) can SIGKILL before gameStop runs, so
# forcekill is also wired from hotkeygen common_context.

EVENT="${1:-restore}"
SYSTEM="${2:-}"

HOTKEY_DIR="/userdata/system/configs/hotkeygen"
SYSTEM_DIR="/usr/share/hotkeygen"

disable_mouse_mode() {
    if command -v batocera-mouse-mode >/dev/null 2>&1; then
        batocera-mouse-mode disable >/dev/null 2>&1 || true
    fi
    pkill -KILL -f '(^|[[:space:]/])batocera-mouse-mode([[:space:]]|$)' >/dev/null 2>&1 || true
    rm -f /var/run/batocera-mouse-mode.enabled \
          /var/run/batocera-mouse-mode.pid \
          /var/run/batocera-mouse-mode.cmd
}

seed_map_variants() {
    base="$1"
    mkdir -p "$HOTKEY_DIR"
    for suffix in "" ".es" ".steam"; do
        src="${SYSTEM_DIR}/${base}${suffix}"
        dst="${HOTKEY_DIR}/${base}${suffix}"
        [ -f "$src" ] || continue
        # Always refresh from image so OTA/hotfixes (e.g. steam_qam on Home)
        # are not stuck behind a stale userdata copy seeded once forever.
        cp -f "$src" "$dst" 2>/dev/null || true
    done
}

apply_map() {
    base="$1"
    variant="$2" # "" | ".es" | ".steam"
    src=""
    if [ -n "$variant" ] && [ -f "${HOTKEY_DIR}/${base}${variant}" ]; then
        src="${HOTKEY_DIR}/${base}${variant}"
    elif [ -n "$variant" ] && [ -f "${SYSTEM_DIR}/${base}${variant}" ]; then
        src="${SYSTEM_DIR}/${base}${variant}"
    elif [ -f "${SYSTEM_DIR}/${base}${variant}" ]; then
        src="${SYSTEM_DIR}/${base}${variant}"
    elif [ -f "${SYSTEM_DIR}/${base}" ]; then
        src="${SYSTEM_DIR}/${base}"
    else
        return 0
    fi
    mkdir -p "$HOTKEY_DIR"
    cp -f "$src" "${HOTKEY_DIR}/${base}" 2>/dev/null || return 0
    return 0
}

restore_es_map() {
    base="$1"
    src=""
    if [ -f "${SYSTEM_DIR}/${base}.es" ]; then
        src="${SYSTEM_DIR}/${base}.es"
    elif [ -f "${HOTKEY_DIR}/${base}.es" ]; then
        src="${HOTKEY_DIR}/${base}.es"
    elif [ -f "${SYSTEM_DIR}/${base}" ]; then
        src="${SYSTEM_DIR}/${base}"
    else
        return 0
    fi
    mkdir -p "$HOTKEY_DIR"
    cp -f "$src" "${HOTKEY_DIR}/${base}" 2>/dev/null || return 0
    cp -f "$src" "${HOTKEY_DIR}/${base}.es" 2>/dev/null || true
}

ensure_hotkeygen() {
    if pgrep -f '(^|[[:space:]])(/usr/bin/)?hotkeygen([[:space:]].*)?--permanent([[:space:]]|$)' >/dev/null 2>&1; then
        return 0
    fi
    if [ -x /etc/init.d/S90hotkeygen ]; then
        /etc/init.d/S90hotkeygen start >/dev/null 2>&1 || /etc/init.d/S90hotkeygen restart >/dev/null 2>&1 || true
    fi
}

reload_hotkeys() {
    ensure_hotkeygen
    if command -v hotkeygen >/dev/null 2>&1; then
        /usr/bin/hotkeygen --default-context >/dev/null 2>&1 || true
        /usr/bin/hotkeygen --reload >/dev/null 2>&1 || true
    fi
}

ODIN_MAPS="AYN_Odin2_Gamepad-2020-3001.mapping AYN_Odin3_Gamepad-2020-3001.mapping"

case "$EVENT" in
    gameStart)
        disable_mouse_mode
        if [ "$SYSTEM" = "steam" ]; then
            for base in $ODIN_MAPS; do
                seed_map_variants "$base"
                apply_map "$base" ".steam"
            done
            reload_hotkeys
        fi
        ;;
    gameStop|gameend|restore|forcekill)
        disable_mouse_mode
        for base in $ODIN_MAPS; do
            restore_es_map "$base"
        done
        reload_hotkeys
        ;;
    *)
        exit 0
        ;;
esac
