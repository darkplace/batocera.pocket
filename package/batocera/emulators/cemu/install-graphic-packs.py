#!/usr/bin/env python3
from __future__ import annotations

import shutil
import sys
import zipfile
from pathlib import Path

KEEP = {"Enhancements", "Graphics", "Mods", "Resolutions", "Workarounds"}


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} packs.zip DEST_DIR", file=sys.stderr)
        return 2
    archive = Path(sys.argv[1])
    dest = Path(sys.argv[2])
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as zf:
        names = zf.namelist()
        roots = {name.split("/", 1)[0] for name in names if name}
        if len(roots) != 1:
            print(f"cemu graphic packs: unexpected archive layout {sorted(roots)}", file=sys.stderr)
            return 1
        extract = archive.parent / "extracted"
        shutil.rmtree(extract, ignore_errors=True)
        zf.extractall(extract)
        src = extract / next(iter(roots))
    copied = 0
    for child in src.iterdir():
        if child.name not in KEEP or not child.is_dir():
            continue
        target = dest / child.name
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(child, target)
        copied += 1
    print(f"cemu graphic packs: installed {copied} categories into {dest}")
    return 0 if copied else 1


if __name__ == "__main__":
    raise SystemExit(main())
