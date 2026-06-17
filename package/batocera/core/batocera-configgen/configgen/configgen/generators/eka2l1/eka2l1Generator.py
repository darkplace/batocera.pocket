from __future__ import annotations

import shutil
import zipfile
from pathlib import Path, PurePosixPath
from typing import TYPE_CHECKING

import yaml

from ... import Command
from ...batoceraPaths import BIOS, CACHE, CONFIGS, HOME, SAVES
from ...controller import generate_sdl_game_controller_config, write_sdl_controller_db
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


_XDG_DATA_HOME = SAVES / "eka2l1"
_EKA2L1_HOME = _XDG_DATA_HOME / "EKA2L1"
_CONFIG_FILE = _EKA2L1_HOME / "config.yml"
_DEFAULT_STORAGE_DIR = "data"
_SIS_EXTENSIONS = {".sis", ".sisx"}
_CARD_EXTENSIONS = {".n-gage", ".zip"}
_NGAGE_PACKAGE_EXTENSIONS = {".n-gage"}
_BIOS_DIRS = (BIOS / "eka2l1", BIOS / "symbian")
_BIOS_SHORTCUTS = {"bios": BIOS / "eka2l1", "symbian": BIOS / "symbian"}
_DEVICE_PACK_MARKER = "devices.yml"
_DEVICE_PACK_SKIP = {"config.yml", "EKA2L1.log"}
_ARCHIVE_EXTENSIONS = {".zip"}
_TOP_LEVEL_ARCHIVE_TERMS = ("n-gage", "ngage", "symbian", "s60")


def _load_config() -> dict:
    if not _CONFIG_FILE.is_file():
        return {}

    loaded = yaml.safe_load(_CONFIG_FILE.read_text()) or {}
    return loaded if isinstance(loaded, dict) else {}


def _write_config(system) -> None:
    config = _load_config()

    if "data-storage" not in config:
        config["data-storage"] = _DEFAULT_STORAGE_DIR

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


def _storage_dir() -> Path:
    config = _load_config()
    storage = config.get("data-storage", _DEFAULT_STORAGE_DIR)
    if not isinstance(storage, str) or not storage.strip():
        storage = _DEFAULT_STORAGE_DIR

    storage_path = Path(storage)
    if storage_path.is_absolute():
        return storage_path

    return _EKA2L1_HOME / storage_path


def _has_device_pack() -> bool:
    storage_dir = _storage_dir()
    return (storage_dir / _DEVICE_PACK_MARKER).is_file() and (storage_dir / "drives").is_dir()


def _copy_tree_missing(source: Path, target: Path) -> None:
    if source.is_dir():
        if target.exists() and not target.is_dir():
            return

        target.mkdir(parents=True, exist_ok=True)
        for child in source.iterdir():
            _copy_tree_missing(child, target / child.name)
        return

    if target.exists() or target.is_symlink():
        return

    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def _seed_pack_dir(source: Path) -> None:
    if not source.is_dir() or not (source / _DEVICE_PACK_MARKER).is_file():
        return

    storage_dir = _storage_dir()
    for item in source.iterdir():
        if item.name in _DEVICE_PACK_SKIP:
            continue
        _copy_tree_missing(item, storage_dir / item.name)


def _archive_root_parts(archive: zipfile.ZipFile) -> tuple[str, ...] | None:
    candidates: list[tuple[str, ...]] = []

    for name in archive.namelist():
        parts = PurePosixPath(name).parts
        if parts and parts[-1] == _DEVICE_PACK_MARKER:
            candidates.append(parts[:-1])

    return min(candidates, key=len) if candidates else None


def _safe_zip_parts(parts: tuple[str, ...]) -> bool:
    return all(part not in {"", ".", "..", "/"} and "\\" not in part for part in parts)


def _seed_pack_archive(source: Path) -> None:
    if source.suffix.lower() not in _ARCHIVE_EXTENSIONS:
        return

    try:
        with zipfile.ZipFile(source) as archive:
            root_parts = _archive_root_parts(archive)
            if root_parts is None or not _safe_zip_parts(root_parts):
                return

            storage_dir = _storage_dir()
            for info in archive.infolist():
                parts = PurePosixPath(info.filename).parts
                if len(parts) <= len(root_parts) or parts[: len(root_parts)] != root_parts:
                    continue

                rel_parts = parts[len(root_parts):]
                if not rel_parts or rel_parts[0] in _DEVICE_PACK_SKIP or not _safe_zip_parts(rel_parts):
                    continue

                target = storage_dir.joinpath(*rel_parts)
                if info.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue

                if target.exists() or target.is_symlink():
                    continue

                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(info) as archive_file, target.open("wb") as target_file:
                    shutil.copyfileobj(archive_file, target_file)
    except (OSError, zipfile.BadZipFile):
        return


def _iter_archives(root: Path):
    if not root.is_dir():
        return

    for item in sorted(root.iterdir()):
        if item.is_file() and item.suffix.lower() in _ARCHIVE_EXTENSIONS:
            yield item


