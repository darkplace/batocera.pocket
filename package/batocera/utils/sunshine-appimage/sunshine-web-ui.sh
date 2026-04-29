#!/bin/bash
set -euo pipefail

if ! batocera-services list all 2>/dev/null | grep -q '^sunshine;\*$'; then
	echo "Sunshine service is disabled. Enable it in System Settings > Services."
	sleep 3
	exit 1
fi

if ! batocera-services status sunshine 2>/dev/null | grep -q '^started$'; then
	batocera-services start sunshine >/dev/null 2>&1 || true
	sleep 1
fi

if ! batocera-services status sunshine 2>/dev/null | grep -q '^started$'; then
	echo "Sunshine service failed to start."
	sleep 3
	exit 1
fi

batocera-mouse show
trap 'batocera-mouse hide' EXIT

if command -v batocera-app-firefox >/dev/null 2>&1; then
	exec batocera-app-firefox http://localhost:47990
elif command -v firefox >/dev/null 2>&1; then
	exec firefox http://localhost:47990
else
	echo "Firefox is not available on this system."
	sleep 3
	exit 1
fi
