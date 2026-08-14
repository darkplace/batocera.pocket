#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} INPUT.json OUTPUT.yml", file=sys.stderr)
        return 2
    src = Path(sys.argv[1])
    dest = Path(sys.argv[2])
    payload = json.loads(src.read_text(encoding="utf-8"))
    if payload.get("return_code") != 0 or not payload.get("patch"):
        print(f"rpcs3 community patches: unexpected payload {payload!r}", file=sys.stderr)
        return 1
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(payload["patch"], encoding="utf-8")
    print(f"rpcs3 community patches: wrote {dest} ({dest.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
