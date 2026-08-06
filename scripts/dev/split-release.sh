#!/bin/bash
# split-release.sh — prepare GitHub Release assets under the 2GB file limit.
#
# Two modes:
#   --ota   <boot.tar.xz>   Raw .part01..N for batocera-upgrade (device-side join)
#   --image <file.img.gz>   Multi-volume ZIP for Windows users (WinZip / 7-Zip)
#   (auto)  chooses --image for *.img / *.img.gz / *.img.xz, else --ota
#
# Windows flash workflow (no shell scripts required):
#   1. Download ALL volume files of the set (.zip + .z01 + .z02 …)
#   2. Keep them in the same folder
#   3. Open the .zip with 7-Zip or WinZip and extract → get the .img.gz
#   4. Flash the .img.gz with balenaEtcher / Rufus / Raspberry Pi Imager
#
# OTA workflow (device):
#   Upload batocera.version, boot.tar.xz.md5, boot.tar.xz.part01..N
#   batocera-upgrade downloads and concatenates parts automatically.

set -euo pipefail

MAX_SIZE_MB=1900
MAX_SIZE_BYTES=$((MAX_SIZE_MB * 1024 * 1024))
MODE="auto"
INPUT=""

usage() {
    echo "Usage:"
    echo "  $0 --image <batocera-*.img.gz>   # multi-volume ZIP for Windows flash"
    echo "  $0 --ota   <boot.tar.xz>         # raw parts for in-device OTA"
    echo "  $0 <file>                        # auto-detect mode from filename"
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --image) MODE="image"; shift; INPUT="${1:-}"; shift || true ;;
        --ota)   MODE="ota";   shift; INPUT="${1:-}"; shift || true ;;
        -h|--help) usage ;;
        *)
            if [ -z "$INPUT" ]; then
                INPUT="$1"
                shift
            else
                usage
            fi
            ;;
    esac
done

[ -n "$INPUT" ] || usage
[ -f "$INPUT" ] || { echo "Error: File not found: $INPUT"; exit 1; }

case "$MODE" in
    auto)
        base="$(basename "$INPUT")"
        case "$base" in
            *.img|*.img.gz|*.img.xz|*.img.zst)
                MODE="image"
                ;;
            *)
                MODE="ota"
                ;;
        esac
        ;;
esac

INPUT_SIZE=$(stat -c%s "$INPUT" 2>/dev/null || stat -f%z "$INPUT" 2>/dev/null)
INPUT_SIZE_MB=$((INPUT_SIZE / 1024 / 1024))
DIR="$(cd "$(dirname "$INPUT")" && pwd)"
BASE="$(basename "$INPUT")"

echo "=== Split Release ==="
echo "Input:    $INPUT"
echo "Size:     ${INPUT_SIZE_MB}MB"
echo "Mode:     $MODE"

echo "Generating full-file checksum..."
md5sum "$INPUT" | awk '{print $1}' > "${INPUT}.md5"
echo "  ${BASE}.md5 = $(cat "${INPUT}.md5")"

if [ "$INPUT_SIZE" -le "$MAX_SIZE_BYTES" ]; then
    echo "Status:   File is under ${MAX_SIZE_MB}MB — no split needed"
    echo "Upload:   ${BASE}  and  ${BASE}.md5"
    exit 0
fi

if [ "$MODE" = "image" ]; then
    command -v zip >/dev/null 2>&1 || { echo "Error: 'zip' is required for --image mode"; exit 1; }

    # Store the already-compressed image with no extra deflate (store-only).
    ZIP_STEM="${BASE%.gz}"
    ZIP_STEM="${ZIP_STEM%.xz}"
    ZIP_STEM="${ZIP_STEM%.zst}"
    ZIP_STEM="${ZIP_STEM%.img}"
    ZIP_OUT="${DIR}/${ZIP_STEM}.zip"

    rm -f "${ZIP_OUT}" "${ZIP_OUT%.zip}".z[0-9][0-9] "${DIR}/${ZIP_STEM}.z[0-9][0-9]" 2>/dev/null || true
    # zip -s creates: name.zip, name.z01, name.z02, ...
    # -0 = store only (img.gz is already compressed)
    # -j = junk paths (flat archive)
    echo "Creating multi-volume ZIP (${MAX_SIZE_MB}MB volumes, store-only)..."
    (
        cd "$DIR"
        rm -f "${ZIP_STEM}.zip" "${ZIP_STEM}".z[0-9][0-9]
        zip -0 -j -s "${MAX_SIZE_MB}m" "${ZIP_STEM}.zip" "${BASE}"
    )

    echo ""
    echo "=== Done (Windows flash set) ==="
    echo "Upload every volume of this set to the GitHub Release:"
    ls -lh "${DIR}/${ZIP_STEM}.zip" "${DIR}/${ZIP_STEM}".z[0-9][0-9] 2>/dev/null || ls -lh "${DIR}/${ZIP_STEM}".z*
    echo "  ${BASE}.md5"
    echo ""
    echo "End-user instructions (Windows):"
    echo "  1. Download ALL files: ${ZIP_STEM}.zip + ${ZIP_STEM}.z01 + ${ZIP_STEM}.z02 ..."
    echo "  2. Keep them in the same folder (do not rename)"
    echo "  3. Open ${ZIP_STEM}.zip with 7-Zip or WinZip → Extract"
    echo "  4. Flash the resulting ${BASE} with balenaEtcher / Rufus"
    exit 0
fi

# ---- OTA raw parts (device reassembles) ----
NUM_PARTS=$(( (INPUT_SIZE + MAX_SIZE_BYTES - 1) / MAX_SIZE_BYTES ))
echo "Parts:    ${NUM_PARTS} (at most ${MAX_SIZE_MB}MB each)"

rm -f "${INPUT}".part[0-9][0-9] "${INPUT}.parts.md5"
echo "Splitting..."
split -b "$MAX_SIZE_BYTES" -d -a 2 "$INPUT" "${INPUT}.part"

PART_NUM=0
for part in "${INPUT}".part[0-9][0-9]; do
    [ -f "$part" ] || continue
    PART_NUM=$((PART_NUM + 1))
    NEW_NAME="${INPUT}.part$(printf '%02d' $PART_NUM)"
    if [ "$part" != "$NEW_NAME" ]; then
        mv "$part" "$NEW_NAME"
    fi
    PART_SIZE=$(stat -c%s "$NEW_NAME" 2>/dev/null || stat -f%z "$NEW_NAME" 2>/dev/null)
    echo "  $(basename "$NEW_NAME") ($((PART_SIZE / 1024 / 1024))MB)"
done

md5sum "${INPUT}".part[0-9][0-9] > "${INPUT}.parts.md5"

echo ""
echo "=== Done (OTA set) ==="
echo "Upload to the GitHub Release:"
echo "  batocera.version"
echo "  ${BASE}.md5"
echo "  ${BASE}.part01 .. part$(printf '%02d' "$PART_NUM")"
echo "(batocera-upgrade joins parts on the device — no PC script needed)"
