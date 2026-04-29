from __future__ import annotations

from typing import TYPE_CHECKING

from ... import Command
from ...controller import generate_sdl_game_controller_config, write_sdl_controller_db
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


class ShGenerator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "shell",
            "keys": { "exit": ["KEY_LEFTALT", "KEY_F4"] }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        # in case of squashfs, the root directory is passed
        runsh = rom / "run.sh"
        shrom = runsh if runsh.exists() else rom

        # PortMaster uses this.
        write_sdl_controller_db(playersControllers)

        commandArray = ["/bin/bash", shrom]
        env = {
            "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers)
        }

        if system.config.emulator == "heroic":
            env["BATOCERA_HEROIC_EXTRA_ARGS"] = system.config.get_str("heroic_extra_args", "")
        elif system.config.emulator == "lutris":
            env["BATOCERA_LUTRIS_EXTRA_ARGS"] = system.config.get_str("lutris_extra_args", "")
        elif system.config.emulator == "apps":
            env["BATOCERA_APPS_EXTRA_ARGS"] = system.config.get_str("apps_extra_args", "")
            env["BATOCERA_APPS_NO_SANDBOX"] = system.config.get_bool("apps_no_sandbox", return_values=("1", "0"))

        return Command.Command(array=commandArray, env=env)

    def getMouseMode(self, config, rom):
        return True
