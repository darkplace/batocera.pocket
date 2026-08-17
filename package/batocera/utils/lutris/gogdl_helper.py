"""Batocera helpers for GOG installs via Heroic gogdl."""

from __future__ import annotations

import json
import os
from glob import glob
from typing import Optional

from lutris import settings
from lutris.util import system
from lutris.util.log import logger

INSTALL_HELPER = "/usr/bin/batocera-lutris-gog-install"


def get_install_helper_path() -> str:
    return INSTALL_HELPER


def find_gogdl() -> Optional[str]:
    env = os.environ.get("BATOCERA_GOGDL") or ""
    if env and system.path_exists(env) and os.access(env, os.X_OK):
        return env
    if system.path_exists("/usr/bin/gogdl") and os.access("/usr/bin/gogdl", os.X_OK):
        return "/usr/bin/gogdl"
    for pattern in (
        "/usr/share/heroic/heroic-arm64/Heroic-*/resources/app.asar.unpacked/build/bin/arm64/linux/gogdl",
        "/usr/share/heroic/*/resources/app.asar.unpacked/build/bin/*/linux/gogdl",
    ):
        for match in sorted(glob(pattern)):
            if os.access(match, os.X_OK):
                return match
    if system.can_find_executable("gogdl"):
        try:
            return system.find_required_executable("gogdl")
        except Exception:
            return None
    return None


def is_available() -> bool:
    return bool(find_gogdl())


def has_lutris_gog_auth() -> bool:
    token = os.path.join(settings.CACHE_DIR, ".gog.token")
    if not system.path_exists(token):
        return False
    try:
        with open(token, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        return bool(data.get("access_token") or data.get("refresh_token"))
    except Exception as ex:
        logger.warning("Failed reading GOG token: %s", ex)
        return False
