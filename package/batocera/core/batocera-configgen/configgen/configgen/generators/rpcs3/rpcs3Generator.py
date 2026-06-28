from __future__ import annotations

import json
import logging
import re
import shutil
import struct
from pathlib import Path
from typing import TYPE_CHECKING, Any, Final, cast

from ruamel.yaml import YAML

from ... import Command
from ...batoceraPaths import BIOS, CACHE, CONFIGS, configure_emulator, mkdir_if_not_exists
from ...exceptions import BatoceraException
from ...utils import vulkan
from ...utils.configparser import CaseSensitiveConfigParser
from ..Generator import Generator
from . import rpcs3Controllers
from .rpcs3Paths import RPCS3_BIN, RPCS3_CONFIG, RPCS3_CONFIG_DIR, RPCS3_CURRENT_CONFIG

if TYPE_CHECKING:
    from ...types import HotkeysContext, Resolution

_logger = logging.getLogger(__name__)

_ACHIEVEMENT_SOUND_ROOT: Final = Path("/usr/share/libretro/assets/sounds")
_DEFAULT_RPCS3_TROPHY_SOUND: Final = "ps3-trophy"
_RPCS3_GAME_PROFILE_KEY: Final = "rpcs3_game_profile"
_RPCS3_GAME_PROFILE_DATABASE: Final = "database"
_RPCS3_GAME_PROFILE_MANUAL: Final = "manual"
_RPCS3_DATABASE_CHOICE: Final = "rpcs3_database"
_RPCS3_DATABASE_CONFIGS: Final = (
    RPCS3_CONFIG_DIR / "GuiConfigs" / "config_database.dat",
    Path("/usr/share/rpcs3/GuiConfigs/config_database.dat"),
)
_RPCS3_DATABASE_KEYS: Final[dict[str, tuple[tuple[str, ...], ...]]] = {
    "rpcs3_ppudecoder": (("Core", "PPU Decoder"),),
    "rpcs3_spudecoder": (("Core", "SPU Decoder"),),
    "rpcs3_spuxfloataccuracy": (("Core", "SPU XFloat Accuracy"),),
    "rpcs3_spuloopdetection": (("Core", "SPU loop detection"),),
    "rpcs3_spublocksize": (("Core", "SPU Block Size"),),
    "rpcs3_sleep_timers_accuracy": (("Core", "Sleep Timers Accuracy"),),
    "rpcs3_framelimit": (("Video", "Frame limit"),),
    "rpcs3_anisotropic": (("Video", "Anisotropic Filter Override"),),
    "rpcs3_aa": (("Video", "MSAA"),),
    "rpcs3_zcull": (("Video", "Accurate ZCULL stats"), ("Video", "Relaxed ZCULL Sync")),
    "rpcs3_shader": (("Video", "Shader Precision"),),
    "rpcs3_shadermode": (("Video", "Shader Mode"),),
    "rpcs3_colorbuffers": (("Video", "Write Color Buffers"),),
    "rpcs3_write_depth_buffers": (("Video", "Write Depth Buffer"),),
    "rpcs3_read_color_buffers": (("Video", "Read Color Buffers"),),
    "rpcs3_read_depth_buffers": (("Video", "Read Depth Buffer"),),
    "rpcs3_strict": (("Video", "Strict Rendering Mode"),),
    "rpcs3_vertexcache": (("Video", "Disable Vertex Cache"),),
    "rpcs3_rsx": (("Video", "Multithreaded RSX"),),
    "rpcs3_cpu_blit": (("Video", "Force CPU Blit"),),
    "rpcs3_disable_zcull_queries": (("Video", "Disable ZCull Occlusion Queries"),),
    "rpcs3_audio_format": (("Audio", "Audio Format"),),
    "rpcs3_audiobuffer": (("Audio", "Enable Buffering"),),
    "rpcs3_timestretch": (("Audio", "Enable Time Stretching"),),
}
_RPCS3_DATABASE_KEY_ALIASES: Final[dict[str, tuple[str, ...]]] = {
    "rpcs3_ppudecoder": ("ppudecoder",),
    "rpcs3_spudecoder": ("spudecoder",),
    "rpcs3_spuxfloataccuracy": ("rpcs3_xfloat", "xfloat"),
    "rpcs3_spuloopdetection": ("spuloopdetect",),
    "rpcs3_spublocksize": ("spublocksize",),
    "rpcs3_sleep_timers_accuracy": ("sleep_timers_accuracy",),
    "rpcs3_framelimit": ("framelimit",),
    "rpcs3_anisotropic": ("anisotropicfilter",),
    "rpcs3_zcull": ("zcull_accuracy",),
    "rpcs3_shader": ("shader_quality",),
    "rpcs3_shadermode": ("shadermode",),
    "rpcs3_colorbuffers": ("writecolorbuffers",),
    "rpcs3_write_depth_buffers": ("writedepthbuffers",),
    "rpcs3_read_color_buffers": ("readcolorbuffers",),
    "rpcs3_read_depth_buffers": ("readdepthbuffers",),
    "rpcs3_strict": ("strict_rendering",),
    "rpcs3_vertexcache": ("disablevertex",),
    "rpcs3_rsx": ("multithreadedrsx",),
    "rpcs3_cpu_blit": ("cpu_blit",),
    "rpcs3_disable_zcull_queries": ("disable_zcull_queries",),
    "rpcs3_audio_format": ("audiochannels",),
    "rpcs3_audiobuffer": ("audio_buffering",),
}
_RPCS3_DATABASE_PROFILE_TARGETS: Final[tuple[tuple[str, ...], ...]] = (
    ("Core", "PPU Decoder"),
    ("Core", "SPU Decoder"),
    ("Core", "SPU XFloat Accuracy"),
    ("Core", "SPU loop detection"),
    ("Core", "SPU Block Size"),
    ("Core", "Sleep Timers Accuracy"),
    ("Core", "Libraries Control"),
    ("Core", "Max SPURS Threads"),
    ("Core", "Accurate SPU DMA"),
    ("Core", "Disable SPU GETLLAR Spin Optimization"),
    ("Core", "Debug Console Mode"),
    ("Core", "Accurate RSX reservation access"),
    ("Core", "RSX FIFO Fetch Accuracy"),
    ("Video", "Frame limit"),
    ("Video", "Anisotropic Filter Override"),
    ("Video", "MSAA"),
    ("Video", "Accurate ZCULL stats"),
    ("Video", "Relaxed ZCULL Sync"),
    ("Video", "Shader Precision"),
    ("Video", "Shader Mode"),
    ("Video", "Write Color Buffers"),
    ("Video", "Write Depth Buffer"),
    ("Video", "Read Color Buffers"),
    ("Video", "Read Depth Buffer"),
    ("Video", "Strict Rendering Mode"),
    ("Video", "Disable Vertex Cache"),
    ("Video", "Multithreaded RSX"),
    ("Video", "Force CPU Blit"),
    ("Video", "Disable ZCull Occlusion Queries"),
    ("Video", "Handle RSX Memory Tiling"),
    ("Video", "Emulate Special Depth Comparison"),
    ("Video", "Vblank NTSC Fixup"),
    ("Video", "Vulkan", "Asynchronous Texture Streaming"),
    ("Audio", "Audio Format"),
    ("Audio", "Enable Buffering"),
    ("Audio", "Enable Time Stretching"),
)
_RPCS3_GT6_TITLE_IDS: Final = frozenset(("BCES01893", "BCJS37016", "BCUS98296"))
_MISSING_DATABASE_VALUE: Final = object()

