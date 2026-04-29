#!/bin/sh
set -eu

EVENT="${1:-}"
SYSTEM="${2:-}"

HOTKEY_DIR="/userdata/system/configs/hotkeygen"
ACTIVE_MAP="${HOTKEY_DIR}/ASUS_ROG_Ally_Config-b05-1abe.mapping"
ES_MAP="${HOTKEY_DIR}/ASUS_ROG_Ally_Config-b05-1abe.mapping.es"
STEAM_MAP="${HOTKEY_DIR}/ASUS_ROG_Ally_Config-b05-1abe.mapping.steam"

apply_map() {
    src="$1"
    [ -f "$src" ] || return 0
    cp -f "$src" "$ACTIVE_MAP"
    /usr/bin/hotkeygen --reload >/dev/null 2>&1 || true
}

case "$EVENT" in
    gameStart)
        if [ "$SYSTEM" = "steam" ]; then
            apply_map "$STEAM_MAP"
        fi
        ;;
    gameStop)
        if [ "$SYSTEM" = "steam" ]; then
            apply_map "$ES_MAP"
        fi
        ;;
    *)
        ;;
esac
