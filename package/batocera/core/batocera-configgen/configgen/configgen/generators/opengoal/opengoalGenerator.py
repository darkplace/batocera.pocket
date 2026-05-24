from __future__ import annotations

from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import CACHE, CONFIGS, SAVES, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


class OpengoalGenerator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "opengoal",
            "keys": {
                "exit": ["KEY_LEFTALT", "KEY_F4"],
                "menu": "KEY_ESC",
                "pause": "KEY_ESC"
            }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        opengoalConfigDir = CONFIGS / "opengoal"
        opengoalSaveDir = SAVES / "opengoal"
        opengoalCacheDir = CACHE / "opengoal"

        mkdir_if_not_exists(opengoalConfigDir)
        mkdir_if_not_exists(opengoalSaveDir)
        mkdir_if_not_exists(opengoalCacheDir)

        game = system.config.get("opengoal_game", "auto")
        commandArray = ["/usr/bin/opengoal"]

        if game != "auto":
            commandArray.extend(["--game", game])

        if system.config.get("opengoal_rebuild", "0") == "1":
            commandArray.append("--rebuild")

        resolution = system.config.get("opengoal_resolution", "screen")
        if resolution == "screen" and gameResolution:
            resolution = f'{gameResolution["width"]}x{gameResolution["height"]}'
        if resolution and resolution != "default":
            commandArray.extend(["--resolution", resolution])
            commandArray.extend(["--window-size", "fullscreen"])

        aspect = system.config.get("opengoal_aspect", "auto")
        if aspect:
            commandArray.extend(["--aspect", aspect])

        commandArray.extend(["--fps", system.config.get("opengoal_fps", "60")])
        commandArray.extend(["--msaa", system.config.get("opengoal_msaa", "0")])
        commandArray.extend(["--vsync", system.config.get("opengoal_vsync", "1")])
        commandArray.extend(["--skip-movies", system.config.get("opengoal_skip_movies", "1")])

        if rom.exists():
            commandArray.append(str(rom))

        env = {
            "XDG_CONFIG_HOME": opengoalConfigDir,
            "XDG_DATA_HOME": opengoalSaveDir,
            "XDG_CACHE_HOME": opengoalCacheDir,
            "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
            "SDL_JOYSTICK_HIDAPI": "0",
            "DISABLE_MANGOHUD": "1"
        }

        audioBackend = system.config.get("opengoal_audio_backend", "pulse")
        if audioBackend != "auto":
            env["CUBEB_BACKEND"] = audioBackend

        audioDriver = system.config.get("opengoal_audio_driver", "auto")
        if audioDriver != "auto":
            env["SDL_AUDIODRIVER"] = audioDriver

        return Command.Command(array=commandArray, env=env)

    def getMouseMode(self, config, rom):
        return True