def _normalise_rpcs3_vsync(value: Any) -> str:
    if isinstance(value, bool):
        return "Full" if value else "Disabled"
    if isinstance(value, str):
        match value.strip().lower():
            case "true" | "on" | "1":
                return "Full"
            case "false" | "off" | "0":
                return "Disabled"
    return cast(str, value)

def _cfg_get(system: Emulator, key: str, default: Any, *aliases: str) -> Any:
    if key in _RPCS3_DATABASE_KEYS and _rpcs3_database_profile_requested(system):
        return default

    value = _cfg_get_configured_value(system, key, *aliases)
    if value is system.config.MISSING or _cfg_value_is_rpcs3_database(value):
        return default
    return value

def _cfg_get_configured_value(system: Emulator, key: str, *aliases: str) -> Any:
    missing = system.config.MISSING
    value = system.config.get(key, missing)
    if value is not missing:
        return value
    for alias in aliases:
        value = system.config.get(alias, missing)
        if value is not missing:
            return value
    return missing

def _cfg_value_is_rpcs3_database(value: Any) -> bool:
    return str(value).casefold() == _RPCS3_DATABASE_CHOICE

def _cfg_uses_rpcs3_database(system: Emulator, key: str, *aliases: str) -> bool:
    value = _cfg_get_configured_value(system, key, *aliases)
    return value is not system.config.MISSING and _cfg_value_is_rpcs3_database(value)

def _rpcs3_database_profile_requested(system: Emulator) -> bool:
    value = _cfg_get_configured_value(system, _RPCS3_GAME_PROFILE_KEY)
    if value is system.config.MISSING:
        return not _has_legacy_database_profile_setting(system)

    profile = str(value).casefold()
    if profile == _RPCS3_GAME_PROFILE_MANUAL:
        return False

    return profile == _RPCS3_GAME_PROFILE_DATABASE or profile == _RPCS3_DATABASE_CHOICE

def _has_legacy_database_profile_setting(system: Emulator) -> bool:
    for key in _RPCS3_DATABASE_KEYS:
        value = _cfg_get_configured_value(system, key, *_RPCS3_DATABASE_KEY_ALIASES.get(key, ()))
        if value is not system.config.MISSING:
            return True

    return False

