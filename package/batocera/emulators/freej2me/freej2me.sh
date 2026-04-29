#!/bin/bash

set -euo pipefail

FREEJ2ME_HOME="${FREEJ2ME_HOME:-/userdata/system/configs/freej2me}"
HOME="${HOME:-${FREEJ2ME_HOME}/home}"

mkdir -p "${FREEJ2ME_HOME}" "${HOME}"
cd "${FREEJ2ME_HOME}"

exec /usr/bin/java -jar /usr/share/freej2me/freej2me-sdl.jar "$@"
