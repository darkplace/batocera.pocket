#!/usr/bin/env bash
# apply-hotpatch.sh — push batocera.pocket source fixes onto a live device and
# persist them with batocera-save-overlay (no full reflash required).
#
# Usage:
#   ./scripts/dev/apply-hotpatch.sh                 # build tarball only
#   ./scripts/dev/apply-hotpatch.sh --apply HOST    # build + install + save overlay
#   ./scripts/dev/apply-hotpatch.sh --apply 10.10.10.104
#
# Env:
#   HOTPATCH_PASS   SSH password (default: linux)
#   HOTPATCH_USER   SSH user (default: root)
#   HOTPATCH_OUT    Output dir for the tarball (default: output/hotpatch)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="${HOTPATCH_OUT:-$ROOT/output/hotpatch}"
USER_NAME="${HOTPATCH_USER:-root}"
PASS="${HOTPATCH_PASS:-linux}"
DO_APPLY=0
HOST=""
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
PATCH_ID="batocera.pocket-hotpatch-${STAMP}"

while [ $# -gt 0 ]; do
    case "$1" in
        --apply)
            DO_APPLY=1
            shift
            HOST="${1:-}"
            [ -n "$HOST" ] || { echo "Error: --apply requires HOST"; exit 1; }
            shift
            ;;
        -h|--help)
            sed -n '2,16p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown arg: $1"; exit 1
            ;;
    esac
done

need() { [ -f "$1" ] || { echo "Missing: $1"; exit 1; }; }

STAGE="$OUT_DIR/stage-${STAMP}"
rm -rf "$STAGE"
mkdir -p "$STAGE/usr/bin" "$STAGE/usr/share/batocera/splash" "$STAGE/meta"

# ---- Files to install (source → relative dest under /) ----
copy_bin() {
    local src="$1" destname="$2"
    need "$src"
    install -m 0755 "$src" "$STAGE/usr/bin/${destname}"
    echo "usr/bin/${destname}" >> "$STAGE/meta/files.list"
}

copy_file() {
    local src="$1" reldest="$2" mode="${3:-0644}"
    need "$src"
    mkdir -p "$STAGE/$(dirname "$reldest")"
    install -m "$mode" "$src" "$STAGE/${reldest}"
    echo "$reldest" >> "$STAGE/meta/files.list"
}

copy_bin "$ROOT/package/batocera/core/batocera-scripts/scripts/batocera-upgrade"       batocera-upgrade
copy_bin "$ROOT/package/batocera/core/batocera-scripts/scripts/batocera-pocket-github-release" batocera-pocket-github-release
copy_bin "$ROOT/package/batocera/core/batocera-scripts/scripts/batocera-config"        batocera-config
copy_bin "$ROOT/package/batocera/core/batocera-scripts/scripts/batocera-es-swissknife" batocera-es-swissknife
copy_bin "$ROOT/package/batocera/utils/batocera-led-handheld/batocera-led-handheld.py" batocera-led-handheld
copy_bin "$ROOT/package/batocera/utils/batocera-arch-plasma-lxc/batocera-arch-plasma-lxc" batocera-arch-plasma-lxc
copy_bin "$ROOT/package/batocera/utils/batocera-wine/batocera-wine-tools"             batocera-wine-tools
# Steam Tools UI uses a copy of wine-tools
copy_bin "$ROOT/package/batocera/utils/batocera-wine/batocera-wine-tools"             batocera-steam-tools
copy_bin "$ROOT/package/batocera/utils/batocera-steam-aarch64/batocera-steam"         batocera-steam
copy_bin "$ROOT/package/batocera/utils/batocera-steam/batocera-steam-session"         batocera-steam-session
copy_bin "$ROOT/package/batocera/utils/batocera-steam/steam-direct-session.sh"        steam-direct-session.sh
copy_bin "$ROOT/package/batocera/emulators/pkmnrecomp/pkmnrecomp"                     pkmnrecomp

# Splash branding (boot logos)
copy_file "$ROOT/package/batocera/core/batocera-splash-odin3/images/logo.png" \
    "usr/share/batocera/splash/boot-logo.png" 0644
copy_file "$ROOT/package/batocera/core/batocera-splash-odin3/images/logo-480p.png" \
    "usr/share/batocera/splash/boot-logo-4x3.png" 0644

# Optional: rebuilt gamescope with Wayland touch (if present in target tree)
GS="$ROOT/output/sm8750/target/usr/bin/gamescope"
if [ -x "$GS" ]; then
    copy_bin "$GS" gamescope