def _cfg_get_bool(system: Emulator, key: str, default: bool = False, *aliases: str) -> bool:
    if key in _RPCS3_DATABASE_KEYS and _rpcs3_database_profile_requested(system):
        return default

    missing = system.config.MISSING
    value = system.config.get(key, missing)
    if value is not missing:
        if _cfg_value_is_rpcs3_database(value):
            return default
        return system.config.get_bool(key, default)
    for alias in aliases:
        value = system.config.get(alias, missing)
        if value is not missing:
            if _cfg_value_is_rpcs3_database(value):
                return default
            return system.config.get_bool(alias, default)
    return default

def _cfg_get_int(system: Emulator, key: str, default: int, *aliases: str) -> int:
    if key in _RPCS3_DATABASE_KEYS and _rpcs3_database_profile_requested(system):
        return default

    missing = system.config.MISSING
    value = system.config.get(key, missing)
    if value is not missing:
        if _cfg_value_is_rpcs3_database(value):
            return default
        return system.config.get_int(key, default)
    for alias in aliases:
        value = system.config.get(alias, missing)
        if value is not missing:
            if _cfg_value_is_rpcs3_database(value):
                return default
            return system.config.get_int(alias, default)
    return default

def _read_param_sfo_title_id(param_sfo: Path) -> str:
    return _read_param_sfo_string(param_sfo, "TITLE_ID").upper()

def _read_param_sfo_string(param_sfo: Path, wanted_key: str) -> str:
    if not param_sfo.is_file():
        return ""

    try:
        data = param_sfo.read_bytes()
        if len(data) < 20 or data[:4] != b"\0PSF":
            return ""

        key_table_start, data_table_start, entries = struct.unpack_from("<III", data, 8)
        for index in range(entries):
            entry_offset = 20 + (index * 16)
            key_offset, _fmt, data_len, _data_max_len, data_offset = struct.unpack_from("<HHIII", data, entry_offset)
            key_start = key_table_start + key_offset
            key_end = data.index(b"\0", key_start)
            key = data[key_start:key_end].decode("utf-8", errors="ignore")
            if key == wanted_key:
                value_start = data_table_start + data_offset
                value_end = value_start + data_len
                return data[value_start:value_end].decode("utf-8", errors="ignore").strip("\0 \t\r\n")
    except (OSError, ValueError, struct.error):
        _logger.debug("Could not read RPCS3 PARAM.SFO %s from %s", wanted_key, param_sfo)

    return ""

def _get_rpcs3_param_sfo_string(rom: Path, key: str) -> str:
    for param_sfo in (rom / "PS3_GAME" / "PARAM.SFO", rom / "PARAM.SFO"):
        value = _read_param_sfo_string(param_sfo, key)
        if value:
            return value

    return ""

def _get_rpcs3_title_id(rom: Path) -> str:
    if rom.suffix == ".psn":
        try:
            with rom.open() as fp:
                for line in fp:
                    title_id = line.strip().upper()
                    if len(title_id) >= 9:
                        return title_id
        except OSError:
            _logger.debug("Could not read RPCS3 PSN title id from %s", rom)
        return ""

    for param_sfo in (rom / "PS3_GAME" / "PARAM.SFO", rom / "PARAM.SFO"):
        title_id = _read_param_sfo_title_id(param_sfo)
        if title_id:
            return title_id

    return ""

def _version_at_most(version: str, maximum: str) -> bool:
    try:
        parsed_version = tuple(int(part) for part in version.split("."))
        parsed_maximum = tuple(int(part) for part in maximum.split("."))
    except ValueError:
        return False

    width = max(len(parsed_version), len(parsed_maximum))
    return parsed_version + (0,) * (width - len(parsed_version)) <= parsed_maximum + (0,) * (width - len(parsed_maximum))

def _load_rpcs3_database_config(title_id: str) -> dict[str, dict[str, Any]]:
    database_path = next((path for path in _RPCS3_DATABASE_CONFIGS if path.is_file()), None)
    if not title_id or database_path is None:
        return {}

    try:
        with database_path.open("r", encoding="utf-8") as config_file:
            database = json.load(config_file)
    except (OSError, json.JSONDecodeError):
        _logger.debug("Could not read RPCS3 config database from %s", database_path)
        return {}

    try:
        config_text = database["games"][title_id]["config"]
    except (KeyError, TypeError):
        _logger.debug("RPCS3 config database has no entry for title id %s", title_id)
        return {}

    yaml = YAML(typ='safe', pure=True)
    try:
        database_config = yaml.load(config_text) or {}
    except Exception:
        _logger.debug("Could not parse RPCS3 database config for title id %s", title_id)
        return {}

    return cast('dict[str, dict[str, Any]]', database_config)

def _get_rpcs3_database_value(database_config: dict[str, Any], path: tuple[str, ...]) -> Any:
    value: Any = database_config
    for part in path:
        if not isinstance(value, dict) or part not in value:
            return _MISSING_DATABASE_VALUE
        value = value[part]

    return value

