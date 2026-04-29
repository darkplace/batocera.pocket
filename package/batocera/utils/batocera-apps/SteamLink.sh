#!/bin/bash
set -euo pipefail
batocera-mouse show
trap 'batocera-mouse hide' EXIT

resolution="$(batocera-resolution currentResolution 2>/dev/null || true)"
case "$resolution" in
  [0-9]*x[0-9]*)
    export HDCD_RESOLUTION="${HDCD_RESOLUTION:-$resolution}"
    export DISPLAY_WIDTH="${DISPLAY_WIDTH:-${resolution%x*}}"
    export DISPLAY_HEIGHT="${DISPLAY_HEIGHT:-${resolution#*x}}"
    ;;
esac

# EGLFS misreads Thor's raw portrait DSI panel; Xwayland lets labwc apply the
# normal rotated 1920x1080 output geometry.
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-x11}"
export SDL_VIDEO_DRIVER="${SDL_VIDEO_DRIVER:-x11}"

{
  printf '%s HDCD_RESOLUTION=%s DISPLAY_WIDTH=%s DISPLAY_HEIGHT=%s QT_QPA_PLATFORM=%s SDL_VIDEODRIVER=%s SDL_VIDEO_DRIVER=%s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" \
    "${HDCD_RESOLUTION:-unset}" \
    "${DISPLAY_WIDTH:-unset}" \
    "${DISPLAY_HEIGHT:-unset}" \
    "${QT_QPA_PLATFORM:-unset}" \
    "${SDL_VIDEODRIVER:-unset}" \
    "${SDL_VIDEO_DRIVER:-unset}"
} >> /userdata/system/logs/steamlink-launch-env.log 2>/dev/null || true

exec batocera-app-steamlink
