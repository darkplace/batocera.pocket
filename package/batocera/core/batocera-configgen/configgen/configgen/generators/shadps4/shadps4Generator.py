#
# This file is part of the batocera distribution (https://batocera.org).
# Copyright (c) 2025+.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# YOU MUST KEEP THIS HEADER AS IT IS
#
from __future__ import annotations

import json
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import TYPE_CHECKING

import toml

from ... import Command
from ...batoceraPaths import CONFIGS, configure_emulator, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ...utils import fex_sdl, vulkan
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext

_logger = logging.getLogger(__name__)

SHADPS4_NATIVE_BIN = Path("/usr/bin/shadps4/shadps4")
SHADPS4_FEX_BIN = Path("/usr/bin/shadps4-fex")
SHADPS4_FEX_APP_CONFIG_DIR = Path("/usr/share/fex-emu/shadps4-fex")
SHADPS4_FEX_APP_CONFIG = SHADPS4_FEX_APP_CONFIG_DIR / "shadps4-fex.json"
SHADPS4_TROPHY_SOUND_SOURCE = Path("/usr/share/libretro/assets/sounds/ps3-trophy.ogg")
SHADPS4_TROPHY_SOUND_MARKER = ".batocera-ps3-trophy"


def _is_aarch64() -> bool:
    return os.uname().machine.lower() in ("aarch64", "arm64")


def _fex_app_environment() -> dict[str, str]:
    return {
        "FEX_APP_CONFIG_LOCATION": f"{SHADPS4_FEX_APP_CONFIG_DIR}/",
        "FEX_APP_CONFIG": str(SHADPS4_FEX_APP_CONFIG),
    }


def _prepare_ps3_trophy_sound(user_config_path: Path) -> None:
    custom_trophy_path = user_config_path / "custom_trophy"
    trophy_sound = custom_trophy_path / "trophy.wav"
    marker = custom_trophy_path / SHADPS4_TROPHY_SOUND_MARKER

    # A trophy.wav without our marker belongs to the user and must not be replaced.
    if trophy_sound.is_file() and not marker.is_file():
        _logger.debug("Keeping user-provided shadPS4 trophy sound at %s", trophy_sound)
        return

    if not SHADPS4_TROPHY_SOUND_SOURCE.is_file():
        _logger.warning("Batocera PS3 trophy sound is missing: %s", SHADPS4_TROPHY_SOUND_SOURCE)
        return

    try:
        signature = (
            f"{SHADPS4_TROPHY_SOUND_SOURCE.stat().st_size}:"
            f"{SHADPS4_TROPHY_SOUND_SOURCE.stat().st_mtime_ns}\n"
        )
        if trophy_sound.is_file() and marker.is_file() and marker.read_text() == signature:
            return
    except OSError as exc:
        _logger.warning("Unable to inspect the shadPS4 trophy sound: %s", exc)
        return

    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        _logger.warning("ffmpeg is missing; cannot prepare the PS3 trophy sound for shadPS4")
        return

    mkdir_if_not_exists(custom_trophy_path)
    temporary_sound = custom_trophy_path / "trophy.tmp.wav"
    try:
        subprocess.run(
            [
                ffmpeg,
                "-y",
                "-loglevel",
                "error",
                "-i",
                str(SHADPS4_TROPHY_SOUND_SOURCE),
                "-c:a",
                "pcm_s16le",
                "-ar",
                "44100",
                "-ac",
                "2",
                str(temporary_sound),
            ],
            check=True,
        )
        temporary_sound.replace(trophy_sound)
        marker.write_text(signature)
    except (OSError, subprocess.CalledProcessError) as exc:
        _logger.warning("Failed to prepare the PS3 trophy sound for shadPS4: %s", exc)
    finally:
        temporary_sound.unlink(missing_ok=True)