def _set_rpcs3_config_value(rpcs3ymlconfig: dict[str, dict[str, Any]], path: tuple[str, ...], value: Any) -> None:
    config: dict[str, Any] = rpcs3ymlconfig
    for part in path[:-1]:
        section = config.get(part)
        if not isinstance(section, dict):
            section = {}
            config[part] = section
        config = section

    config[path[-1]] = value

def _apply_rpcs3_database_choices(system: Emulator, rpcs3ymlconfig: dict[str, dict[str, Any]], rom: Path, title_id: str) -> None:
    if _rpcs3_database_profile_requested(system):
        requested = [
            (_RPCS3_GAME_PROFILE_KEY, target)
            for target in _RPCS3_DATABASE_PROFILE_TARGETS
        ]
    else:
        requested = [
            (key, target)
            for key, targets in _RPCS3_DATABASE_KEYS.items()
            if _cfg_uses_rpcs3_database(system, key, *_RPCS3_DATABASE_KEY_ALIASES.get(key, ()))
            for target in targets
        ]

    if not requested:
        return

    database_config = _load_rpcs3_database_config(title_id)
    if not database_config:
        _logger.debug("RPCS3 database choices requested, but no database config was available for %s", title_id or "unknown title id")
        _apply_rpcs3_database_overrides(system, rpcs3ymlconfig, rom, title_id)
        return

    for config_key, target in requested:
        value = _get_rpcs3_database_value(database_config, target)
        if value is _MISSING_DATABASE_VALUE:
            if config_key != _RPCS3_GAME_PROFILE_KEY:
                _logger.debug("RPCS3 database entry for %s has no %s setting", title_id, config_key)
            continue

        _set_rpcs3_config_value(rpcs3ymlconfig, target, value)

    _apply_rpcs3_database_overrides(system, rpcs3ymlconfig, rom, title_id)

def _apply_rpcs3_database_overrides(system: Emulator, rpcs3ymlconfig: dict[str, dict[str, Any]], rom: Path, title_id: str) -> None:
    if not _rpcs3_database_profile_requested(system) or title_id not in _RPCS3_GT6_TITLE_IDS:
        return

    _set_rpcs3_config_value(rpcs3ymlconfig, ("Video", "Disable ZCull Occlusion Queries"), True)

    app_version = _get_rpcs3_param_sfo_string(rom, "APP_VER")
    if _version_at_most(app_version, "01.05"):
        _set_rpcs3_config_value(rpcs3ymlconfig, ("Video", "Force CPU Blit"), True)
        _set_rpcs3_config_value(rpcs3ymlconfig, ("Video", "Write Color Buffers"), False)
        _set_rpcs3_config_value(rpcs3ymlconfig, ("Video", "Read Color Buffers"), False)

def _retroachievements_sound_disabled(sound: str) -> bool:
    return sound.lower() in ("", "0", "false", "none")

def _retroachievements_sound_path(system: Emulator) -> str:
    sound = str(system.config.get("retroachievements.sound", _DEFAULT_RPCS3_TROPHY_SOUND))
    if _retroachievements_sound_disabled(sound):
        return ""

    if "/" in sound:
        path = Path(sound)
        return str(path) if path.is_file() else ""

    for suffix in (".ogg", ".wav"):
        path = _ACHIEVEMENT_SOUND_ROOT / f"{sound}{suffix}"
        if path.is_file():
            return str(path)

    return ""

