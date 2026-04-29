from __future__ import annotations

from typing import TYPE_CHECKING

from configgen.Command import Command
from configgen.batoceraPaths import CONFIGS
from configgen.controller import Controller
from configgen.controller import generate_sdl_game_controller_config, write_sdl_controller_db
from configgen.generators.Generator import Generator

if TYPE_CHECKING:
    from pathlib import Path

    from configgen.Emulator import Emulator
    from configgen.controllersConfig import ControllersConfig


_FREEJ2ME_HOME = CONFIGS / "freej2me"
_DEFAULT_RESOLUTION = "240x320"
_DEFAULT_SCALE = "3"


class FreeJ2MEGenerator(Generator):
    @staticmethod
    def _get_resolution(config: Emulator) -> tuple[str, str]:
        resolution = config.config.get("j2me_phone_resolution", _DEFAULT_RESOLUTION)
        if "x" not in resolution:
            return ("240", "320")

        width, height = resolution.lower().split("x", 1)
        if not width.isdigit() or not height.isdigit():
            return ("240", "320")

        return (width, height)

    def getHotkeysContext(self):
        return {
            "name": "freej2me",
            "keys": {"exit": "batocera-es-swissknife --emukill 0.5"},
        }

    def getMouseMode(self, config: Emulator, rom: Path) -> bool:
        return True

    def generate(self, system: Emulator, rom: Path, players_controllers: ControllersConfig, metadata: dict, guns: list[Controller], wheels: list[Controller], gameResolution: dict) -> Command:
        (_FREEJ2ME_HOME / "home").mkdir(parents=True, exist_ok=True)
        write_sdl_controller_db(players_controllers)

        command_array = ["/usr/bin/freej2me"]
        if str(rom) != "config" and rom.name != "config":
            width, height = self._get_resolution(system)
            command_array.extend([rom.resolve().as_uri(), width, height])

        return Command(array=command_array, env={
            "FREEJ2ME_HOME": _FREEJ2ME_HOME,
            "HOME": _FREEJ2ME_HOME / "home",
            "XDG_CONFIG_HOME": CONFIGS,
            "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(players_controllers),
            "SDL_JOYSTICK_HIDAPI": "0",
        })
