from __future__ import annotations

from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import BATOCERA_SHARE_DIR
from ...controller import generate_sdl_game_controller_config
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext

def _is_sm8550() -> bool:
    try:
        return (BATOCERA_SHARE_DIR / "batocera.arch").read_text().strip() == "sm8550"
    except OSError:
        return False

def _sm8550_sdl_ui_env() -> dict[str, str]:
    if not _is_sm8550():
        return {}

    return {
        "DISPLAY": "",
        "SDL_VIDEODRIVER": "wayland",
        "SDL_RENDER_VSYNC": "0",
        "MESA_LOADER_DRIVER_OVERRIDE": "zink",
        "DISABLE_MANGOHUD": "1",
        "DISABLE_LSFG": "1",
    }

class OdcommanderGenerator(Generator):

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        commandArray = ["od-commander"]
        env = {
            "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers)
        }
        env.update(_sm8550_sdl_ui_env())

        return Command.Command(array=commandArray,env=env)

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "odcommander",
            "keys": { "exit": ["KEY_LEFTALT", "KEY_F4"] }
        }
