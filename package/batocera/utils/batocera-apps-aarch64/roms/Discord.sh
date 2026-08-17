#!/bin/bash
set -euo pipefail
batocera-mouse show
if command -v batocera-mouse-mode >/dev/null 2>&1; then
    batocera-mouse-mode enable >/dev/null 2>&1 || true
fi
trap 'batocera-mouse-mode disable >/dev/null 2>&1 || true; batocera-mouse hide' EXIT
exec batocera-app-vesktop
