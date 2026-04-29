from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import TYPE_CHECKING, Any

from ... import Command
from ...batoceraPaths import CONFIGS, configure_emulator, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config, write_sdl_controller_db
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


_GOPHER64_CONFIG_DIR = CONFIGS / "gopher64"
_GOPHER64_HOME_DIR = _GOPHER64_CONFIG_DIR / "home"
_GOPHER64_CONFIG_FILE = _GOPHER64_CONFIG_DIR / "config.json"
_GOPHER64_DEFAULT_CONFIG = Path("/usr/share/gopher64/config.json")
_GOPHER64_PROFILE_SIZE = 19


def _button_entry(enabled: bool, id: int) -> dict[str, int | bool]:
    return {"enabled": enabled, "id": id}


def _axis_entry(enabled: bool, id: int, axis: int) -> dict[str, int | bool]:
    return {"enabled": enabled, "id": id, "axis": axis}


def _hat_entry(enabled: bool, id: int, direction: int) -> dict[str, int | bool]:
    return {"enabled": enabled, "id": id, "direction": direction}


def _default_profile() -> dict[str, Any]:
    keys = [_button_entry(False, 0) for _ in range(_GOPHER64_PROFILE_SIZE)]
    controller_buttons = [_button_entry(False, 0) for _ in range(_GOPHER64_PROFILE_SIZE)]
    controller_axis = [_axis_entry(False, 0, 0) for _ in range(_GOPHER64_PROFILE_SIZE)]

    # Default keyboard bindings from upstream src/ui/input.rs:get_default_profile().
    keys[0] = _button_entry(True, 7)    # D
    keys[1] = _button_entry(True, 4)    # A
    keys[2] = _button_entry(True, 22)   # S
    keys[3] = _button_entry(True, 26)   # W
    keys[4] = _button_entry(True, 40)   # Return
    keys[5] = _button_entry(True, 29)   # Z
    keys[6] = _button_entry(True, 224)  # Left Ctrl
    keys[7] = _button_entry(True, 225)  # Left Shift
    keys[8] = _button_entry(True, 15)   # L
    keys[9] = _button_entry(True, 13)   # J
    keys[10] = _button_entry(True, 14)  # K
    keys[11] = _button_entry(True, 12)  # I
    keys[12] = _button_entry(True, 6)   # C
    keys[13] = _button_entry(True, 27)  # X
    keys[14] = _button_entry(True, 80)  # Left
    keys[15] = _button_entry(True, 79)  # Right
    keys[16] = _button_entry(True, 82)  # Up
    keys[17] = _button_entry(True, 81)  # Down
    keys[18] = _button_entry(True, 54)  # Comma

    # Default controller bindings from upstream src/ui/input.rs:get_default_profile().
    controller_buttons[0] = _button_entry(True, 14)  # Dpad right
    controller_buttons[1] = _button_entry(True, 13)  # Dpad left
    controller_buttons[2] = _button_entry(True, 12)  # Dpad down
    controller_buttons[3] = _button_entry(True, 11)  # Dpad up
    controller_buttons[4] = _button_entry(True, 6)   # Start
    controller_axis[5] = _axis_entry(True, 4, 1)     # Left trigger
    controller_buttons[6] = _button_entry(True, 2)   # West/X
    controller_buttons[7] = _button_entry(True, 0)   # South/A
    controller_axis[8] = _axis_entry(True, 2, 1)     # Right stick X+
    controller_axis[9] = _axis_entry(True, 2, -1)    # Right stick X-
    controller_axis[10] = _axis_entry(True, 3, 1)    # Right stick Y+
    controller_axis[11] = _axis_entry(True, 3, -1)   # Right stick Y-
    controller_buttons[12] = _button_entry(True, 10) # Right shoulder
    controller_buttons[13] = _button_entry(True, 9)  # Left shoulder
    controller_axis[14] = _axis_entry(True, 0, -1)   # Left stick X-
    controller_axis[15] = _axis_entry(True, 0, 1)    # Left stick X+
    controller_axis[16] = _axis_entry(True, 1, -1)   # Left stick Y-
    controller_axis[17] = _axis_entry(True, 1, 1)    # Left stick Y+
    controller_buttons[18] = _button_entry(True, 4)  # Back

    return {
        "keys": keys,
        "controller_buttons": controller_buttons,
        "controller_axis": controller_axis,
        "joystick_buttons": [_button_entry(False, 0) for _ in range(_GOPHER64_PROFILE_SIZE)],
        "joystick_hat": [_hat_entry(False, 0, 0) for _ in range(_GOPHER64_PROFILE_SIZE)],
        "joystick_axis": [_axis_entry(False, 0, 0) for _ in range(_GOPHER64_PROFILE_SIZE)],
        "dinput": False,
        "deadzone": 5,
    }


