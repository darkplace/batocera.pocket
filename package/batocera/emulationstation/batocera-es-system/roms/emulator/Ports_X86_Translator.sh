#!/bin/bash
# Tools launcher: pick Box64 vs FEX binfmt for Ports (mutual exclusion).
set -euo pipefail

TRANSLATOR="${1:-}"
HELPER="/usr/bin/batocera-ports-translator"

if [[ "$(uname -m)" != "aarch64" && "$(uname -m)" != "arm64" ]]; then
    echo "Ports X86 translator is only used on aarch64."
    sleep 2
    exit 0
fi

current="$(batocera-settings-get ports.ports_translator 2>/dev/null || true)"
current="${current:-box64}"

if [[ -z "${TRANSLATOR}" ]]; then
    # Cycle Box64 <-> FEX when launched from ES with no args.
    if [[ "${current}" == "fex" ]]; then
        TRANSLATOR="box64"
    else
        TRANSLATOR="fex"
    fi
fi

case "${TRANSLATOR}" in
    box64|fex) ;;
    *)
        echo "Usage: $0 [box64|fex]"
        exit 1
        ;;
esac

batocera-settings-set ports.ports_translator "${TRANSLATOR}" >/dev/null 2>&1 || true

if [[ -x "${HELPER}" ]]; then
    "${HELPER}" "${TRANSLATOR}" || true
else
    echo "batocera-ports-translator missing; saved preference only."
fi

echo "Ports X86 translator: ${TRANSLATOR}"
sleep 2
exit 0
