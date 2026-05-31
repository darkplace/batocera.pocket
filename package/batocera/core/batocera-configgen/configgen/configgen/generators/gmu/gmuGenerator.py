from __future__ import annotations

from typing import TYPE_CHECKING

from ... import Command
from ...controller import generate_sdl_game_controller_config, write_sdl_controller_db
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


class GmuGenerator(Generator):

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        write_sdl_controller_db(playersControllers)

        env = {
            "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
        }

        command = ["/usr/bin/start_gmu.sh"]
        if rom.suffix.lower() != ".sh":
            command.append(str(rom))

        return Command.Command(array=command, env=env)

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "gmu",
            "keys": {
                "exit": "pkill -HUP gmu.bin"
            },
        }
