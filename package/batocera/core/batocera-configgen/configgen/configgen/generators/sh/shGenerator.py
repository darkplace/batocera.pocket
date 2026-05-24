from __future__ import annotations

from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import BATOCERA_SHARE_DIR
from ...controller import generate_sdl_game_controller_config, write_sdl_controller_db
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


def _is_sm8550() -> bool:
    try:
        return (BATOCERA_SHARE_DIR / "batocera.arch").read_text().strip() == "sm8550"
    except OSError:
        return False


def _is_portmaster_launcher(path) -> bool:
    return "portmaster" in path.name.lower()


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
            env["BATOCERA_HEROIC_MODE"] = system.config.core
        elif system.config.emulator == "lutris":
            env["BATOCERA_LUTRIS_EXTRA_ARGS"] = system.config.get_str("lutris_extra_args", "")
            env["BATOCERA_LUTRIS_MODE"] = system.config.core
        elif system.config.emulator == "n64recomp":
            env["BATOCERA_N64RECOMP_EXTRA_ARGS"] = system.config.get_str("n64recomp_extra_args", "")
        elif system.config.emulator == "apps":
            env["BATOCERA_APPS_EXTRA_ARGS"] = system.config.get_str("apps_extra_args", "")
            env["BATOCERA_APPS_NO_SANDBOX"] = system.config.get_bool("apps_no_sandbox", return_values=("1", "0"))

        if _is_sm8550() and _is_portmaster_launcher(shrom):
            env.update({
                "SDL_VIDEODRIVER": "wayland",
                "SDL_RENDER_DRIVER": "software",
                "SDL_RENDER_VSYNC": "0",
                "DISABLE_MANGOHUD": "1",
                "DISABLE_LSFG": "1",
            })

        return Command.Command(array=commandArray, env=env)

    def getMouseMode(self, config, rom):
        return True
