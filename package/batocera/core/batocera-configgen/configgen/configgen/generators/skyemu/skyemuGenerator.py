from __future__ import annotations

import struct
from pathlib import Path
from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import CONFIGS, configure_emulator, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config, write_sdl_controller_db
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


_SKYEMU_CONFIG_DIR = CONFIGS / "SkyEmu"
_SKYEMU_HOME_DIR = CONFIGS / "skyemu-home"
_SKYEMU_LINK_DIR = _SKYEMU_HOME_DIR / ".local" / "share" / "Sky"
_SKYEMU_SETTINGS_FILE = _SKYEMU_CONFIG_DIR / "user_settings.bin"
_SKYEMU_SETTINGS_SIZE = 1024
_SKYEMU_SETTINGS_VERSION = 3

_OFFSET_DRAW_DEBUG_MENU = 0
_OFFSET_VOLUME = 4
_OFFSET_THEME = 8
_OFFSET_SETTINGS_FILE_VERSION = 12
_OFFSET_GB_PALETTE = 16
_OFFSET_GHOSTING = 32
_OFFSET_COLOR_CORRECTION = 36
_OFFSET_INTEGER_SCALING = 40
_OFFSET_SCREEN_SHADER = 44
_OFFSET_SCREEN_ROTATION = 48
_OFFSET_STRETCH_TO_FIT = 52
_OFFSET_AUTO_HIDE_TOUCH_CONTROLS = 56
_OFFSET_TOUCH_CONTROLS_OPACITY = 60
_OFFSET_ALWAYS_SHOW_MENUBAR = 64
_OFFSET_LANGUAGE = 68
_OFFSET_TOUCH_CONTROLS_SCALE = 72
_OFFSET_TOUCH_CONTROLS_SHOW_TURBO = 76
_OFFSET_SAVE_TO_PATH = 80
_OFFSET_FORCE_DMG_MODE = 84
_OFFSET_GBA_COLOR_CORRECTION_MODE = 88
_OFFSET_HTTP_CONTROL_SERVER_PORT = 92
_OFFSET_HTTP_CONTROL_SERVER_ENABLE = 96
_OFFSET_AVOID_OVERLAPING_TOUCHSCREEN = 100
_OFFSET_CUSTOM_FONT_SCALE = 104
_OFFSET_HARDCORE_MODE = 108
_OFFSET_DRAW_CHALLENGE_INDICATORS = 112
_OFFSET_DRAW_PROGRESS_INDICATORS = 116
_OFFSET_DRAW_LEADERBOARD_TRACKERS = 120
_OFFSET_DRAW_NOTIFICATIONS = 124
_OFFSET_GUI_SCALE_FACTOR = 128
_OFFSET_ONLY_ONE_NOTIFICATION = 132
_OFFSET_ENABLE_DOWNLOAD_CACHE = 136
_OFFSET_NDS_LAYOUT = 140
_OFFSET_TOUCH_SCREEN_SHOW_BUTTON_LABELS = 144
_OFFSET_SHOW_SCREEN_BEZEL = 148


def _store_u32(blob: bytearray, offset: int, value: int) -> None:
    struct.pack_into("<I", blob, offset, value)


def _store_f32(blob: bytearray, offset: int, value: float) -> None:
    struct.pack_into("<f", blob, offset, value)


def _default_settings_blob() -> bytearray:
    blob = bytearray(_SKYEMU_SETTINGS_SIZE)
    _store_u32(blob, _OFFSET_DRAW_DEBUG_MENU, 0)
    _store_f32(blob, _OFFSET_VOLUME, 0.8)
    _store_u32(blob, _OFFSET_THEME, 0)
    _store_u32(blob, _OFFSET_SETTINGS_FILE_VERSION, _SKYEMU_SETTINGS_VERSION)
    for index, color in enumerate((0x00388F81, 0x00437D64, 0x003F6D56, 0x002D4A31)):
        _store_u32(blob, _OFFSET_GB_PALETTE + (index * 4), color)
    _store_f32(blob, _OFFSET_GHOSTING, 1.0)
    _store_f32(blob, _OFFSET_COLOR_CORRECTION, 1.0)
    _store_u32(blob, _OFFSET_INTEGER_SCALING, 0)
    _store_u32(blob, _OFFSET_SCREEN_SHADER, 3)
    _store_u32(blob, _OFFSET_SCREEN_ROTATION, 0)
    _store_u32(blob, _OFFSET_STRETCH_TO_FIT, 0)
    _store_u32(blob, _OFFSET_AUTO_HIDE_TOUCH_CONTROLS, 1)
    _store_f32(blob, _OFFSET_TOUCH_CONTROLS_OPACITY, 0.5)
    _store_u32(blob, _OFFSET_ALWAYS_SHOW_MENUBAR, 1)
    _store_u32(blob, _OFFSET_LANGUAGE, 0)
    _store_f32(blob, _OFFSET_TOUCH_CONTROLS_SCALE, 1.0)
    _store_u32(blob, _OFFSET_TOUCH_CONTROLS_SHOW_TURBO, 1)
    _store_u32(blob, _OFFSET_SAVE_TO_PATH, 0)
    _store_u32(blob, _OFFSET_FORCE_DMG_MODE, 0)
    _store_u32(blob, _OFFSET_GBA_COLOR_CORRECTION_MODE, 0)
    _store_u32(blob, _OFFSET_HTTP_CONTROL_SERVER_PORT, 8080)
    _store_u32(blob, _OFFSET_HTTP_CONTROL_SERVER_ENABLE, 0)
    _store_u32(blob, _OFFSET_AVOID_OVERLAPING_TOUCHSCREEN, 1)
    _store_f32(blob, _OFFSET_CUSTOM_FONT_SCALE, 1.0)
    _store_u32(blob, _OFFSET_HARDCORE_MODE, 0)
    _store_u32(blob, _OFFSET_DRAW_CHALLENGE_INDICATORS, 1)
    _store_u32(blob, _OFFSET_DRAW_PROGRESS_INDICATORS, 1)
    _store_u32(blob, _OFFSET_DRAW_LEADERBOARD_TRACKERS, 1)
    _store_u32(blob, _OFFSET_DRAW_NOTIFICATIONS, 1)
    _store_f32(blob, _OFFSET_GUI_SCALE_FACTOR, 1.0)
    _store_u32(blob, _OFFSET_ONLY_ONE_NOTIFICATION, 0)
    _store_u32(blob, _OFFSET_ENABLE_DOWNLOAD_CACHE, 1)
    _store_u32(blob, _OFFSET_NDS_LAYOUT, 0)
    _store_u32(blob, _OFFSET_TOUCH_SCREEN_SHOW_BUTTON_LABELS, 1)
    _store_u32(blob, _OFFSET_SHOW_SCREEN_BEZEL, 1)
    return blob


