#!/bin/sh
# Install official shadPS4 community XML patches (ps4_cheats).
# Usage: install-community-patches.sh DEST_DIR
set -eu

DEST="${1:?destination directory}"
URL="${SHADPS4_CHEATS_URL:-https://github.com/shadps4-emu/ps4_cheats/archive/refs/heads/main.tar.gz}"
WORKDIR="${TMPDIR:-/tmp}/shadps4-cheats-$$"

mkdir -p "$DEST" "$WORKDIR"
trap 'rm -rf "$WORKDIR"' EXIT

curl -fL --retry 3 -o "$WORKDIR/cheats.tar.gz" "$URL"
tar -xzf "$WORKDIR/cheats.tar.gz" -C "$WORKDIR"
PATCH_SRC="$(find "$WORKDIR" -type d -name PATCHES | head -n 1)"
if [ -z "$PATCH_SRC" ]; then
	echo "shadps4 community patches: PATCHES directory missing from archive" >&2
	exit 1
fi

find "$PATCH_SRC" -maxdepth 1 -name '*.xml' -exec cp -f {} "$DEST/" \;

python3 - "$DEST" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
index = {}
for xml_path in sorted(root.glob("*.xml")):
    text = xml_path.read_text(encoding="utf-8", errors="replace")
    index[xml_path.name] = re.findall(r"<ID>\s*(CUSA\d+)\s*</ID>", text, flags=re.I)
(root / "files.json").write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")
print(f"shadps4 community patches: {len(index)} xml files")
PY