def _iter_seed_sources():
    for bios_dir in _BIOS_DIRS:
        yield bios_dir
        yield bios_dir / "Data"
        yield bios_dir / "EKA2L1"
        yield from _iter_archives(bios_dir)

    if not BIOS.is_dir():
        return

    for item in sorted(BIOS.iterdir()):
        lower_name = item.name.lower()
        if (
            item.is_file()
            and item.suffix.lower() in _ARCHIVE_EXTENSIONS
            and any(term in lower_name for term in _TOP_LEVEL_ARCHIVE_TERMS)
        ):
            yield item


def _seed_device_packs() -> None:
    seen: set[str] = set()

    for source in _iter_seed_sources():
        source_key = str(source)
        if source_key in seen:
            continue

        seen.add(source_key)
        if source.is_dir():
            _seed_pack_dir(source)
        elif source.is_file():
            _seed_pack_archive(source)


def _normalize_firmware_dirs(parent: Path) -> None:
    if not parent.is_dir():
        return

    for device_dir in parent.iterdir():
        lower_name = device_dir.name.lower()
        target = parent / lower_name
        if lower_name == device_dir.name or not device_dir.is_dir() or target.exists() or target.is_symlink():
            continue

        try:
            target.symlink_to(device_dir, target_is_directory=True)
        except OSError:
            _copy_tree_missing(device_dir, target)


def _normalize_case_tree(parent: Path) -> None:
    if not parent.is_dir() or parent.is_symlink():
        return

    for item in list(parent.iterdir()):
        if item.is_symlink():
            continue

        lower_name = item.name.lower()
        target = parent / lower_name
        if lower_name != item.name and not target.exists() and not target.is_symlink():
            try:
                target.symlink_to(item, target_is_directory=item.is_dir())
            except OSError:
                _copy_tree_missing(item, target)

        if item.is_dir():
            _normalize_case_tree(item)


def _normalize_device_pack_dirs() -> None:
    storage_dir = _storage_dir()
    drive_z = storage_dir / "drives" / "z"
    _normalize_firmware_dirs(drive_z)
    if drive_z.is_dir():
        for firmware_dir in drive_z.iterdir():
            if firmware_dir.is_dir() and not firmware_dir.is_symlink():
                _normalize_firmware_dirs(firmware_dir)
                _normalize_case_tree(firmware_dir)

    _normalize_firmware_dirs(storage_dir / "roms")
    _normalize_case_tree(storage_dir / "roms")


def _is_ngage_mime_package(rom: Path) -> bool:
    if rom.suffix.lower() not in _NGAGE_PACKAGE_EXTENSIONS or not rom.is_file():
        return False

    try:
        with rom.open("rb") as rom_file:
            header = rom_file.read(4096).lower()
    except OSError:
        return False

    return b"content-type: multipart/" in header and b"ngage-install-file" in header


def _is_mountable_card(rom: Path) -> bool:
    if rom.is_dir():
        return True

    if not rom.is_file() or rom.suffix.lower() not in _CARD_EXTENSIONS:
        return False

    return zipfile.is_zipfile(rom)


def _create_bios_shortcuts() -> None:
    for name, target in _BIOS_SHORTCUTS.items():
        link = _EKA2L1_HOME / name
        if link.exists() or link.is_symlink():
            continue

        try:
            link.symlink_to(target, target_is_directory=True)
        except OSError:
            pass


def _prepare_storage() -> None:
    _EKA2L1_HOME.mkdir(parents=True, exist_ok=True)
    _storage_dir().mkdir(parents=True, exist_ok=True)
    (_EKA2L1_HOME / "bindings").mkdir(parents=True, exist_ok=True)
    BIOS.mkdir(parents=True, exist_ok=True)
    for bios_dir in _BIOS_DIRS:
        bios_dir.mkdir(parents=True, exist_ok=True)

    _create_bios_shortcuts()
    if not _has_device_pack():
        _seed_device_packs()
    _normalize_device_pack_dirs()


def _launch_mode(system, rom: Path) -> str:
    mode = system.config.get_str("eka2l1_launch_mode", "auto")
    if mode != "auto":
        return mode

    if rom.suffix.lower() in _SIS_EXTENSIONS:
        return "install"

    if _is_ngage_mime_package(rom):
        return "config"

    if _is_mountable_card(rom):
        return "runng"

    return "run"


class Eka2l1Generator(Generator):
    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "eka2l1",
            "keys": {"exit": ["KEY_LEFTALT", "KEY_F4"]},
        }

    def executionDirectory(self, config, rom: Path) -> Path | None:
        _prepare_storage()
        return _EKA2L1_HOME

    def getMouseMode(self, config, rom: Path) -> bool:
        return True

    def generate(self, system, rom: Path, playersControllers, metadata, guns, wheels, gameResolution):
        _prepare_storage()
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
            mountable_card = _is_mountable_card(rom)

            if mode in {"mount", "runng", "run"} and mountable_card:
                command.append("--mount")
                if system.config.get_bool("eka2l1_mount_writable"):
                    command.append("writeable")
                command.append(str(rom))

            if mode == "install" or rom.suffix.lower() in _SIS_EXTENSIONS:
                command.extend(["--install", str(rom)])

            run_app = system.config.get_str("eka2l1_run_app", "").strip()
            if run_app:
                command.extend(["--run", run_app])
            elif mode == "runng" and mountable_card:
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