def _profile_complete(profile: dict[str, Any]) -> bool:
    return (
        isinstance(profile.get("keys"), list) and len(profile["keys"]) == _GOPHER64_PROFILE_SIZE
        and isinstance(profile.get("controller_buttons"), list) and len(profile["controller_buttons"]) == _GOPHER64_PROFILE_SIZE
        and isinstance(profile.get("controller_axis"), list) and len(profile["controller_axis"]) == _GOPHER64_PROFILE_SIZE
        and isinstance(profile.get("joystick_buttons"), list) and len(profile["joystick_buttons"]) == _GOPHER64_PROFILE_SIZE
        and isinstance(profile.get("joystick_hat"), list) and len(profile["joystick_hat"]) == _GOPHER64_PROFILE_SIZE
        and isinstance(profile.get("joystick_axis"), list) and len(profile["joystick_axis"]) == _GOPHER64_PROFILE_SIZE
    )


def _ensure_default_config() -> None:
    mkdir_if_not_exists(_GOPHER64_CONFIG_DIR)
    mkdir_if_not_exists(_GOPHER64_HOME_DIR)
    if not _GOPHER64_CONFIG_FILE.exists():
        shutil.copy2(_GOPHER64_DEFAULT_CONFIG, _GOPHER64_CONFIG_FILE)


def _set_nested(mapping: dict[str, Any], *keys: str, value: Any) -> None:
    current = mapping
    for key in keys[:-1]:
        current = current.setdefault(key, {})
    current[keys[-1]] = value


class Gopher64Generator(Generator):
    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "gopher64",
            "keys": {"exit": ["KEY_LEFTALT", "KEY_F4"]},
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        _ensure_default_config()

        with _GOPHER64_CONFIG_FILE.open(encoding="utf-8") as config_file:
            config: dict[str, Any] = json.load(config_file)

        _set_nested(config, "video", "upscale", value=system.config.get_int("gopher64_upscale", 1))
        _set_nested(config, "video", "integer_scaling", value=system.config.get_bool("gopher64_integer_scaling", False))
        _set_nested(config, "video", "widescreen", value=system.config.get_bool("gopher64_widescreen", False))
        _set_nested(config, "video", "crt", value=system.config.get_bool("gopher64_crt", False))
        _set_nested(config, "video", "fullscreen", value=not configure_emulator(rom))
        _set_nested(config, "emulation", "overclock", value=system.config.get_bool("gopher64_overclock", False))
        _set_nested(config, "emulation", "disable_expansion_pak", value=system.config.get_bool("gopher64_disable_expansion_pak", False))
        _set_nested(config, "emulation", "usb", value=system.config.get_bool("gopher64_usb", False))
        _set_nested(config, "input", "emulate_vru", value=system.config.get_bool("gopher64_emulate_vru", False))
        default_profile = config.setdefault("input", {}).setdefault("input_profiles", {}).get("default")
        if not isinstance(default_profile, dict) or not _profile_complete(default_profile):
            config["input"]["input_profiles"]["default"] = _default_profile()

        controller_assignment = [controller.device_path for controller in playersControllers[:4]]
        controller_assignment.extend([None] * (4 - len(controller_assignment)))
        _set_nested(config, "input", "controller_assignment", value=controller_assignment)
        _set_nested(config, "input", "controller_enabled", value=[index < len(playersControllers) for index in range(4)])
        _set_nested(config, "input", "input_profile_binding", value=["default", "default", "default", "default"])

        with _GOPHER64_CONFIG_FILE.open("w", encoding="utf-8") as config_file:
            json.dump(config, config_file, indent=2)
            config_file.write("\n")

        write_sdl_controller_db(playersControllers)

        command_array = ["/usr/bin/gopher64"]
        if not configure_emulator(rom):
            command_array.extend(["-f", str(rom)])

        return Command.Command(
            array=command_array,
            env={
                "HOME": str(_GOPHER64_HOME_DIR),
                "XDG_CONFIG_HOME": str(CONFIGS),
                "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
                "SDL_JOYSTICK_HIDAPI": "0",
            },
        )

    def getInGameRatio(self, config, gameResolution, rom):
        if config.get_bool("gopher64_widescreen", False):
            return 16 / 9
        return 4 / 3
