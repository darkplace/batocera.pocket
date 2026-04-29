from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path
from typing import TYPE_CHECKING

from ... import Command
from ...controller import _DEFAULT_SDL_MAPPING, generate_sdl_game_controller_config
from ...exceptions import BatoceraException
from ..Generator import Generator

if TYPE_CHECKING:
    from ...controller import Controller, Controllers
    from ...input import Input
    from ...types import HotkeysContext


FEX_BUTTON_CODE_TO_INDEX = {
    304: 0, 305: 1, 307: 2, 308: 3, 310: 4, 311: 5,
    314: 6, 315: 7, 316: 8, 317: 9, 318: 10,
    544: 11, 545: 12, 546: 13, 547: 14,
}

FEX_AXIS_CODE_TO_INDEX = {
    0: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 5,
}


def _is_fex_wine(system) -> bool:
    return (
        system.config.get_bool("fex", False)
        or system.config.get_str("aarch64_wine_mode", "").strip().lower() == "fex"
    )


def _fex_sdl_joysticks() -> list[dict[str, str]]:
    script = r'''
import ctypes
import json

class SDL_JoystickGUID(ctypes.Structure):
    _fields_ = [("data", ctypes.c_ubyte * 16)]

sdl = ctypes.CDLL("libSDL2-2.0.so.0")
sdl.SDL_Init.argtypes = [ctypes.c_uint32]
sdl.SDL_Init.restype = ctypes.c_int
sdl.SDL_NumJoysticks.restype = ctypes.c_int
sdl.SDL_JoystickGetDeviceGUID.argtypes = [ctypes.c_int]
sdl.SDL_JoystickGetDeviceGUID.restype = SDL_JoystickGUID
sdl.SDL_JoystickGetGUIDString.argtypes = [SDL_JoystickGUID, ctypes.c_char_p, ctypes.c_int]
sdl.SDL_JoystickNameForIndex.argtypes = [ctypes.c_int]
sdl.SDL_JoystickNameForIndex.restype = ctypes.c_char_p
sdl.SDL_JoystickPathForIndex.argtypes = [ctypes.c_int]
sdl.SDL_JoystickPathForIndex.restype = ctypes.c_char_p

devices = []
if sdl.SDL_Init(0x00000200 | 0x00002000) == 0:
    for index in range(sdl.SDL_NumJoysticks()):
        guid_buf = ctypes.create_string_buffer(64)
        guid = sdl.SDL_JoystickGetDeviceGUID(index)
        sdl.SDL_JoystickGetGUIDString(guid, guid_buf, 64)
        devices.append({
            "index": str(index),
            "name": (sdl.SDL_JoystickNameForIndex(index) or b"").decode("utf-8", "replace"),
            "path": (sdl.SDL_JoystickPathForIndex(index) or b"").decode("utf-8", "replace"),
            "guid": guid_buf.value.decode("ascii"),
        })
print(json.dumps(devices))
'''
    try:
        output = subprocess.check_output(
            ["FEXBash", "-c", f"python3 - <<'PY'\n{script}\nPY"],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=8,
        )
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return []

    try:
        data = json.loads(output.strip().splitlines()[-1])
    except (IndexError, json.JSONDecodeError):
        return []

    if isinstance(data, list):
        return [device for device in data if isinstance(device, dict)]
    return []


def _match_fex_sdl_joystick(controller: "Controller", devices: list[dict[str, str]]) -> dict[str, str] | None:
    for device in devices:
        if device.get("path") == controller.device_path:
            return device
    for device in devices:
        if device.get("name") == controller.real_name:
            return device
    if len(devices) == 1:
        return devices[0]
    return None


def _input_to_fex_sdl_mapping(keyname: str, input: "Input") -> str | None:
    if input.type == "button":
        if input.code is not None and int(input.code) in FEX_BUTTON_CODE_TO_INDEX:
            return f"{keyname}:b{FEX_BUTTON_CODE_TO_INDEX[int(input.code)]}"
        return f"{keyname}:b{input.id}"

    if input.type == "hat":
        return f"{keyname}:h{input.id}.{input.value}"

    if input.type == "axis":
        axis_id = FEX_AXIS_CODE_TO_INDEX.get(int(input.code), int(input.id)) if input.code is not None else int(input.id)
        if "joystick" in input.name:
            return f"{keyname}:a{axis_id}{'~' if int(input.value) > 0 else ''}"
        if keyname in ("dpup", "dpdown", "dpleft", "dpright"):
            return f"{keyname}:{'-' if int(input.value) < 0 else '+'}a{axis_id}"
        if "trigger" in keyname:
            return f"{keyname}:a{axis_id}{'~' if int(input.value) < 0 else ''}"
        return f"{keyname}:a{axis_id}"

    if input.type == "key":
        return None

    raise BatoceraException(f"Unknown controller input type: {input.type!r}")


def _generate_fex_sdl_game_controller_config(controllers: "Controllers") -> str:
    devices = _fex_sdl_joysticks()
    configs: list[str] = []
    for controller in controllers:
        device = _match_fex_sdl_joystick(controller, devices)
        if device is None or not device.get("guid"):
            configs.append(controller.generate_sdl_game_db_line())
            continue

        config = [device["guid"], device.get("name") or controller.real_name.replace(",", "."), "platform:Linux"]
        hotkey_input = None
        mapped_button_codes: set[str] = set()
        for input in controller.inputs.values():
            key_name = _DEFAULT_SDL_MAPPING.get(input.name)
            if key_name is None:
                continue
            if input.name == "hotkey":
                hotkey_input = input
                continue
            if input.type == "button" and input.code is not None:
                mapped_button_codes.add(input.code)
            if (sdl_config := _input_to_fex_sdl_mapping(key_name, input)) is not None:
                config.append(sdl_config)

        if (
            hotkey_input is not None
            and hotkey_input.code not in mapped_button_codes
            and (key_name := _DEFAULT_SDL_MAPPING.get(hotkey_input.name)) is not None
            and (sdl_config := _input_to_fex_sdl_mapping(key_name, hotkey_input)) is not None
        ):
            config.append(sdl_config)

        config.append("")
        configs.append(",".join(config))

    return "\n".join(configs)


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
                    sdl_controller_config = _generate_fex_sdl_game_controller_config(playersControllers)
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

            return Command.Command(
                array=commandArray,
                env=environment
            )

        raise BatoceraException("Invalid system: " + system.name)

    def hasInternalMangoHUDCall(self):
        return True

    def getMouseMode(self, config, rom):
        return config.get_bool("force_mouse")
