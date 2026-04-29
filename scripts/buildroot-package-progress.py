#!/usr/bin/env python3

import json
import os
import re
import sys
from pathlib import Path

try:
    import fcntl
except ImportError:  # pragma: no cover
    fcntl = None


def usage():
    print(
        "usage:\n"
        "  buildroot-package-progress.py setup <state> <base_dir> <build_order> <show_info>\n"
        "  buildroot-package-progress.py prefix <state> <package>\n"
        "  buildroot-package-progress.py <start|end> <step> <package>",
        file=sys.stderr,
    )
    return 1


def read_json(path: Path):
    text = path.read_text(encoding="utf-8", errors="replace")

    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end < start:
        raise ValueError("no JSON object found in {}".format(path))

    return json.loads(text[start : end + 1])


def read_build_order(path: Path):
    ordered_packages = []
    seen_packages = set()
    package_name = re.compile(r"^[A-Za-z0-9][A-Za-z0-9+_.-]*$")

    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        pkg = raw_line.strip()
        if not pkg or not package_name.match(pkg) or pkg in seen_packages:
            continue
        seen_packages.add(pkg)
        ordered_packages.append(pkg)

    return ordered_packages


def build_state(base_dir: Path, build_order_path: Path, show_info_path: Path) -> dict:
    ordered_packages = read_build_order(build_order_path)
    info = read_json(show_info_path)

    pending = {}
    for pkg in ordered_packages:
        pkg_info = info.get(pkg)
        if not pkg_info or pkg_info.get("virtual"):
            continue

        stamp_dir = pkg_info.get("stamp_dir")
        if not stamp_dir:
            continue

        final_stamp = base_dir / stamp_dir / ".stamp_installed"
        if not final_stamp.exists():
            pending[pkg] = True

    return {
        "version": 1,
        "total": len(pending),
        "current": 0,
        "pending": pending,
        "seen": {},
    }


def write_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(state, handle, sort_keys=True)


def with_locked_state(path: Path, callback):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+", encoding="utf-8") as handle:
        if fcntl is not None:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        handle.seek(0)
        try:
            state = json.load(handle)
        except json.JSONDecodeError:
            state = {
                "version": 1,
                "total": 0,
                "current": 0,
                "pending": {},
                "seen": {},
            }
        result = callback(state)
        handle.seek(0)
        handle.truncate()
        json.dump(state, handle, sort_keys=True)
        handle.flush()
        os.fsync(handle.fileno())
        if fcntl is not None:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        return result


def cmd_setup(argv):
    if len(argv) != 4:
        return usage()

    state_path = Path(argv[0])
    base_dir = Path(argv[1])
    build_order_path = Path(argv[2])
    show_info_path = Path(argv[3])

    state = build_state(base_dir, build_order_path, show_info_path)
    write_state(state_path, state)
    return 0


def cmd_prefix(argv):
    if len(argv) != 2:
        return usage()

    state_path = Path(argv[0])
    package = argv[1]

    if not state_path.exists():
        return 0

    try:
        state = read_json(state_path)
    except json.JSONDecodeError:
        return 0

    index = state.get("seen", {}).get(package)
    total = state.get("total", 0)
    if index and total:
        print(f"<{index}/{total}> ", end="")
    return 0


def cmd_step(argv):
    if len(argv) != 3:
        return usage()

    action, _step, package = argv
    if action != "start":
        return 0

    state_file = os.environ.get("BR2_PACKAGE_PROGRESS_STATE")
    if not state_file:
        return 0

    state_path = Path(state_file)

    def update(state: dict):
        pending = state.get("pending", {})
        if package not in pending:
            return None
        seen = state.setdefault("seen", {})
        if package in seen:
            return None
        state["current"] = int(state.get("current", 0)) + 1
        seen[package] = state["current"]
        return None

    with_locked_state(state_path, update)
    return 0


def main(argv):
    if not argv:
        return usage()

    command = argv[0]
    if command == "setup":
        return cmd_setup(argv[1:])
    if command == "prefix":
        return cmd_prefix(argv[1:])
    if command in {"start", "end"}:
        return cmd_step(argv)
    return usage()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
