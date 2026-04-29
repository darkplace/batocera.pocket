from __future__ import annotations

import os
import shutil
from pathlib import Path
from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import CACHE, CONF_INIT, CONFIGS, HOME, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


ARES_CONFIG = CONFIGS / "ares"
ARES_DATA = HOME / ".local" / "share" / "ares"
ARES_INIT = CONF_INIT / "ares"


class AresGenerator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "ares",
            "keys": { "exit": ["KEY_LEFTALT", "KEY_F4"] }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        self._ensure_config()

        env = {
            "XDG_CONFIG_HOME": CONFIGS,
            "XDG_DATA_HOME": HOME,
            "XDG_CACHE_HOME": CACHE,
            "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
            "SDL_JOYSTICK_HIDAPI": "0",
        }

        command_array: list[str | Path] = ["/usr/bin/ares", "--fullscreen", rom]
        match system.config.get("ares_cores"):
            case "little":
                command_array = ["taskset", "-c", "0-3", *command_array]
            case "big":
                command_array = ["taskset", "-c", "4-7", *command_array]

        return Command.Command(array=command_array, env=env)

    @staticmethod
    def _ensure_config() -> None:
        mkdir_if_not_exists(ARES_CONFIG)

        settings = ARES_CONFIG / "settings.bml"
        if not settings.exists():
            initial_settings = ARES_INIT / "settings.bml"
            if initial_settings.exists():
                shutil.copy2(initial_settings, settings)

        mkdir_if_not_exists(ARES_DATA.parent)
        if ARES_DATA.exists() or ARES_DATA.is_symlink():
            if ARES_DATA.is_symlink() and ARES_DATA.resolve() == ARES_CONFIG:
                return
            if ARES_DATA.is_dir() and not ARES_DATA.is_symlink():
                shutil.rmtree(ARES_DATA)
            else:
                ARES_DATA.unlink()
        os.symlink(ARES_CONFIG, ARES_DATA)
