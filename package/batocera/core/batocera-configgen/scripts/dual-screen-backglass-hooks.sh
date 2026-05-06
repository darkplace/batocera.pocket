#!/bin/sh

STATE_FILE="/var/run/batocera-dual-screen-backglass.cmd"

is_dual_screen_handheld() {
    [ "$(/usr/bin/batocera-settings-get-master display.position)" = "top-bottom" ] || return 1
    [ -n "$(/usr/bin/batocera-settings-get-master global.videooutput2)" ]
}

is_dual_screen_emulator() {
    case "$2:$3:$4" in
        nds:*:*|n3ds:*:*|3ds:*:*|wiiu:*:*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
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
    pkill -f '/usr/bin/batocera-backglass-window' || true
}

restore_backglass() {
    [ -f "$STATE_FILE" ] || return 0
    pgrep -f '/usr/bin/batocera-backglass-window' >/dev/null && return 0
    sh -c "$(cat "$STATE_FILE")" >/dev/null 2>&1 &
    rm -f "$STATE_FILE"
}

case "$1" in
    gameStart)
        if is_dual_screen_handheld && is_dual_screen_emulator "$@"; then
            stop_backglass
        fi
        ;;
    gameStop)
        restore_backglass
        ;;
esac

exit 0
