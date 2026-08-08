#!/usr/bin/env bash
# pack-ota-prep-zip.sh — user-facing ZIP so devices flashed from an older
# GitHub image (still using /releases/latest) can resolve per-board OTA tags.
#
# Usage:
#   ./scripts/dev/pack-ota-prep-zip.sh
#   HOTPATCH_OUT=output/hotpatch ./scripts/dev/pack-ota-prep-zip.sh
#
# Output:
#   ${HOTPATCH_OUT}/batocera-pocket-ota-per-board-prep.zip

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="${HOTPATCH_OUT:-$ROOT/output/hotpatch}"
STAMP="$(date -u +%Y%m%d)"
NAME="batocera-pocket-ota-per-board-prep"
STAGE="$OUT_DIR/stage-${NAME}-${STAMP}"
ZIP="$OUT_DIR/${NAME}.zip"

SCRIPTS="$ROOT/package/batocera/core/batocera-scripts/scripts"

need() { [ -f "$1" ] || { echo "Missing: $1" >&2; exit 1; }; }

need "$SCRIPTS/batocera-pocket-github-release"
need "$SCRIPTS/batocera-upgrade"
need "$SCRIPTS/batocera-config"
need "$SCRIPTS/batocera-es-swissknife"

rm -rf "$STAGE"
mkdir -p "$STAGE/usr/bin" "$OUT_DIR"

install -m 0755 "$SCRIPTS/batocera-pocket-github-release" "$STAGE/usr/bin/"
install -m 0755 "$SCRIPTS/batocera-upgrade"               "$STAGE/usr/bin/"
install -m 0755 "$SCRIPTS/batocera-config"                "$STAGE/usr/bin/"
install -m 0755 "$SCRIPTS/batocera-es-swissknife"         "$STAGE/usr/bin/"

cat > "$STAGE/install.sh" <<'EOF'
#!/bin/bash
# Install batocera.pocket per-board OTA scripts and persist via overlay.
# Run on the device as root (F1 → Terminal, or SSH).
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root (ssh root@device or F1 terminal)." >&2
    exit 1
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
LIST="usr/bin/batocera-pocket-github-release
usr/bin/batocera-upgrade
usr/bin/batocera-config
usr/bin/batocera-es-swissknife"

echo "=== batocera.pocket OTA per-board prep ==="

while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    src="${HERE}/${rel}"
    dest="/${rel}"
    [ -f "$src" ] || { echo "Missing in zip: ${rel}" >&2; exit 1; }
    mkdir -p "$(dirname "$dest")"
    install -m 0755 "$src" "$dest"
    echo "installed ${dest}"
done <<EOL
${LIST}
EOL

CONF="/userdata/system/batocera.conf"
touch "$CONF"
if grep -q '^updates.url=' "$CONF" 2>/dev/null; then
    sed -i 's|^updates.url=.*|updates.url=https://github.com/darkplace/batocera.pocket|' "$CONF"
else
    printf '\nupdates.url=https://github.com/darkplace/batocera.pocket\n' >> "$CONF"
fi
if grep -q '^updates.type=' "$CONF" 2>/dev/null; then
    sed -i 's|^updates.type=.*|updates.type=stable|' "$CONF"
else
    printf 'updates.type=stable\n' >> "$CONF"
fi
if grep -q '^updates.enabled=' "$CONF" 2>/dev/null; then
    sed -i 's|^updates.enabled=.*|updates.enabled=1|' "$CONF"
else
    printf 'updates.enabled=1\n' >> "$CONF"
fi
echo "updated ${CONF} (updates.url → darkplace/batocera.pocket)"

# Persist onto /boot/boot/overlay (survives reboot)
if [ ! -e /boot/boot/overlay ]; then
    batocera-save-overlay 50
else
    batocera-save-overlay
fi

BOARD="$(cat /boot/boot/batocera.board 2>/dev/null || echo unknown)"
mkdir -p /userdata/system/upgrade/hotpatch
echo "ota-per-board-prep $(date -u +%Y%m%dT%H%M%SZ) board=${BOARD}" \
    > /userdata/system/upgrade/hotpatch/LAST_OTA_PREP

echo ""
echo "=== OK ==="
echo "Board: ${BOARD}"
if command -v batocera-pocket-github-release >/dev/null 2>&1; then
    echo -n "Resolved release tag: "
    batocera-pocket-github-release tag "${BOARD}" 2>/dev/null || echo "(none yet — publish a tag with -${BOARD}-)"
fi
echo ""
echo "Reboot once, then check:"
echo "  batocera-config canupdate"
echo "  batocera-es-swissknife --update"
EOF
chmod 0755 "$STAGE/install.sh"

cat > "$STAGE/README.txt" <<EOF
batocera.pocket — OTA per-board prep
====================================
Build: ${STAMP}
For devices flashed from GitHub image v44-sm8750-20260807 (or any build that
still queries /releases/latest).

What this does
--------------
Installs scripts so Updates use the GitHub release whose tag contains your
board id (e.g. -sm8750-), never the global "Latest" button.

Files installed
---------------
  /usr/bin/batocera-pocket-github-release
  /usr/bin/batocera-upgrade
  /usr/bin/batocera-config
  /usr/bin/batocera-es-swissknife
  + sets updates.url in /userdata/system/batocera.conf
  + batocera-save-overlay (persists across reboot)

Install (on the handheld)
-------------------------
1. Copy this ZIP to the device share, e.g.:
     \\\\DEVICE_IP\\share\\system\\upgrade\\
   or any folder under /userdata (USB also fine).

2. On the device (F1 → Terminal, or SSH as root / password linux):

     cd /userdata/system/upgrade
     unzip -o batocera-pocket-ota-per-board-prep.zip
     cd batocera-pocket-ota-per-board-prep
     bash install.sh

3. Reboot once.

4. Verify:

     batocera-config canupdate
     batocera-es-swissknife --update

Spanish (resumen)
-----------------
Copia el ZIP a /userdata, descomprime, ejecuta: bash install.sh
como root, reinicia. Así el dispositivo buscará releases con tu board
(p.ej. v44-sm8750-…) en vez de "Latest" de GitHub.

Repo: https://github.com/darkplace/batocera.pocket
EOF

# Zip with a single top-level directory (friendly for Windows unzip)
rm -f "$ZIP"
(
    cd "$STAGE/.."
    BASE="$(basename "$STAGE")"
    # Rename stage dir to the public folder name inside the zip
    rm -rf "${NAME}"
    mv "$BASE" "$NAME"
    zip -r -q "$ZIP" "$NAME"
    # Keep stage for inspection under stable name
    mv "$NAME" "$BASE"
)

echo "Built: $ZIP"
unzip -l "$ZIP" | head -30
ls -lh "$ZIP"
