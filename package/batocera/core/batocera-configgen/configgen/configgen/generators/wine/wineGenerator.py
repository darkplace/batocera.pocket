from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import TYPE_CHECKING

from ... import Command
from ...controller import generate_sdl_game_controller_config
from ...utils import fex_sdl, lsfg
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


def _is_fex_wine(system) -> bool:
    return (
        system.config.get_bool("fex", False)
        or system.config.get_str("aarch64_wine_mode", "").strip().lower() == "fex"
    )


class WineGenerator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "wine",
            "keys": {
                "exit": "/usr/bin/batocera-wine windows stop"
            }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):

        if system.name == "windows_installers":
            commandArray = ["batocera-wine", "windows", "install", rom]
            return Command.Command(array=commandArray)

        if system.name == "windows":
            commandArray = ["batocera-wine", "windows", "play", rom]
            hud = system.config.get("hud", "none")
            if hud and hud != "none":
                commandArray.insert(0, "mangohud")

            environment: dict[str, str | Path] = {}

            # --------------------------------------------------
            # Box64 support (ARM64 only)
            # --------------------------------------------------
            if (
                Path("/usr/bin/box64").exists()
                and os.uname().machine == "aarch64"
            ):
                environment.update({
                    "BOX64": "1",
                    "BOX64_PATH": "/usr/bin",
                    "BOX64_NOBANNER": "1",
                })
                if (
                    system.config.get_bool("fex", False)
                    or system.config.get_str("aarch64_wine_mode", "").strip().lower() == "fex"
                ):
                    environment.update({
                        "BATOCERA_WINE_USE_FEX": "1",
                        "BOX64": "0",
                    })

            # --------------------------------------------------
            # Language
            # --------------------------------------------------
            try:
                language = subprocess.check_output(
                    "batocera-settings-get system.language",
                    shell=True,
                    text=True
                ).strip()
            except subprocess.CalledProcessError:
                language = "en_US"

            if language:
                environment.update({
                    "LANG": language + ".UTF-8",
                    "LC_ALL": language + ".UTF-8"
                })

            # --------------------------------------------------
            # SDL controller configuration
            # --------------------------------------------------
            if system.config.get_bool("sdl_config", True):
                if _is_fex_wine(system):
                    sdl_controller_config = fex_sdl.generate_sdl_game_controller_config(playersControllers)
                else:
                    sdl_controller_config = generate_sdl_game_controller_config(playersControllers)

                environment.update({
                    "SDL_GAMECONTROLLERCONFIG": sdl_controller_config,
                    "SDL_JOYSTICK_HIDAPI": "0"
                })
                if _is_fex_wine(system):
                    environment.update({
                        "FEX_ENV": f"SDL_GAMECONTROLLERCONFIG={sdl_controller_config}",
                        "SDL_XINPUT_ENABLED": "1",
                        "SDL_JOYSTICK_RAWINPUT": "0",
                        "SDL_JOYSTICK_DIRECTINPUT": "0",
                        "SDL_DIRECTINPUT_ENABLED": "0",
                    })

            # --------------------------------------------------
            # NVIDIA PRIME / Vulkan cleanup
            # --------------------------------------------------
            if Path("/var/tmp/nvidia.prime").exists():
                variables_to_remove = [
                    "__NV_PRIME_RENDER_OFFLOAD",
                    "__VK_LAYER_NV_optimus",
                    "__GLX_VENDOR_LIBRARY_NAME"
                ]
                for variable_name in variables_to_remove:
                    if variable_name in os.environ:
                        del os.environ[variable_name]

                environment.update({
                    "VK_ICD_FILENAMES":
                        "/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json:"
                        "/usr/share/vulkan/icd.d/nvidia_icd.i686.json"
                })

            lsfg.apply_lsfg_vk(system, environment, use_wine_layer=True, defer_layer_env=True)

            return Command.Command(
                array=commandArray,
                env=environment
            )

        raise BatoceraException("Invalid system: " + system.name)

    def hasInternalMangoHUDCall(self):
        return True

    def getMouseMode(self, config, rom):
        return config.get_bool("force_mouse")
