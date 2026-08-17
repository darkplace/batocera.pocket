"""Batocera helpers to install Epic Games titles via Legendary."""

from __future__ import annotations

import json
import os
from glob import glob
from typing import Optional

from lutris import settings
from lutris.util import system
from lutris.util.log import logger

INSTALL_HELPER = "/usr/bin/batocera-lutris-egs-install"

_LEGENDARY_CANDIDATES = (
    os.environ.get("BATOCERA_LEGENDARY") or "",
    "/usr/bin/legendary",
)


def get_install_helper_path() -> str:
    return INSTALL_HELPER


def find_legendary() -> Optional[str]:
    for path in _LEGENDARY_CANDIDATES:
        if path and system.path_exists(path) and os.access(path, os.X_OK):
            return path
    for pattern in (
        "/usr/share/heroic/heroic-arm64/Heroic-*/resources/app.asar.unpacked/build/bin/arm64/linux/legendary",
        "/usr/share/heroic/*/resources/app.asar.unpacked/build/bin/*/linux/legendary",
    ):
        matches = sorted(glob(pattern))
        for match in matches:
            if os.access(match, os.X_OK):
                return match
    if system.can_find_executable("legendary"):
        try:
            return system.find_required_executable("legendary")
        except Exception:
            return None
    return None


def is_available() -> bool:
    if not system.path_exists(INSTALL_HELPER):
        # Helper may be missing on old images; still OK if legendary exists —
        # installer require-binaries will fail clearly.
        return bool(find_legendary())
    return bool(find_legendary())


def lutris_egs_token_path() -> Optional[str]:
    candidates = (
        os.path.join(settings.CACHE_DIR, ".egs.token"),
        os.path.expanduser("~/.cache/lutris/.egs.token"),
        "/userdata/saves/lutris/.cache/lutris/.egs.token",
    )
    for path in candidates:
        if path and system.path_exists(path):
            return path
    return None


def has_lutris_egs_auth() -> bool:
    path = lutris_egs_token_path()
    if not path:
        return False
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        return bool(data.get("refresh_token") or data.get("access_token"))
    except Exception as ex:
        logger.warning("Failed reading EGS token %s: %s", path, ex)
        return False
