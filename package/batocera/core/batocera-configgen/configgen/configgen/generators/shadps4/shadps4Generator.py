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
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import TYPE_CHECKING

import toml

from ... import Command
from ...batoceraPaths import CONFIGS, configure_emulator, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ...utils import fex_sdl, lsfg, vulkan
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
SHADPS4_PATCHES_SHARE = Path("/usr/share/shadps4/patches/shadPS4")
_SHADPS4_HANDHELD_PATCHES = frozenset({
    "Skip Intro",
    "Performance Patch (perf increase)",
    "Disable Motion Blur (perf increase)",
    "Disable Dynamic Light Shadows (perf increase)",
    "Disable Chromatic Aberration",
    "Disable AA",
    "Disable DoF",
    "FMOD Crash Fix",
    "Resolution Patch 1280x720 (16:9)",
})
_SHADPS4_PATCH_DENY = re.compile(
    r"(?i)60\s*fps|90\s*fps|uncap|no dead|stealth|silent|debug menu|"
    r"4k|1440|2160|2560|3840|5120|1080p|1440p"
)


def _is_aarch64() -> bool:
    return os.uname().machine.lower() in ("aarch64", "arm64")


def _render_size(system, gameResolution) -> tuple[int, int]:
    native = (int(gameResolution["width"]), int(gameResolution["height"]))
    raw = system.config.get_str("shadps4_resolution", "").strip().lower()
    if not raw:
        raw = "1280x720" if _is_aarch64() else "native"
    if raw in {"native", "display", "auto"}:
        return native
    if "x" not in raw:
        return native
    width_str, height_str = raw.split("x", 1)
    try:
        width, height = int(width_str), int(height_str)
    except ValueError:
        return native
    if width < 320 or height < 240:
        return native
    return width, height


def _should_enable_community_patch(name: str) -> bool:
    if name in _SHADPS4_HANDHELD_PATCHES:
        return True
    if _SHADPS4_PATCH_DENY.search(name):
        return False
    return "(perf increase)" in name or name.startswith("Skip Intro") or "FMOD Crash Fix" in name


def _apply_community_patch_enables(xml_path: Path) -> None:
    text = xml_path.read_text(encoding="utf-8", errors="replace")
    if 'isEnabled="true"' in text:
        return

    def _repl(match: re.Match[str]) -> str:
        tag = re.sub(r'\s+isEnabled="[^"]*"', "", match.group(0))
        name_match = re.search(r'\bName="([^"]+)"', tag)
        name = name_match.group(1) if name_match else ""
        enabled = "true" if _should_enable_community_patch(name) else "false"
        return tag[:-1] + f' isEnabled="{enabled}">'

    updated, count = re.subn(r"<Metadata\b[^>]*>", _repl, text)
    if count:
        xml_path.write_text(updated, encoding="utf-8")


def _write_patches_index(patch_dir: Path) -> None:
    index: dict[str, list[str]] = {}
    for xml_path in sorted(patch_dir.glob("*.xml")):
        text = xml_path.read_text(encoding="utf-8", errors="replace")
        index[xml_path.name] = re.findall(r"<ID>\s*(CUSA\d+)\s*</ID>", text, flags=re.I)
    (patch_dir / "files.json").write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")


