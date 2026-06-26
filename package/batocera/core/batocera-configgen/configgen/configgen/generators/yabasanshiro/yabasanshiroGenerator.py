from __future__ import annotations

import json
from pathlib import Path
from typing import TYPE_CHECKING, Any

from ... import Command
from ...batoceraPaths import CONFIGS, configure_emulator, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config, write_sdl_controller_db
from ...input import Input
from ..Generator import Generator

if TYPE_CHECKING:
    from ...controller import Controller
    from ...types import HotkeysContext


_CONFIG_HOME = CONFIGS / "yabasanshiro"
_YABA_DATA_DIR = _CONFIG_HOME / ".yabasanshiro"
_KEYMAP_FILE = _YABA_DATA_DIR / "keymapv2.json"


def _int(value: str | int, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _input_entry(input: Input | None, *, analog: bool = False) -> dict[str, int | str] | None:
    if input is None:
        return None

    if analog and input.type == "axis":
        return {"type": "axis", "id": _int(input.id), "value": 0}

    if input.type in {"button", "axis", "hat", "key"}:
        return {"type": input.type, "id": _int(input.id), "value": _int(input.value, 1)}

    return None


def _add_binding(bindings: dict[str, Any], yaba_name: str, pad: Controller, input_name: str, *, analog: bool = False) -> None:
    entry = _input_entry(pad.inputs.get(input_name), analog=analog)
    if entry is not None:
        bindings[yaba_name] = entry


def _device_key(pad: Controller) -> str:
    return f"{pad.index}_{pad.real_name}_{pad.guid}"


def _controller_keymap(pad: Controller) -> dict[str, Any]:
    bindings: dict[str, Any] = {}

    for name in ("up", "down", "left", "right", "start"):
        _add_binding(bindings, name, pad, name)

    # ROCKNIX standalone mapping: Saturn A/B/C/X/Y/Z -> ES Y/B/A/X/L1/R1.
    _add_binding(bindings, "a", pad, "y")
    _add_binding(bindings, "b", pad, "b")
    _add_binding(bindings, "c", pad, "a")
    _add_binding(bindings, "x", pad, "x")
    _add_binding(bindings, "y", pad, "pageup")
    _add_binding(bindings, "z", pad, "pagedown")
    _add_binding(bindings, "l", pad, "l2")
    _add_binding(bindings, "r", pad, "r2")
    _add_binding(bindings, "select", pad, "hotkey")
    if "select" not in bindings:
        _add_binding(bindings, "select", pad, "select")

    _add_binding(bindings, "analogx", pad, "joystick1left", analog=True)
    _add_binding(bindings, "analogy", pad, "joystick1up", analog=True)
    _add_binding(bindings, "analogleft", pad, "l2", analog=True)
    _add_binding(bindings, "analogright", pad, "r2", analog=True)

    return bindings


def _write_keymap(players_controllers) -> None:
    keymap: dict[str, Any] = {}

    for pad in players_controllers[:2]:
        player_key = f"player{pad.player_number}"
        keymap[player_key] = {
            "DeviceID": pad.index,
            "deviceGUID": pad.guid,
            "deviceName": pad.real_name,
            "padmode": 0,
        }
        keymap[_device_key(pad)] = _controller_keymap(pad)

    with _KEYMAP_FILE.open("w", encoding="utf-8") as keymap_file:
        json.dump(keymap, keymap_file, indent=2)
        keymap_file.write("\n")


def _write_game_config(system, rom: Path) -> None:
    config = {
        "Aspect rate": 1 if system.config.get_bool("yabasanshiro_keep_aspect", True) else 0,
        "Resolution": system.config.get_int("yabasanshiro_resolution", 2),
        "Rotate screen": system.config.get_bool("yabasanshiro_rotate_screen", False),
        "Rotate screen resolution": system.config.get_int("yabasanshiro_rotate_resolution", 0),
        "Use compute shader": system.config.get_bool("yabasanshiro_compute_shader", False),
    }

    game_config = _YABA_DATA_DIR / f"{rom.name}.config"
    with game_config.open("w", encoding="utf-8") as config_file:
        json.dump(config, config_file, indent=2)
        config_file.write("\n")


def _bios_argument(config) -> Path | None:
    bios = config.get("yabasanshiro_bios")
    if bios is config.MISSING or bios in {"", "emulated"}:
        return None

    bios_path = Path(str(bios))
    if bios_path.exists():
        return bios_path

    return None


class YabaSanshiroGenerator(Generator):
    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "yabasanshiro",
            "keys": {
                "exit": "killall -9 yabasanshiro",
                "menu": "KEY_ESC",
                "save_state": "KEY_F5",
                "previous_slot": "KEY_F6",
                "restore_state": "KEY_F7",
                "next_slot": "KEY_F8",
            },
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        mkdir_if_not_exists(_CONFIG_HOME)
        mkdir_if_not_exists(_YABA_DATA_DIR)
        _write_keymap(playersControllers)
        write_sdl_controller_db(playersControllers)

        command_array: list[str | Path] = ["/usr/bin/yabasanshiro"]

        if not configure_emulator(rom):
            _write_game_config(system, rom)
            command_array.extend([
                "-r",
                str(system.config.get_int("yabasanshiro_resolution", 2)),
                "-i",
                rom,
            ])

            if bios_path := _bios_argument(system.config):
                command_array.extend(["-b", bios_path])

            command_array.extend(["-s", str(system.config.get_int("yabasanshiro_scsp_sync", 1))])

            if system.config.get_bool("yabasanshiro_keep_aspect", True):
                command_array.append("-a")

            if not system.config.get_bool("yabasanshiro_frameskip", True):
                command_array.append("-nf")

        return Command.Command(
            array=command_array,
            env={
                "HOME": str(_CONFIG_HOME),
                "XDG_CONFIG_HOME": str(CONFIGS),
                "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
                "SDL_JOYSTICK_HIDAPI": "0",
            },
        )

    def getInGameRatio(self, config, gameResolution, rom):
        return 4 / 3
