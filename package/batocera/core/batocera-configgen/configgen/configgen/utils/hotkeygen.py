from __future__ import annotations

import json
import logging
import subprocess
from contextlib import contextmanager
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from collections.abc import Iterator

    from ..Emulator import Emulator
    from ..generators.Generator import Generator

_logger = logging.getLogger(__name__)


_HOTKEYGEN_INIT = Path("/etc/init.d/S90hotkeygen")
_HOTKEYGEN_PID = Path("/var/run/hotkeygen.pid")


def _hotkeygen_permanent_running() -> bool:
    try:
        pid = int(_HOTKEYGEN_PID.read_text().strip())
        cmdline = Path(f"/proc/{pid}/cmdline").read_text().replace("\0", " ")
    except (FileNotFoundError, ProcessLookupError, ValueError):
        return False

    return "hotkeygen" in cmdline and "--permanent" in cmdline


def _ensure_hotkeygen_running() -> None:
    if _hotkeygen_permanent_running():
        return

    _HOTKEYGEN_PID.unlink(missing_ok=True)
    if _HOTKEYGEN_INIT.exists():
        subprocess.call([_HOTKEYGEN_INIT, "start"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


@contextmanager
def set_hotkeygen_context(generator: Generator, system: Emulator, /) -> Iterator[None]:
    # hotkeygen context
    hkc = generator.getHotkeysContext()

    exit_hotkey_only = system.config.get_bool("exithotkeyonly")

    # limit hotkeys
    # there is an option to disable all hotkeys but exit in case the player 1 is a pad with not hotkey specific button
    if exit_hotkey_only:
        if "exit" in hkc["keys"]:
            hkc["keys"] = { "exit": hkc["keys"]["exit"] }
        else:
            # should not happen while exit should always be there
            hkc["keys"] = {}

    # if uimod is not full (aka kiosk or children mode), remove the menu action
    if system.config.ui_mode != "Full" and "menu" in hkc["keys"]:
        del hkc["keys"]["menu"]

    _logger.debug("hotkeygen: updating context to %s", hkc["name"])
    _ensure_hotkeygen_running()

    cmd = ["hotkeygen", "--new-context", hkc["name"], json.dumps(hkc["keys"])]

    if exit_hotkey_only:
        cmd.append("--disable-common")

    subprocess.call(cmd)

    try:
        yield
    finally:
        # reset hotkeygen context
        _logger.debug("hotkeygen: resetting to default context")
        subprocess.call(["hotkeygen", "--default-context"])

def get_hotkeygen_event() -> str | None:
    import evdev

    for dev in evdev.list_devices():
        input_device = evdev.InputDevice(dev)
        if input_device.name == "batocera hotkeys":
            return dev
    return None
