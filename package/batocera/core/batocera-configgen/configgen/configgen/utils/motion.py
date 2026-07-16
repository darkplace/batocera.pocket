from __future__ import annotations

import os
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .configparser import CaseSensitiveRawConfigParser


DSU_HOST = "127.0.0.1"
DSU_DEFAULT_PORT = 26760
DSU_READY_FILE = Path("/var/run/batocera-qcom-motion.ready")
DSU_PID_FILE = Path("/var/run/batocera-qcom-motion.pid")
DSU_SWITCH_GUID = "00000000-0000-0000-0000-00007f000001"


def get_builtin_dsu_server() -> tuple[str, int] | None:
    try:
        pid = int(DSU_PID_FILE.read_text().strip())
        os.kill(pid, 0)
        port = int(DSU_READY_FILE.read_text().strip())
    except (OSError, ValueError):
        return None

    if not 1 <= port <= 65535:
        return None
    return DSU_HOST, port


def configure_switch_dsu_motion(parser: CaseSensitiveRawConfigParser) -> None:
    server = get_builtin_dsu_server()
    if server is None:
        return

    host, port = server
    binding = (
        f"engine:cemuhookudp,guid:{DSU_SWITCH_GUID},"
        f"port:{port},pad:0,motion:0"
    )
    parser.set("Controls", "motion_enabled", "true")
    parser.set("Controls", r"motion_enabled\default", "false")
    parser.set("Controls", "udp_input_servers", f"{host}:{port}")
    parser.set("Controls", r"udp_input_servers\default", "false")
    for motion in ("motionleft", "motionright"):
        parser.set("Controls", rf"player_0_{motion}", f'"{binding}"')
        parser.set("Controls", rf"player_0_{motion}\default", "false")