def _load_or_default_settings() -> bytearray:
    if _SKYEMU_SETTINGS_FILE.exists():
        data = bytearray(_SKYEMU_SETTINGS_FILE.read_bytes())
        if len(data) >= _SKYEMU_SETTINGS_SIZE:
            return data[:_SKYEMU_SETTINGS_SIZE]
    return _default_settings_blob()


def _ensure_symlink(link: Path, target: Path) -> None:
    if link.is_symlink():
        if link.resolve() == target.resolve():
            return
        link.unlink()
    elif link.exists():
        return

    link.symlink_to(target)


class SkyEmuGenerator(Generator):
    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "skyemu",
            "keys": {"exit": "batocera-es-swissknife --emukill 0.5"},
        }

    def getMouseMode(self, config, rom):
        return True

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        mkdir_if_not_exists(_SKYEMU_CONFIG_DIR)
        mkdir_if_not_exists(_SKYEMU_LINK_DIR)
        _ensure_symlink(_SKYEMU_LINK_DIR / "SkyEmu", _SKYEMU_CONFIG_DIR)
        settings_blob = _load_or_default_settings()
        _store_u32(settings_blob, _OFFSET_SETTINGS_FILE_VERSION, _SKYEMU_SETTINGS_VERSION)
        _store_u32(settings_blob, _OFFSET_INTEGER_SCALING, 1 if system.config.get_bool("skyemu_integer_scaling", False) else 0)
        _store_u32(settings_blob, _OFFSET_STRETCH_TO_FIT, 1 if system.config.get_bool("skyemu_stretch_to_fit", False) else 0)
        _store_u32(settings_blob, _OFFSET_SHOW_SCREEN_BEZEL, 1 if system.config.get_bool("skyemu_show_screen_bezel", True) else 0)
        _SKYEMU_SETTINGS_FILE.write_bytes(settings_blob)

        retroachievements_enabled = system.config.get_bool("retroachievements")
        ra_token = _SKYEMU_CONFIG_DIR / "ra_token.txt"
        if retroachievements_enabled and (username := system.config.get("retroachievements.username")) and (token := system.config.get("retroachievements.token")):
            ra_token.write_text(f"{username}\n{token}\n", encoding="utf-8")
        elif ra_token.exists():
            ra_token.unlink()

        write_sdl_controller_db(playersControllers)

        command_array = ["/usr/bin/SkyEmu"]
        if not configure_emulator(rom):
            command_array.extend(["fullscreen", str(rom)])

        return Command.Command(
            array=command_array,
            env={
                "HOME": str(_SKYEMU_HOME_DIR),
                "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
                "SDL_JOYSTICK_HIDAPI": "0",
                "SKYEMU_RA_HARDCORE_MODE": "1" if retroachievements_enabled and system.config.get_bool("retroachievements.hardcore") else "0",
                "SKYEMU_RA_DRAW_NOTIFICATIONS": "1" if retroachievements_enabled else "0",
                "SKYEMU_RA_DRAW_PROGRESS_INDICATORS": "1" if retroachievements_enabled and system.config.get_bool("retroachievements.challenge_indicators", True) else "0",
                "SKYEMU_RA_DRAW_LEADERBOARD_TRACKERS": "1" if retroachievements_enabled and system.config.get_bool("retroachievements.leaderboards", True) else "0",
                "SKYEMU_RA_DRAW_CHALLENGE_INDICATORS": "1" if retroachievements_enabled and system.config.get_bool("retroachievements.challenge_indicators", True) else "0",
                "SKYEMU_RA_ENCORE_MODE": "1" if retroachievements_enabled and system.config.get_bool("retroachievements.encore") else "0",
                "SKYEMU_RA_UNOFFICIAL": "1" if retroachievements_enabled and system.config.get_bool("retroachievements.unofficial") else "0",
            },
        )
