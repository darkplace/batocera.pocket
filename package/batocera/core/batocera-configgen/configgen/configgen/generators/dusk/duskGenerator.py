from __future__ import annotations

import os
from pathlib import Path
from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import CACHE, CONFIGS, SAVES, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


def _is_rgds() -> bool:
    for path in ("/proc/device-tree/compatible", "/sys/firmware/devicetree/base/compatible"):
        try:
            with open(path, "rb") as compat:
                if b"anbernic,rg-ds" in compat.read().split(b"\0"):
                    return True
        except OSError:
            pass

    return False


class DuskGenerator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "dusk",
            "keys": {
                "exit": ["KEY_LEFTALT", "KEY_F4"],
                "menu": "KEY_ESC",
                "pause": "KEY_ESC"
            }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        duskConfigDir = CONFIGS / "dusk"
        duskSaveDir = SAVES / "dusk"
        duskCacheDir = CACHE / "dusk"
        romDir = Path("/userdata/roms/dusk")

        mkdir_if_not_exists(duskConfigDir)
        mkdir_if_not_exists(duskSaveDir)
        mkdir_if_not_exists(duskCacheDir)

        # Start in the content folder so Dusk's own menu/file picker opens
        # where the user was told to place the Twilight Princess RVZ.
        if rom.parent.exists():
            os.chdir(rom.parent)
        elif romDir.exists():
            os.chdir(romDir)

        backend = system.config.get("dusk_graphics_backend", "vulkan")
        commandArray = [
            "/usr/bin/dusk",
            "--backend", backend,
            "--cvar", "video.enableFullscreen=true",
            "--cvar", f"backend.graphicsBackend={backend}"
        ]

        dvdImage = rom
        defaultDvdImage = romDir / "Twilight Princess.rvz"
        if not dvdImage.exists() and defaultDvdImage.exists():
            dvdImage = defaultDvdImage

        if dvdImage.exists():
            commandArray.append(str(dvdImage))

        if _is_rgds():
            commandArray.extend([
                "--cvar", "video.enableVsync=false",
                "--cvar", "game.internalResolutionScale=1",
                "--cvar", "game.shadowResolutionMultiplier=1",
                "--cvar", "game.bloomMode=0",
                "--cvar", "game.enableDepthOfField=false",
                "--cvar", "game.disableWaterRefraction=true",
                "--cvar", "game.enableFrameInterpolation=false",
                "--cvar", "game.enableMapBackground=false"
            ])

        env = {
            "DUSK_DATA_DIR": "/usr/lib/dusk",
            "XDG_CONFIG_HOME": CONFIGS,
            "XDG_DATA_HOME": duskSaveDir,
            "XDG_CACHE_HOME": duskCacheDir,
            "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
            "SDL_JOYSTICK_HIDAPI": "0",
            "SDL_AUDIODRIVER": system.config.get("dusk_audio_driver", "pulseaudio"),
            "PULSE_LATENCY_MSEC": system.config.get("dusk_audio_latency", "100"),
            "DISABLE_MANGOHUD": "1"
        }

        return Command.Command(array=commandArray, env=env)

    def getMouseMode(self, config, rom):
        return True