fi

cat > "$STAGE/meta/README.txt" <<EOF
${PATCH_ID}
batocera.pocket live hotpatch

Contents:
  - GitHub OTA (batocera-upgrade / batocera-config / swissknife)
  - stable == butterfly (latest release only)
  - LED split-status defaults (charge yellow, idle off, low red)
  - Plasma LXC shell-mode script generator (v9)
  - decky-bcc URL → darkplace/decky-bcc
  - Steam session scripts + gamescope (if available)
  - Splash boot logos (batocera.pocket)

Persistence: batocera-save-overlay writes /boot/boot/overlay
EOF

TAR="$OUT_DIR/${PATCH_ID}.tar.gz"
mkdir -p "$OUT_DIR"
tar -C "$STAGE" -czf "$TAR" .
echo "Built: $TAR"
echo "Files:"
cat "$STAGE/meta/files.list"

if [ "$DO_APPLY" -eq 0 ]; then
    echo ""
    echo "Tarball only. To install on a device:"
    echo "  $0 --apply <device-ip>"
    exit 0
fi

command -v sshpass >/dev/null || { echo "sshpass required"; exit 1; }

SSH=(sshpass -p "$PASS" ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
SCP=(sshpass -p "$PASS" scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

echo "Uploading to ${USER_NAME}@${HOST} ..."
"${SSH[@]}" "${USER_NAME}@${HOST}" 'mkdir -p /userdata/system/upgrade/hotpatch'
"${SCP[@]}" "$TAR" "${USER_NAME}@${HOST}:/userdata/system/upgrade/hotpatch/${PATCH_ID}.tar.gz"

echo "Installing + saving overlay on device..."
"${SSH[@]}" "${USER_NAME}@${HOST}" "PATCH_ID='${PATCH_ID}' bash -s" <<'REMOTE'
set -euo pipefail
TAR="/userdata/system/upgrade/hotpatch/${PATCH_ID}.tar.gz"
WORKDIR="/tmp/${PATCH_ID}"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
tar -C "$WORKDIR" -xzf "$TAR"

# Root is an overlay: writing to / already goes to the upperdir (tmpfs until save-overlay).
while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    dest="/${rel}"
    mkdir -p "$(dirname "$dest")"
    cp -a "${WORKDIR}/${rel}" "$dest"
    echo "installed ${dest}"
done < "${WORKDIR}/meta/files.list"

# Ensure updates point at batocera.pocket GitHub Releases
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

# Drop stale userdata LED map so new split-status defaults apply
if [ -f /userdata/system/configs/emulationstation/leds.conf ]; then
    # Keep file but remove hard-coded power-led colour map lines if present —
    # safest: backup and remove so daemon regenerates from script defaults.
    cp -a /userdata/system/configs/emulationstation/leds.conf \
        "/userdata/system/configs/emulationstation/leds.conf.bak.${PATCH_ID}" || true
    rm -f /userdata/system/configs/emulationstation/leds.conf
    echo "reset leds.conf (backup kept)"
fi

# Restart LED daemon so new defaults take effect immediately
if [ -x /etc/init.d/S51led-handheld ]; then
    /etc/init.d/S51led-handheld restart || true
fi

# Persist upperdir onto /boot/boot/overlay (survives reboot)
# Use 150M if creating fresh — scripts + gamescope need headroom
if [ ! -e /boot/boot/overlay ]; then
    batocera-save-overlay 150
else
    batocera-save-overlay
fi

echo "${PATCH_ID}" > /userdata/system/upgrade/hotpatch/LAST_APPLIED
echo "=== hotpatch OK: ${PATCH_ID} ==="
echo "Verify:"
grep -E 'updates\.(url|type)' /userdata/system/batocera.conf || true
grep -n 'darkplace/batocera.pocket' /usr/bin/batocera-upgrade | head -3 || true
grep -n 'FFCC00' /usr/bin/batocera-led-handheld | head -3 || true
grep -n 'darkplace/decky-bcc' /usr/bin/batocera-wine-tools | head -3 || true
ls -la /boot/boot/overlay
REMOTE

echo ""
echo "Done. Reboot the device when convenient to confirm overlay persistence."
echo "Quick checks after reboot:"
echo "  batocera-es-swissknife --update"
echo "  batocera-config canupdate"
echo "  grep updates.url /userdata/system/batocera.conf"