class shadPS4Generator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "shadps4",
            "keys": {"exit": ["KEY_LEFTALT", "KEY_F4"]}
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):

        # Set the paths using Path objects
        configPath = CONFIGS / "shadps4"
        userConfigPath = configPath / "user"
        toml_file = userConfigPath / "config.toml"
        json_file = userConfigPath / "config.json"
        savesPath = Path("/userdata/saves/shadps4")
        romDir = Path("/userdata/roms/ps4")
        dlcPath = romDir / "DLC"

        mkdir_if_not_exists(userConfigPath)
        mkdir_if_not_exists(savesPath)

        # Check Vulkan first before doing anything
        discrete_index = -1
        if vulkan.is_available():
            _logger.debug("Vulkan driver is available on the system.")
            vulkan_version = vulkan.get_version()
            if vulkan_version > "1.3":
                _logger.debug("Using Vulkan version: %s", vulkan_version)
                if vulkan.has_discrete_gpu():
                    _logger.debug("A discrete GPU is available on the system. We will use that for performance")
                    discrete_index = vulkan.get_discrete_gpu_index()
                    if discrete_index:
                        _logger.debug("Using Discrete GPU Index: %s for shadPS4", discrete_index)
                    else:
                        _logger.debug("Couldn't get discrete GPU index")
                        discrete_index = 0
                else:
                    _logger.debug("Discrete GPU is not available on the system. Using default.")
            else:
                _logger.debug("Vulkan version: %s is not compatible with shadPS4", vulkan_version)
        else:
            _logger.debug("*** Vulkan driver required is not available on the system!!! ***")
            sys.exit(1)

        # Adjust the config.toml file
        config: dict[str, dict[str, object]] = {}

        # Check if the file exists
        if toml_file.is_file():
            try:
                with toml_file.open("r") as f:
                    config = toml.load(f)
            except Exception as e:
                 _logger.error("Failed to load existing shadps4 config: %s. Will create default.", e)

        # If config is empty, create default structure
        if not config:
             _logger.info("Creating default shadps4 config at %s", toml_file)
             config = {
                "General": {
                    "isPS4Pro": False,
                    "isTrophyPopupDisabled": False,
                    "trophyNotificationDuration": 6.0,
                    "playBGM": False,
                    "BGMvolume": 50,
                    "enableDiscordRPC": False,
                    "logFilter": "",
                    "logType": "async",
                    "userName": "Batocera",
                    "updateChannel": "Release",
                    "chooseHomeTab": "General",
                    "showSplash": False,
                    "autoUpdate": False,
                    "alwaysShowChangelog": False,
                    "sideTrophy": "right",
                    "separateUpdateEnabled": False,
                    "compatibilityEnabled": False,
                    "checkCompatibilityOnStartup": False,
                },
                "Input": {
                    "cursorState": 1,
                    "cursorHideTimeout": 5,
                    "backButtonBehavior": "left",
                    "useSpecialPad": False,
                    "specialPadClass": 1,
                    "isMotionControlsEnabled": True,
                    "useUnifiedInputConfig": True,
                },
                "GPU": {
                    "screenWidth": int(gameResolution["width"]),
                    "screenHeight": int(gameResolution["height"]),
                    "nullGpu": False,
                    "copyGPUBuffers": False,
                    "dumpShaders": False,
                    "patchShaders": True,
                    "vblankDivider": 1,
                    "Fullscreen": True,
                    "FullscreenMode": "Fullscreen (Borderless)",
                    "allowHDR": False,
                },
                "Vulkan": {
                    "gpuId": int(discrete_index),
                    "validation": False,
                    "validation_sync": False,
                    "validation_gpu": False,
                    "crashDiagnostic": False,
                    "hostMarkers": False,
                    "guestMarkers": False,
                    "rdocEnable": False,
                },
                "Debug": {
                    "DebugDump": False,
                    "CollectShader": False,
                    "isSeparateLogFilesEnabled": False,
                    "FPSColor": True,
                },
                "Keys": {
                    "TrophyKey": ""
                 },
                "GUI": {
                    "installDirs": [str(romDir)],
                    "saveDataPath": str(savesPath),
                    "loadGameSizeEnabled": True,
                    "addonInstallDir": str(dlcPath),
                    "emulatorLanguage": "en_US",
                    "backgroundImageOpacity": 50,
                    "showBackgroundImage": True,
                    "mw_width": int(gameResolution["width"]),
                    "mw_height": int(gameResolution["height"]),
                    "theme": 0,
                    "iconSize": 36,
                    "sliderPos": 0,
                    "iconSizeGrid": 69,
                    "sliderPosGrid": 0,
                    "gameTableMode": 0,
                    "geometry_x": 0,
                    "geometry_y": 0,
                    "geometry_w": int(gameResolution["width"]),
                    "geometry_h": int(gameResolution["height"]),
                    "pkgDirs": [str(romDir)],
                    "elfDirs": [],
                    "recentFiles": [],
                },
                "Settings": {
                    "consoleLanguage": 1
                },
             }

        # --- Apply Batocera Specific Overrides ---
        # General
        general_config = config.setdefault("General", {})
        general_config["autoUpdate"] = False
        general_config["enableDiscordRPC"] = False
        general_config["userName"] = "Batocera"
        trophy_notifications_enabled = system.config.get_bool("shadps4_achievements", True)
        general_config["isTrophyPopupDisabled"] = not trophy_notifications_enabled

        _prepare_ps3_trophy_sound(userConfigPath)

        # GPU
        gpu_config = config.setdefault("GPU", {})
        gpu_config["Fullscreen"] = True
        gpu_config["FullscreenMode"] = "Fullscreen (Borderless)"
        gpu_config["screenWidth"] = int(gameResolution["width"])
        gpu_config["screenHeight"] = int(gameResolution["height"])

        # GUI
        gui_config = config.setdefault("GUI", {})
        gui_config["addonInstallDir"] = str(dlcPath)
        gui_config["installDirs"] = [str(romDir)]
        gui_config["saveDataPath"] = str(savesPath)
        gui_config["mw_width"] = int(gameResolution["width"])
        gui_config["mw_height"] = int(gameResolution["height"])
        gui_config["geometry_w"] = int(gameResolution["width"])
        gui_config["geometry_h"] = int(gameResolution["height"])
        gui_config["pkgDirs"] = [str(romDir)]

        # Vulkan - Set the detected GPU ID
        config.setdefault("Vulkan", {})["gpuId"] = int(discrete_index)

        input_config = config.setdefault("Input", {})
        input_config["useUnifiedInputConfig"] = True
        input_config["backgroundControllerInput"] = True

        # Options
        if system.config.get_bool("shadps4_hdr"):
            gpu_config["allowHDR"] = True
        else:
            gpu_config["allowHDR"] = False
        if system.config.get("shadps4_console_lang"):
            config["Settings"]["consoleLanguage"] = int(system.config["shadps4_console_lang"])
        else:
            config["Settings"]["consoleLanguage"] = 1

        # Create necessary directories if they do not exist
        mkdir_if_not_exists(toml_file.parent)

        # Now write the updated toml
        with toml_file.open("w") as f:
            toml.dump(config, f)

        shadPS4Generator._write_json_overrides(
            json_file,
            {
                "General": {
                    "trophy_popup_disabled": not trophy_notifications_enabled,
                },
                "Input": {
                    "use_unified_input_config": True,
                    "background_controller_input": True,
                },
            },
        )

        # Change to the configPath directory before running
        os.chdir(configPath)

        # Determine the path based on extension
        if rom.is_dir():
            eboot_path = rom / "eboot.bin"
        else:
            eboot_path = rom.parent / "eboot.bin"

        use_fex = _is_aarch64() and SHADPS4_FEX_BIN.exists()
        commandBase: list[str | Path] = [SHADPS4_FEX_BIN] if use_fex else [SHADPS4_NATIVE_BIN]

        # Run command
        if configure_emulator(rom):
            commandArray = commandBase
        else:
            commandArray = [*commandBase, eboot_path]

        fex_app_environment = _fex_app_environment() if use_fex and SHADPS4_FEX_APP_CONFIG.exists() else {}
        if use_fex:
            sdl_controller_config = fex_sdl.generate_sdl_game_controller_config(
                playersControllers,
                fex_app_environment,
            )
        else:
            sdl_controller_config = generate_sdl_game_controller_config(playersControllers)

        environment = {
            "SDL_GAMECONTROLLERCONFIG": sdl_controller_config,
            "SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS": "1",
            "SDL_JOYSTICK_HIDAPI": "0"
        }
        if use_fex:
            environment.update(fex_app_environment)
            environment.update({
                "FEX_ENV": f"SDL_GAMECONTROLLERCONFIG={sdl_controller_config}",
                "SDL_XINPUT_ENABLED": "1",
                "SDL_JOYSTICK_RAWINPUT": "0",
                "SDL_JOYSTICK_DIRECTINPUT": "0",
                "SDL_DIRECTINPUT_ENABLED": "0",
            })

        return Command.Command(
            array=commandArray,
            env=environment
        )

    @staticmethod
    def _write_json_overrides(path: Path, overrides: dict[str, dict[str, object]]) -> None:
        data: dict[str, object] = {}
        if path.is_file():
            try:
                with path.open("r") as f:
                    loaded = json.load(f)
                if isinstance(loaded, dict):
                    data = loaded
            except Exception as e:
                _logger.error("Failed to load existing shadps4 json config: %s. Will create default.", e)

        for section, values in overrides.items():
            current = data.setdefault(section, {})
            if not isinstance(current, dict):
                current = {}
                data[section] = current
            current.update(values)

        with path.open("w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")

    def getInGameRatio(self, config, gameResolution, rom):
        return 16 / 9