class Rpcs3Generator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "rpcs3",
            "keys": { "exit": "/usr/bin/rpcs3-exit", "menu": ["KEY_LEFTSHIFT", "KEY_F10"] }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):

        rpcs3Controllers.generateControllerConfig(system, playersControllers, rom)

        # Taking care of the CurrentSettings.ini file
        mkdir_if_not_exists(RPCS3_CURRENT_CONFIG.parent)

        # Generates CurrentSettings.ini with values to disable prompts on first run

        rpcsCurrentSettings = CaseSensitiveConfigParser(interpolation=None)
        if RPCS3_CURRENT_CONFIG.exists():
            rpcsCurrentSettings.read(RPCS3_CURRENT_CONFIG)

        # Sets Gui Settings to close completely and disables some popups
        if not rpcsCurrentSettings.has_section("main_window"):
            rpcsCurrentSettings.add_section("main_window")

        rpcsCurrentSettings.set("main_window", "confirmationBoxExitGame", "false")
        rpcsCurrentSettings.set("main_window", "infoBoxEnabledInstallPUP","false")
        rpcsCurrentSettings.set("main_window", "infoBoxEnabledWelcome","false")
        rpcsCurrentSettings.set("main_window", "confirmationBoxBootGame", "false")
        rpcsCurrentSettings.set("main_window", "infoBoxEnabledInstallPKG", "false")

        if not rpcsCurrentSettings.has_section("Meta"):
            rpcsCurrentSettings.add_section("Meta")
        rpcsCurrentSettings.set("Meta", "checkUpdateStart", "false")
        rpcsCurrentSettings.set("Meta", "useRichPresence", "true" if system.config.get_bool("discord") else "false")

        if not rpcsCurrentSettings.has_section("GSFrame"):
            rpcsCurrentSettings.add_section("GSFrame")
        rpcsCurrentSettings.set("GSFrame", "disableMouse", "true")

        with RPCS3_CURRENT_CONFIG.open("w") as configfile:
            rpcsCurrentSettings.write(configfile)

        mkdir_if_not_exists(RPCS3_CONFIG.parent)

        # Generate a default config if it doesn't exist otherwise just open the existing
        rpcs3ymlconfig: dict[str, dict[str, Any]] = {}
        if RPCS3_CONFIG.is_file():
            with RPCS3_CONFIG.open("r") as stream:
                yaml = YAML(typ='safe', pure=True)
                rpcs3ymlconfig = cast('dict[str, dict[str, Any]]', yaml.load(stream) or {})

        # Add Nodes if not in the file
        if "Core" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Core"] = {}
        if "VFS" not in rpcs3ymlconfig:
            rpcs3ymlconfig["VFS"] = {}
        if "Video" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Video"] = {}
        if "Audio" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Audio"] = {}
        if "Input/Output" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Input/Output"] = {}
        if "System" not in rpcs3ymlconfig:
            rpcs3ymlconfig["System"] = {}
        if "Net" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Net"] = {}
        if "Savestate" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Savestate"] = {}
        if "Miscellaneous" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Miscellaneous"] = {}
        if "Log" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Log"] = {}

        # -= [Core] =-
        # Set the PPU Decoder based on config
        rpcs3ymlconfig["Core"]["PPU Decoder"] = _cfg_get(system, "rpcs3_ppudecoder", "Recompiler (LLVM)", "ppudecoder")
        # Set the SPU Decoder based on config
        rpcs3ymlconfig["Core"]["SPU Decoder"] = _cfg_get(system, "rpcs3_spudecoder", "Recompiler (LLVM)", "spudecoder")
        # Set the SPU XFloat Accuracy based on config
        rpcs3ymlconfig["Core"].pop("XFloat Accuracy", None)
        rpcs3ymlconfig["Core"]["SPU XFloat Accuracy"] = _cfg_get(system, "rpcs3_spuxfloataccuracy", "Approximate", "rpcs3_xfloat", "xfloat")
        # Set the Default Core Values we need
        # Force to True for now to account for updates where exiting config file present.
        rpcs3ymlconfig["Core"]["SPU Cache"] = True
        # Preferred SPU Threads
        rpcs3ymlconfig["Core"]["Preferred SPU Threads"] = _cfg_get_int(system, "rpcs3_sputhreads", 0, "sputhreads")
        # SPU Loop Detection
        rpcs3ymlconfig["Core"]["SPU loop detection"] = _cfg_get_bool(system, "rpcs3_spuloopdetection", False, "spuloopdetect")
        # SPU Block Size
        rpcs3ymlconfig["Core"]["SPU Block Size"] = _cfg_get(system, "rpcs3_spublocksize", "Safe", "spublocksize")
        # Max Power Saving CPU-Preemptions
        rpcs3ymlconfig["Core"]["Max CPU Preempt Count"] = system.config.get_int("rpcs3_maxcpu_preemptcount", 0)
        # Sleep Timers Accuracy
        rpcs3ymlconfig["Core"]["Sleep Timers Accuracy"] = _cfg_get(system, "rpcs3_sleep_timers_accuracy", "As Host", "sleep_timers_accuracy")
        # RSX FIFO Accuracy
        rpcs3ymlconfig["Core"]["RSX FIFO Accuracy"] = _cfg_get(system, "rpcs3_rsxfifoaccuracy", "Fast", "rsxfifoaccuracy")

        # -= [Video] =-
        # gfx backend - default to Vulkan
        if vulkan.is_available():
            _logger.debug("Vulkan driver is available on the system.")
            if _cfg_get(system, "rpcs3_gfxbackend", "", "gfxbackend") == "OpenGL":
                _logger.debug("User selected OpenGL")
                rpcs3ymlconfig["Video"]["Renderer"] = "OpenGL"
            else:
                rpcs3ymlconfig["Video"]["Renderer"] = "Vulkan"

            if vulkan.has_discrete_gpu():
                _logger.debug("A discrete GPU is available on the system.")
                discrete_name = vulkan.get_discrete_gpu_name()
                if discrete_name:
                    _logger.debug("Using Discrete GPU Name: %s for RPCS3", discrete_name)
                    if "Vulkan" not in rpcs3ymlconfig["Video"]:
                        rpcs3ymlconfig["Video"]["Vulkan"] = {}
                    rpcs3ymlconfig["Video"]["Vulkan"]["Adapter"] = discrete_name
        else:
            _logger.debug("Vulkan driver is not available. Falling back to OpenGL")
            rpcs3ymlconfig["Video"]["Renderer"] = "OpenGL"

        # System aspect ratio
        rpcs3ymlconfig["Video"]["Aspect ratio"] = system.config.get("rpcs3_ratio") or Rpcs3Generator.getClosestRatio(gameResolution)
        
        # Shader compilation mode
        rpcs3ymlconfig["Video"]["Shader Mode"] = _cfg_get(system, "rpcs3_shadermode", "Async Shader Recompiler", "shadermode")
        
        # Shader quality
        rpcs3ymlconfig["Video"]["Shader Precision"] = _cfg_get(system, "rpcs3_shader", "High", "shader_quality")
        
        # Vsync
        rpcs3ymlconfig["Video"]["VSync"] = _normalise_rpcs3_vsync(_cfg_get(system, "rpcs3_vsync", "Full", "vsync"))

        # Stretch to display area
        rpcs3ymlconfig["Video"]["Stretch To Display Area"] = _cfg_get_bool(system, "rpcs3_stretchdisplay", False, "stretchtodisplay")
        
        # Frame Limit
        match _cfg_get(system, "rpcs3_framelimit", system.config.MISSING, "framelimit"):
            case system.config.MISSING:
                rpcs3ymlconfig["Video"]["Frame limit"] = "Auto"
                rpcs3ymlconfig["Video"]["Second Frame Limit"] = 0
            case "Off" | "30" | "50" | "59.94" | "60" as framelimit:
                rpcs3ymlconfig["Video"]["Frame limit"] = framelimit
                rpcs3ymlconfig["Video"]["Second Frame Limit"] = 0
            case _ as framelimit:
                rpcs3ymlconfig["Video"]["Second Frame Limit"] = framelimit
                rpcs3ymlconfig["Video"]["Frame limit"] = "Off"
        
        # Write Color Buffers
        rpcs3ymlconfig["Video"]["Write Color Buffers"] = _cfg_get_bool(system, "rpcs3_colorbuffers", False, "writecolorbuffers")
        
        # Write Depth Buffers
        rpcs3ymlconfig["Video"]["Write Depth Buffer"] = _cfg_get_bool(system, "rpcs3_write_depth_buffers", False, "writedepthbuffers")
        
        # Read Color Buffers
        rpcs3ymlconfig["Video"]["Read Color Buffers"] = _cfg_get_bool(system, "rpcs3_read_color_buffers", False, "readcolorbuffers")
        
        # Read Depth Buffers
        rpcs3ymlconfig["Video"]["Read Depth Buffer"] = _cfg_get_bool(system, "rpcs3_read_depth_buffers", False, "readdepthbuffers")
        
        # Disable Vertex Cache
        rpcs3ymlconfig["Video"]["Disable Vertex Cache"] = _cfg_get_bool(system, "rpcs3_vertexcache", False, "disablevertex")
        
        # Strict rendering mode
        rpcs3ymlconfig["Video"]["Strict Rendering Mode"] = _cfg_get_bool(system, "rpcs3_strict", False, "strict_rendering")
        
        # Anisotropic Filtering
        rpcs3ymlconfig["Video"]["Anisotropic Filter Override"] = _cfg_get_int(system, "rpcs3_anisotropic", 0, "anisotropicfilter")
        
        # MSAA
        rpcs3ymlconfig["Video"]["MSAA"] = _cfg_get(system, "rpcs3_aa", "Auto")
        
        # ZCULL Accuracy
        match _cfg_get(system, "rpcs3_zcull", "", "zcull_accuracy"):
            case "Approximate":
                rpcs3ymlconfig["Video"]["Accurate ZCULL stats"] = False
                rpcs3ymlconfig["Video"]["Relaxed ZCULL Sync"] = False
            case "Relaxed":
                rpcs3ymlconfig["Video"]["Accurate ZCULL stats"] = False
                rpcs3ymlconfig["Video"]["Relaxed ZCULL Sync"] = True
            case _:
                rpcs3ymlconfig["Video"]["Accurate ZCULL stats"] = True
                rpcs3ymlconfig["Video"]["Relaxed ZCULL Sync"] = False

        # Internal resolution
        rpcs3ymlconfig["Video"]["Resolution"] = "1280x720"
        
        # Resolution scaling
        rpcs3ymlconfig["Video"]["Resolution Scale"] = _cfg_get_int(system, "rpcs3_resolution_scale", 100, "rpcs3_internal_resolution")
        
        # Output Scaling filter
        rpcs3ymlconfig["Video"]["Output Scaling Mode"] = _cfg_get(system, "rpcs3_scaling", "Bilinear", "rpcs3_scaling_filter")
        
        # Number of Shader Compilers
        rpcs3ymlconfig["Video"]["Shader Compiler Threads"] = system.config.get_int("rpcs3_num_compilers", 0)
        
        # Multithreaded RSX
        rpcs3ymlconfig["Video"]["Multithreaded RSX"] = _cfg_get_bool(system, "rpcs3_rsx", False, "multithreadedrsx")
        
        # Async Texture Streaming
        rpcs3ymlconfig["Video"]["Asynchronous Texture Streaming 2"] = _cfg_get_bool(system, "rpcs3_async_texture", False, "asynctexturestream")
        
        # Force CPU Blit Emulation
        rpcs3ymlconfig["Video"]["Force CPU Blit"] = _cfg_get_bool(system, "rpcs3_cpu_blit", False, "cpu_blit")
        
        # Disable ZCULL Occlusion Queries
        rpcs3ymlconfig["Video"]["Disable ZCull Occlusion Queries"] = _cfg_get_bool(system, "rpcs3_disable_zcull_queries", False, "disable_zcull_queries")
        
        # Driver Wake-up Delay
        rpcs3ymlconfig["Video"]["Driver Wake-Up Delay"] = _cfg_get_int(system, "rpcs3_driver_wake", 1, "driver_wake")
        
        # 3D mode
        rpcs3ymlconfig["Video"]["3D Display Mode"] = _cfg_get(system, "rpcs3_3d", "Disabled", "enable3d")
        
        # Fullscreen mode (exclusive vs borderless)
        fullscreen_mode = _cfg_get(system, "rpcs3_fullscreen_mode", "Automatic")
        if system.config.get_bool("exclusivefs"):
            fullscreen_mode = "Enable"
        rpcs3ymlconfig["Video"]["Exclusive Fullscreen Mode"] = fullscreen_mode

        # -= [Audio] =-
        rpcs3ymlconfig["Audio"]["Renderer"] = "Cubeb"
        rpcs3ymlconfig["Audio"]["Master Volume"] = 100
        
        # Audio format/channels
        rpcs3ymlconfig["Audio"]["Audio Format"] = _cfg_get(system, "rpcs3_audio_format", "Stereo", "audiochannels")
        
        # Convert to 16 bit
        rpcs3ymlconfig["Audio"]["Convert to 16 bit"] = system.config.get_bool("rpcs3_audio_16bit")
        
        # Audio buffering
        rpcs3ymlconfig["Audio"]["Enable Buffering"] = _cfg_get_bool(system, "rpcs3_audiobuffer", True, "audio_buffering")
        
        # Audio buffer duration
        rpcs3ymlconfig["Audio"]["Desired Audio Buffer Duration"] = system.config.get_int("rpcs3_audiobuffer_duration", 100)
        
        # Time stretching
        time_stretch_mode = _cfg_get(system, "time_stretching", "")
        if _cfg_get_bool(system, "rpcs3_timestretch", False):
            rpcs3ymlconfig["Audio"]["Enable Time Stretching"] = True
            rpcs3ymlconfig["Audio"]["Enable Buffering"] = True
        elif time_stretch_mode in ("low", "medium", "high"):
            rpcs3ymlconfig["Audio"]["Enable Time Stretching"] = True
            rpcs3ymlconfig["Audio"]["Enable Buffering"] = True
        else:
            rpcs3ymlconfig["Audio"]["Enable Time Stretching"] = False
        
        # Time stretching threshold
        if time_stretch_mode == "low":
            rpcs3ymlconfig["Audio"]["Time Stretching Threshold"] = 25
        elif time_stretch_mode == "medium":
            rpcs3ymlconfig["Audio"]["Time Stretching Threshold"] = 50
        elif time_stretch_mode == "high":
            rpcs3ymlconfig["Audio"]["Time Stretching Threshold"] = 75
        else:
            rpcs3ymlconfig["Audio"]["Time Stretching Threshold"] = system.config.get_int("rpcs3_timestretch_threshold", 75)

        # -= [System] =-
        # System region
        rpcs3ymlconfig["System"]["License Area"] = _cfg_get(system, "rpcs3_region", "SCEA", "ps3_region")
        
        # System language
        rpcs3ymlconfig["System"]["Language"] = _cfg_get(system, "rpcs3_language", "English (US)", "ps3_language")

        # -= [Input/Output] =-
        # Gun stuff
        if system.config.use_guns and guns:
            rpcs3ymlconfig["Input/Output"]["Move"] = "Gun"
            rpcs3ymlconfig["Input/Output"]["Camera"] = "Fake"
            rpcs3ymlconfig["Input/Output"]["Camera type"] = "PS Eye"
        
        # Gun crosshairs
        rpcs3ymlconfig["Input/Output"]["Show move cursor"] = system.config.get_bool("rpcs3_crosshairs")
        
        # Keyboard handler
        rpcs3ymlconfig["Input/Output"]["Keyboard"] = _cfg_get(system, "rpcs3_keyboard", "Null", "keyboard")

        # Let RPCS3 import Batocera's generated SDL mapping database.
        rpcs3ymlconfig["Input/Output"]["Load SDL GameController Mappings"] = True
        
        # Mouse handler
        rpcs3ymlconfig["Input/Output"]["Mouse"] = _cfg_get(system, "rpcs3_mouse", "Null", "mouse")
        
        # PS Move handler
        move_value = _cfg_get(system, "rpcs3_move", "", "move")
        if move_value:
            rpcs3ymlconfig["Input/Output"]["Move"] = move_value
        
        # Camera input
        camera_value = _cfg_get(system, "rpcs3_camera", "", "camera")
        if camera_value:
            rpcs3ymlconfig["Input/Output"]["Camera"] = camera_value
        
        # Camera type
        camera_type = _cfg_get(system, "rpcs3_cameraType", "", "cameraType")
        if camera_type:
            rpcs3ymlconfig["Input/Output"]["Camera type"] = camera_type
        
        # Gun configuration
        gun_mode = system.config.get("rpcs3_guns", "none")
        if gun_mode == "raw":
            rpcs3ymlconfig["Input/Output"]["Move"] = "Raw Mouse"
        elif gun_mode == "pseye":
            rpcs3ymlconfig["Input/Output"]["Move"] = "Gun"
            rpcs3ymlconfig["Input/Output"]["Camera"] = "Fake"

        # -= [Miscellaneous] =-
        rpcs3ymlconfig["Miscellaneous"]["Exit RPCS3 when process finishes"] = True
        rpcs3ymlconfig["Miscellaneous"]["Start games in fullscreen mode"] = True
        rpcs3ymlconfig["Miscellaneous"]["Automatically start games after boot"] = True
        rpcs3ymlconfig["Miscellaneous"]["Pause emulation on RPCS3 focus loss"] = True
        rpcs3ymlconfig["Miscellaneous"]["Prevent display sleep while running games"] = True
        
        # Show shader compilation hint
        hide_hints = _cfg_get_bool(system, "rpcs3_hidehints", False, "hidehints")
        rpcs3ymlconfig["Miscellaneous"]["Show shader compilation hint"] = not hide_hints
        rpcs3ymlconfig["Miscellaneous"]["Show PPU compilation hint"] = not hide_hints
        
        # Show trophy popups
        rpcs3ymlconfig["Miscellaneous"]["Show trophy popups"] = _cfg_get_bool(system, "rpcs3_show_trophy", False, "show_trophy")

        title_id = _get_rpcs3_title_id(rom)
        _apply_rpcs3_database_choices(system, rpcs3ymlconfig, rom, title_id)

        with RPCS3_CONFIG.open("w") as file:
            yaml = YAML(pure=True)
            yaml.default_flow_style = False
            yaml.dump(rpcs3ymlconfig, file)

        # copy icon files to config
        icon_target = RPCS3_CONFIG_DIR / 'Icons'
        mkdir_if_not_exists(icon_target)
        shutil.copytree('/usr/share/rpcs3/Icons/', icon_target, dirs_exist_ok=True, copy_function=shutil.copy2)

        # determine the rom name
        if rom.suffix == ".psn":
            romName: Path | None = None

            with rom.open() as fp:
                for line in fp:
                    if len(line) >= 9:
                        romName = RPCS3_CONFIG_DIR / "dev_hdd0" / "game" / line.strip().upper() / "USRDIR" / "EBOOT.BIN"

            if romName is None:
                raise BatoceraException(f'No game ID found in {rom}')
        elif configure_emulator(rom):
            romName: Path | None = None
        else:
            romName = rom / "PS3_GAME" / "USRDIR" / "EBOOT.BIN"

        if romName:
            commandArray: list[Path | str] = [RPCS3_BIN, romName]
        else:
            commandArray: list[Path | str] = [RPCS3_BIN]

        if not system.config.get_bool("rpcs3_gui") and romName:
            commandArray.append("--no-gui")

        # firmware not installed and available : instead of starting the game, install it
        if Rpcs3Generator.getFirmwareVersion() is None and (BIOS / "PS3UPDAT.PUP").exists():
            commandArray = [RPCS3_BIN, "--installfw", BIOS / "PS3UPDAT.PUP"]

        env = {
            "XDG_CONFIG_HOME": CONFIGS,
            "XDG_CACHE_HOME": CACHE,
            "BATOCERA_RPCS3_DISABLE_AUTO_DATABASE_CONFIG": "1"
        }
        if _cfg_get_bool(system, "rpcs3_achievement_sound", True):
            if sound_path := _retroachievements_sound_path(system):
                env["BATOCERA_RPCS3_TROPHY_SOUND"] = sound_path

        return Command.Command(
            array=commandArray,
            env=env
        )

    @staticmethod
    def getClosestRatio(gameResolution: Resolution) -> str:
        screenRatio = gameResolution["width"] / gameResolution["height"]
        if screenRatio < 1.6:
            return "4:3"
        return "16:9"

    def getInGameRatio(self, config, gameResolution, rom):
        return 16/9

    @staticmethod
    def getFirmwareVersion() -> str | None:
        try:
            with (RPCS3_CONFIG_DIR / "dev_flash" / "vsh" / "etc" / "version.txt").open("r") as stream:
                lines = stream.readlines()
            for line in lines:
                matches = re.match("^release:(.*):", line)
                if matches:
                    return matches[1]
        except Exception:
            return None
        return None
