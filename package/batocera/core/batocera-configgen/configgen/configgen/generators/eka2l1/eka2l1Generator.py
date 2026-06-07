from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

import yaml

from ... import Command
from ...batoceraPaths import CACHE, CONFIGS, HOME, SAVES
from ...controller import generate_sdl_game_controller_config, write_sdl_controller_db
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


_XDG_DATA_HOME = SAVES / "eka2l1"
_EKA2L1_HOME = _XDG_DATA_HOME / "EKA2L1"
_CONFIG_FILE = _EKA2L1_HOME / "config.yml"
_SIS_EXTENSIONS = {".sis", ".sisx"}
_CARD_EXTENSIONS = {".n-gage", ".zip"}


def _load_config() -> dict:
    if not _CONFIG_FILE.is_file():
        return {}

    loaded = yaml.safe_load(_CONFIG_FILE.read_text()) or {}
    return loaded if isinstance(loaded, dict) else {}


def _write_config(system) -> None:
    config = _load_config()

    def set_bool(source: str, target: str, default: bool):
        if source in system.config:
            config[target] = system.config.get_bool(source)
        elif target not in config:
            config[target] = default

    keybind_profile = system.config.get_str("eka2l1_keybind_profile", "").strip()
    if keybind_profile:
        config["current-keybind-profile"] = keybind_profile
    elif "current-keybind-profile" not in config:
        config["current-keybind-profile"] = "default"

    set_bool("eka2l1_integer_scaling", "integer-scaling", True)
    set_bool("eka2l1_nearest_neighbor", "enable-nearest-neighbor-filter", True)

    if "eka2l1_audio_volume" in system.config:
        config["audio-master-volume"] = max(0, min(100, system.config.get_int("eka2l1_audio_volume", 100)))
    elif "audio-master-volume" not in config:
        config["audio-master-volume"] = 100

    _CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    _CONFIG_FILE.write_text(yaml.safe_dump(config, sort_keys=False))


def _launch_mode(system, rom: Path) -> str:
    mode = system.config.get_str("eka2l1_launch_mode", "auto")
    if mode != "auto":
        return mode

    if rom.suffix.lower() in _SIS_EXTENSIONS:
        return "install"

    if rom.is_dir() or rom.suffix.lower() in _CARD_EXTENSIONS:
        return "runng"

    return "run"


class Eka2l1Generator(Generator):
    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "eka2l1",
            "keys": {"exit": ["KEY_LEFTALT", "KEY_F4"]},
        }

    def executionDirectory(self, config, rom: Path) -> Path | None:
        _EKA2L1_HOME.mkdir(parents=True, exist_ok=True)
        (_EKA2L1_HOME / "bindings").mkdir(parents=True, exist_ok=True)
        return _EKA2L1_HOME

    def getMouseMode(self, config, rom: Path) -> bool:
        return True

    def generate(self, system, rom: Path, playersControllers, metadata, guns, wheels, gameResolution):
        _write_config(system)
        write_sdl_controller_db(playersControllers)

        command = ["/usr/eka2l1/eka2l1_qt"]

        if system.config.get_bool("eka2l1_fullscreen", True):
            command.append("--fullscreen")

        device_code = system.config.get_str("eka2l1_device_code", "").strip()
        if device_code:
            command.extend(["--device", device_code])

        keybind_profile = system.config.get_str("eka2l1_keybind_profile", "").strip()
        if keybind_profile:
            command.extend(["--keybindprofile", keybind_profile])

        mmc_id = system.config.get_str("eka2l1_mmcid", "").strip()
        if mmc_id:
            command.extend(["--mmcid", mmc_id])

        if str(rom) != "config" and rom.name != "config":
            mode = _launch_mode(system, rom)

            if mode in {"mount", "runng", "run"} and (rom.is_dir() or rom.suffix.lower() in _CARD_EXTENSIONS):
                command.append("--mount")
                if system.config.get_bool("eka2l1_mount_writable"):
                    command.append("writeable")
                command.append(str(rom))

            if mode == "install" or rom.suffix.lower() in _SIS_EXTENSIONS:
                command.extend(["--install", str(rom)])

            run_app = system.config.get_str("eka2l1_run_app", "").strip()
            if run_app:
                command.extend(["--run", run_app])
            elif mode == "runng":
                command.append("--runng")

        return Command.Command(
            array=command,
            env={
                "HOME": HOME,
                "XDG_CONFIG_HOME": CONFIGS,
                "XDG_DATA_HOME": _XDG_DATA_HOME,
                "XDG_CACHE_HOME": CACHE,
                "SDL_GAMECONTROLLERCONFIG": generate_sdl_game_controller_config(playersControllers),
                "SDL_JOYSTICK_HIDAPI": "0",
            },
        )