def _seed_community_patches(user_config_path: Path) -> None:
    dest = user_config_path / "patches" / "shadPS4"
    mkdir_if_not_exists(dest)
    copied = False
    if SHADPS4_PATCHES_SHARE.is_dir():
        for xml_path in SHADPS4_PATCHES_SHARE.glob("*.xml"):
            target = dest / xml_path.name
            if target.exists():
                continue
            try:
                shutil.copy2(xml_path, target)
                copied = True
            except OSError as exc:
                _logger.warning("Unable to install shadPS4 community patch %s: %s", xml_path.name, exc)
    if _is_aarch64():
        for xml_path in dest.glob("*.xml"):
            try:
                _apply_community_patch_enables(xml_path)
            except OSError as exc:
                _logger.warning("Unable to enable shadPS4 community patch %s: %s", xml_path.name, exc)
    if copied or not (dest / "files.json").is_file():
        try:
            _write_patches_index(dest)
        except OSError as exc:
            _logger.warning("Unable to index shadPS4 community patches: %s", exc)


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
        _seed_community_patches(userConfigPath)

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
        trophy_notification_side = system.config.get_str("shadps4_trophy_position", "right")
        if trophy_notification_side not in {"left", "right", "top", "bottom"}:
            trophy_notification_side = "right"
        trophy_notification_duration = system.config.get_int("shadps4_trophy_duration", 6)
        trophy_notification_duration = min(max(trophy_notification_duration, 1), 10)
        ps4_pro_enabled = system.config.get_bool("shadps4_ps4pro", False)
        show_splash = system.config.get_bool("shadps4_show_splash", False)
        show_fps = system.config.get_bool("shadps4_show_fps", False)
        console_language = system.config.get_int("shadps4_console_lang", 1)
        general_config["isTrophyPopupDisabled"] = not trophy_notifications_enabled
        general_config["trophyNotificationDuration"] = float(trophy_notification_duration)
        general_config["sideTrophy"] = trophy_notification_side
        general_config["isPS4Pro"] = ps4_pro_enabled
        general_config["showSplash"] = show_splash

        _prepare_ps3_trophy_sound(userConfigPath)

        render_width, render_height = _render_size(system, gameResolution)

        # GPU
        gpu_config = config.setdefault("GPU", {})
        gpu_config["Fullscreen"] = True
        gpu_config["FullscreenMode"] = "Fullscreen (Borderless)"
        gpu_config["screenWidth"] = render_width
        gpu_config["screenHeight"] = render_height

        hdr_enabled = system.config.get_bool("shadps4_hdr", False)
        copy_gpu_buffers = system.config.get_bool("shadps4_copy_gpu_buffers", False)
        patch_shaders = system.config.get_bool("shadps4_patch_shaders", True)
        fsr_enabled = system.config.get_bool("shadps4_fsr", False)
        rcas_enabled = system.config.get_bool("shadps4_rcas", False)
        present_mode = system.config.get_str("shadps4_present_mode", "Mailbox")
        if present_mode not in {"Mailbox", "Fifo", "Immediate"}:
            present_mode = "Mailbox"
        vblank_frequency = system.config.get_int("shadps4_vblank_freq", 60)
        if not 30 <= vblank_frequency <= 360:
            vblank_frequency = 60
        readbacks_mode = system.config.get_int("shadps4_readbacks_mode", 0)
        if readbacks_mode not in {0, 1, 2}:
            readbacks_mode = 0
        direct_memory_access = system.config.get_bool("shadps4_dma", False)
        pipeline_cache_enabled = system.config.get_bool("shadps4_pipeline_cache", True)
        pipeline_cache_archived = system.config.get_bool("shadps4_pipeline_cache_archive", False)
        motion_controls_enabled = system.config.get_bool("shadps4_motion_controls", True)
        logging_enabled = system.config.get_bool("shadps4_logging", True)

        gpu_config["allowHDR"] = hdr_enabled
        gpu_config["copyGPUBuffers"] = copy_gpu_buffers
        gpu_config["patchShaders"] = patch_shaders
        gpu_config["fsrEnabled"] = fsr_enabled
        gpu_config["rcasEnabled"] = rcas_enabled
        gpu_config["presentMode"] = present_mode
        gpu_config["vblankFrequency"] = vblank_frequency
        gpu_config["readbacksMode"] = readbacks_mode
        gpu_config["directMemoryAccess"] = direct_memory_access

        # GUI
        gui_config = config.setdefault("GUI", {})
        gui_config["addonInstallDir"] = str(dlcPath)
        gui_config["installDirs"] = [str(romDir)]
        gui_config["saveDataPath"] = str(savesPath)
        gui_config["mw_width"] = render_width
        gui_config["mw_height"] = render_height
        gui_config["geometry_w"] = render_width
        gui_config["geometry_h"] = render_height
        gui_config["pkgDirs"] = [str(romDir)]

        # Vulkan - Set the detected GPU ID
        vulkan_config = config.setdefault("Vulkan", {})
        vulkan_config["gpuId"] = int(discrete_index)
        vulkan_config["pipelineCacheEnable"] = pipeline_cache_enabled
        vulkan_config["pipelineCacheArchive"] = pipeline_cache_archived

        input_config = config.setdefault("Input", {})
        input_config["useUnifiedInputConfig"] = True
        input_config["backgroundControllerInput"] = True
        input_config["isMotionControlsEnabled"] = motion_controls_enabled

        debug_config = config.setdefault("Debug", {})
        debug_config["showFpsCounter"] = show_fps

        log_config = config.setdefault("Log", {})
        log_config["enable"] = logging_enabled

        settings_config = config.setdefault("Settings", {})
        settings_config["consoleLanguage"] = console_language

        # Create necessary directories if they do not exist
        mkdir_if_not_exists(toml_file.parent)

        # Now write the updated toml
        with toml_file.open("w") as f:
            toml.dump(config, f)

        shadPS4Generator._write_json_overrides(
            json_file,
            {
                "General": {
                    "addon_install_dir": str(dlcPath),
                    "discord_rpc_enabled": False,
                    "home_dir": str(savesPath),
                    "install_dirs": [{"enabled": True, "path": str(romDir)}],
                    "neo_mode": ps4_pro_enabled,
                    "show_fps_counter": show_fps,
                    "show_splash": show_splash,
                    "console_language": console_language,
                    "trophy_notification_duration": float(trophy_notification_duration),
                    "trophy_notification_side": trophy_notification_side,
                    "trophy_popup_disabled": not trophy_notifications_enabled,
                },
                "Input": {
                    "background_controller_input": True,
                    "motion_controls_enabled": motion_controls_enabled,
                    "use_unified_input_config": True,
                },
                "GPU": {
                    "copy_gpu_buffers": copy_gpu_buffers,
                    "direct_memory_access_enabled": direct_memory_access,
                    "fsr_enabled": fsr_enabled,
                    "full_screen": True,
                    "full_screen_mode": "Fullscreen (Borderless)",
                    "hdr_allowed": hdr_enabled,
                    "patch_shaders": patch_shaders,
                    "present_mode": present_mode,
                    "rcas_enabled": rcas_enabled,
                    "readbacks_mode": readbacks_mode,
                    "vblank_frequency": vblank_frequency,
                    "window_height": render_height,
                    "window_width": render_width,
                },
                "Log": {
                    "enable": logging_enabled,
                },
                "Vulkan": {
                    "gpu_id": int(discrete_index),
                    "pipeline_cache_archived": pipeline_cache_archived,
                    "pipeline_cache_enabled": pipeline_cache_enabled,
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

        lsfg.apply_lsfg_vk(system, environment)

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
