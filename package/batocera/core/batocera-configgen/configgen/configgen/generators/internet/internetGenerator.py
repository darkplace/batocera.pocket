from __future__ import annotations

import os
import shutil
from typing import TYPE_CHECKING
from urllib.parse import urlparse

from ... import Command
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


def _read_url(path) -> str:
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""

    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("["):
            continue

        if line.lower().startswith("url="):
            line = line.split("=", 1)[1].strip()

        parsed = urlparse(line)
        if parsed.scheme in {"http", "https"} and parsed.netloc:
            return line

    return ""


class InternetGenerator(Generator):

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        url = _read_url(rom)
        browser = shutil.which("batocera-app-firefox") or shutil.which("firefox") or shutil.which("xdg-open")

        if not browser:
            browser = "/usr/bin/xdg-open"

        env = {
            "XDG_RUNTIME_DIR": os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}",
        }

        return Command.Command(array=[browser, url], env=env)

    def getMouseMode(self, config, rom):
        return True

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "firefox",
            "keys": {
                "exit": "pkill -TERM -f '(^|[[:space:]/])(firefox|batocera-app-firefox)([[:space:]]|$)'"
            },
        }
