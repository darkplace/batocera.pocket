from __future__ import annotations

import os
import shutil
from pathlib import Path
from typing import TYPE_CHECKING, Any

import toml

from ... import Command
from ...batoceraPaths import CONFIGS, configure_emulator, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config, write_sdl_controller_db
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


_NANOBOYADVANCE_CONFIG_DIR = CONFIGS / "nanoboyadvance"
_NANOBOYADVANCE_HOME_DIR = _NANOBOYADVANCE_CONFIG_DIR / "home"
_NANOBOYADVANCE_CONFIG_FILE = _NANOBOYADVANCE_CONFIG_DIR / "config.toml"
_NANOBOYADVANCE_DEFAULT_CONFIG = Path("/usr/share/nanoboyadvance/config.toml")


def _ensure_default_config() -> None:
    mkdir_if_not_exists(_NANOBOYADVANCE_CONFIG_DIR)
    mkdir_if_not_exists(_NANOBOYADVANCE_HOME_DIR)
    if not _NANOBOYADVANCE_CONFIG_FILE.exists():
        shutil.copy2(_NANOBOYADVANCE_DEFAULT_CONFIG, _NANOBOYADVANCE_CONFIG_FILE)


def _set_nested(mapping: dict[str, Any], *keys: str, value: Any) -> None:
    current = mapping
    for key in keys[:-1]:
        current = current.setdefault(key, {})
    current[keys[-1]] = value


class NanoBoyAdvanceGenerator(Generator):
    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "nanoboyadvance",
            "keys": {"exit": ["KEY_LEFTALT", "KEY_F4"]},
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        _ensure_default_config()

        with _NANOBOYADVANCE_CONFIG_FILE.open(encoding="utf-8") as config_file:
            config: dict[str, Any] = toml.load(config_file)

        _set_nested(config, "general", "bios_path", value="/userdata/bios/gba_bios.bin")
        _set_nested(config, "general", "bios_skip", value=system.config.get_bool("nanoboyadvance_bios_skip", False))
        _set_nested(config, "general", "sync_to_audio", value=system.config.get_bool("nanoboyadvance_sync_to_audio", False))
        _set_nested(config, "video", "fullscreen", value=not configure_emulator(rom))
        _set_nested(config, "video", "scale", value=system.config.get_int("nanoboyadvance_scale", 2))
        _set_nested(config, "audio", "resampler", value=system.config.get("nanoboyadvance_audio_resampler", "cubic"))
        _set_nested(config, "audio", "interpolate_fifo", value=system.config.get_bool("nanoboyadvance_interpolate_fifo", True))
        _set_nested(config, "audio", "mp2k_hle_enable", value=system.config.get_bool("nanoboyadvance_mp2k_hle_enable", False))
        _set_nested(config, "audio", "mp2k_hle_cubic", value=system.config.get_bool("nanoboyadvance_mp2k_hle_cubic", False))

        with _NANOBOYADVANCE_CONFIG_FILE.open("w", encoding="utf-8") as config_file:
            toml.dump(config, config_file)

        write_sdl_controller_db(playersControllers)

        launcher_path = _NANOBOYADVANCE_CONFIG_DIR / "NanoBoyAdvance"
        if launcher_path.is_symlink() or launcher_path.exists():
            launcher_path.unlink()
        launcher_path.symlink_to("/usr/bin/NanoBoyAdvance")

        command_array = [str(launcher_path), "--bios", "/userdata/bios/gba_bios.bin"]
        if not configure_emulator(rom):
            command_array.append(str(rom))

        return Command.Command(
            array=command_array,
            env={
                "HOME": str(_NANOBOYADVANCE_HOME_DIR),
                "XDG_CONFIG_HOME": str(CONFIGS),
                "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
                "SDL_JOYSTICK_HIDAPI": "0",
            },
        )

    def getInGameRatio(self, config, gameResolution, rom):
        return 3 / 2
