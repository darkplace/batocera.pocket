from __future__ import annotations

import errno
import logging
import os
import shutil
import stat
from pathlib import Path
from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import BIOS, mkdir_if_not_exists, ensure_parents_and_open
from ...utils import lsfg, vulkan
from ...utils.configparser import CaseSensitiveRawConfigParser
from ..Generator import Generator
from ..eden.edenController import build_eden_sdl_game_controller_config
from .yuzuController import set_yuzu_controllers

if TYPE_CHECKING:
    from ...controller import Controllers
    from ...Emulator import Emulator

_logger = logging.getLogger(__name__)

# Yuzu AppImage uses standard XDG paths under HOME
HOME = Path("/userdata/system")
YUZU_CONFIG = HOME / ".config" / "yuzu"
YUZU_DATA = HOME / ".local/share" / "yuzu"
YUZU_CACHE = HOME / ".cache" / "yuzu"
SWITCH_BIOS = BIOS / "switch"
SWITCH_KEYS = SWITCH_BIOS / "keys"
SWITCH_NAND = SWITCH_BIOS / "nand"
SWITCH_FIRMWARE = SWITCH_BIOS / "firmware"

# UCLAMP values (out of 1024)
# 819 = ~80% utilization floor, forces scheduler to use big cores
UCLAMP_MIN = 819
UCLAMP_MAX = 1024


def _has_uclamp_support() -> bool:
    return Path("/proc/self/sched_util_min").exists() and Path("/proc/self/sched_util_max").exists()


def _link_dir_into_expected(source_dir: Path, expected_dir: Path) -> None:
    if not source_dir.exists():
        return

    if expected_dir.is_symlink():
        try:
            if expected_dir.resolve() == source_dir.resolve():
                return
        except FileNotFoundError:
            pass
        expected_dir.unlink(missing_ok=True)
        _symlink_or_copy_dir(source_dir, expected_dir)
        return

    if expected_dir.exists():
        return

    expected_dir.parent.mkdir(parents=True, exist_ok=True)
    _symlink_or_copy_dir(source_dir, expected_dir)


def _link_file_into_expected(source_file: Path, expected_file: Path) -> None:
    if not source_file.exists():
        return

    if expected_file.is_symlink():
        try:
            if expected_file.resolve() == source_file.resolve():
                return
        except FileNotFoundError:
            pass
        expected_file.unlink(missing_ok=True)
        _symlink_or_copy_file(source_file, expected_file)
        return

    if expected_file.is_dir():
        shutil.rmtree(expected_file)
    elif expected_file.exists():
        return

    _unlink_dangling_symlink(expected_file.parent)
    expected_file.parent.mkdir(parents=True, exist_ok=True)
    _symlink_or_copy_file(source_file, expected_file)


def _unlink_dangling_symlink(path: Path) -> None:
    if path.is_symlink() and not path.exists():
        path.unlink(missing_ok=True)


def _ensure_real_dir(path: Path) -> None:
    if path.is_symlink():
        path.unlink(missing_ok=True)
    elif path.exists() and not path.is_dir():
        path.unlink()

    path.mkdir(parents=True, exist_ok=True)


def _symlink_or_copy_dir(source_dir: Path, expected_dir: Path) -> None:
    try:
        expected_dir.symlink_to(source_dir, target_is_directory=True)
    except OSError as exc:
        if exc.errno not in (errno.ENOSYS, errno.EOPNOTSUPP, errno.EPERM):
            raise
        shutil.copytree(source_dir, expected_dir, dirs_exist_ok=True)


def _symlink_or_copy_file(source_file: Path, expected_file: Path) -> None:
    try:
        expected_file.symlink_to(source_file)
    except OSError as exc:
        if exc.errno not in (errno.ENOSYS, errno.EOPNOTSUPP, errno.EPERM):
            raise
        shutil.copy2(source_file, expected_file)


def _pick_existing_path(*candidates: Path) -> Path | None:
    for path in candidates:
        if path.exists():
            return path
    return None


def _resolve_firmware_dir() -> Path | None:
    candidates = (
        SWITCH_BIOS / "registered",
        SWITCH_FIRMWARE / "registered",
        SWITCH_FIRMWARE / "Contents" / "registered",
        SWITCH_FIRMWARE / "system" / "Contents" / "registered",
    )

    for candidate in candidates:
        if candidate.is_dir():
            return candidate

    if SWITCH_FIRMWARE.is_dir() and any(_is_registered_firmware_entry(child) for child in SWITCH_FIRMWARE.iterdir()):
        return SWITCH_FIRMWARE

    return None


def _is_registered_firmware_entry(path: Path) -> bool:
    if path.is_file():
        return True

    return path.is_dir() and path.name.endswith(".nca") and (path / "00").is_file()


def _registered_firmware_entries(source_dir: Path):
    for child in sorted(source_dir.iterdir()):
        if child.is_file():
            yield child, child.name
        elif child.is_dir() and child.name.endswith(".nca") and (child / "00").is_file():
            yield child / "00", child.name


def _link_firmware_into_registered(target_registered_dir: Path) -> None:
    source_dir = _resolve_firmware_dir()
    if source_dir is None:
        return

    target_registered_dir.mkdir(parents=True, exist_ok=True)
    for source, target_name in _registered_firmware_entries(source_dir):
        _link_file_into_expected(source, target_registered_dir / target_name)


def _is_aarch64() -> bool:
    return os.uname().machine.lower() in ("aarch64", "arm64")


def _is_nvidia_gpu() -> bool:
    for name in (vulkan.get_default_gpu_name(), vulkan.get_discrete_gpu_name()):
        if name and "nvidia" in name.lower():
            return True
    return False


def _is_qlaunch_marker(rom: Path) -> bool:
    return rom.suffix.lower() == ".qlaunch"


def _clear_controller_shortcut(
    parser: CaseSensitiveRawConfigParser, *action_names: str
) -> None:
    for action_name in action_names:
        prefix = f"Shortcuts\\Main%20Window\\{action_name}\\Controller_KeySeq"
        parser.set("UI", f"{prefix}\\default", "false")
        parser.set("UI", prefix, "")


def _set_shortcut(
    parser: CaseSensitiveRawConfigParser,
    action_name: str,
    key_sequence: str,
    *,
    context: str = "1",
) -> None:
    prefix = f"Shortcuts\\Main%20Window\\{action_name}"
    parser.set("UI", f"{prefix}\\Context", context)
    parser.set("UI", f"{prefix}\\Context\\default", "false")
    parser.set("UI", f"{prefix}\\KeySeq", key_sequence)
    parser.set("UI", f"{prefix}\\KeySeq\\default", "false")
    parser.set("UI", f"{prefix}\\Controller_KeySeq", "")
    parser.set("UI", f"{prefix}\\Controller_KeySeq\\default", "false")
    parser.set("UI", f"{prefix}\\Repeat", "false")
    parser.set("UI", f"{prefix}\\Repeat\\default", "false")


def _disable_shortcut(parser: CaseSensitiveRawConfigParser, action_name: str) -> None:
    _set_shortcut(parser, action_name, "", context="3")


_YUZU_CONTROLLER_SHORTCUTS = (
    "Audio%20Mute\\Unmute",
    "Audio%20Volume%20Down",
    "Audio%20Volume%20Up",
    "Capture%20Screenshot",
    "Change%20Adapting%20Filter",
    "Change%20Docked%20Mode",
    "Change%20GPU%20Accuracy",
    "Continue\\Pause%20Emulation",
    "Exit%20Fullscreen",
    "Exit%20Yuzu",
    "Exit%20yuzu",
    "Fullscreen",
    "Load%20File",
    "Load\\Remove%20Amiibo",
    "Restart%20Emulation",
    "Stop%20Emulation",
    "Toggle%20Framerate%20Limit",
)


class YuzuGenerator(Generator):

    def getHotkeysContext(self):
        return {
            "name": "yuzu",
            "keys": {
                "exit": "batocera-es-swissknife --emukill 0.5",
                "menu": "KEY_F4",
                "pause": "KEY_F4",
                "reset": "KEY_F6",
                "screenshot": ["KEY_LEFTCTRL", "KEY_P"],
                "fastforward": ["KEY_LEFTCTRL", "KEY_U"],
            }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):

        # ---- Create directory structure ----
        mkdir_if_not_exists(SWITCH_BIOS)

        mkdir_if_not_exists(YUZU_CONFIG)
        mkdir_if_not_exists(YUZU_DATA)
        mkdir_if_not_exists(YUZU_DATA / "load")
        mkdir_if_not_exists(YUZU_DATA / "sdmc")
        mkdir_if_not_exists(YUZU_CACHE)

        # Canonical shared BIOS content lives in /userdata/bios/switch/{keys,nand}.
        # Link into Yuzu expected locations when possible.
        _link_dir_into_expected(SWITCH_NAND, YUZU_DATA / "nand")
        if not (YUZU_DATA / "nand").exists():
            mkdir_if_not_exists(YUZU_DATA / "nand")
            _link_dir_into_expected(SWITCH_NAND / "system", YUZU_DATA / "nand" / "system")
            _link_dir_into_expected(SWITCH_NAND / "user", YUZU_DATA / "nand" / "user")
            mkdir_if_not_exists(YUZU_DATA / "nand" / "system")
            mkdir_if_not_exists(YUZU_DATA / "nand" / "user")
        _link_firmware_into_registered(YUZU_DATA / "nand" / "system" / "Contents" / "registered")

        prod_key_source = _pick_existing_path(
            SWITCH_KEYS / "prod.keys",
            SWITCH_BIOS / "prod.keys",
        )
        title_key_source = _pick_existing_path(
            SWITCH_KEYS / "title.keys",
            SWITCH_KEYS / "title.keys_autogenerated",
            SWITCH_BIOS / "title.keys",
            SWITCH_BIOS / "title.keys_autogenerated",
        )
        if prod_key_source is not None and prod_key_source.parent == SWITCH_KEYS:
            _link_dir_into_expected(SWITCH_KEYS, YUZU_DATA / "keys")
            _unlink_dangling_symlink(YUZU_DATA / "keys")
            mkdir_if_not_exists(YUZU_DATA / "keys")
        else:
            _ensure_real_dir(YUZU_DATA / "keys")

        if prod_key_source is not None:
            _link_file_into_expected(prod_key_source, YUZU_DATA / "keys" / "prod.keys")
        if title_key_source is not None:
            _link_file_into_expected(title_key_source, YUZU_DATA / "keys" / "title.keys")

        # ---- Write configuration ----
        YuzuGenerator.writeConfig(
            YUZU_CONFIG / "qt-config.ini",
            system,
            playersControllers,
        )

        # ---- Build environment ----
        home = str(HOME)
        env = {
            "HOME": home,
            "USER": "root",
            "LOGNAME": "root",
            "PWD": "/userdata",
            "SHELL": "/bin/sh",
            "TERM": "linux",
            "DISPLAY": ":0",
            "WAYLAND_DISPLAY": "wayland-0",
            "XDG_RUNTIME_DIR": "/var/run",
            "XDG_CONFIG_HOME": f"{home}/.config",
            "XDG_DATA_HOME": f"{home}/.local/share",
            "XDG_CACHE_HOME": f"{home}/.cache",
            "LANG": "en_US.UTF-8",
            "LC_ALL": "en_US.UTF-8",
            "SDL_GAMECONTROLLERCONFIG": build_eden_sdl_game_controller_config(playersControllers),
            # Steam Deck can fall back to unusable lizard mode with SDL hidapi in some AppImage builds.
            "SDL_JOYSTICK_HIDAPI": "0",
        }

        # ---- UCLAMP performance tuning for big.LITTLE ----
        use_uclamp = system.config.get_bool("perf_uclamp", True) and _has_uclamp_support()
        uclamp_min = system.config.get_int("perf_uclamp_min", UCLAMP_MIN)

        if use_uclamp:
            wrapper_path = YUZU_CONFIG / "yuzu-perf.sh"
            YuzuGenerator._write_uclamp_wrapper(
                wrapper_path, "/usr/bin/yuzu", uclamp_min, UCLAMP_MAX
            )
            if _is_qlaunch_marker(rom):
                command_array = [str(wrapper_path), "-qlaunch"]
            else:
                command_array = [str(wrapper_path), "-f", "-g", str(rom)]
        else:
            if _is_qlaunch_marker(rom):
                command_array = ["/usr/bin/yuzu", "-qlaunch"]
            else:
                command_array = ["/usr/bin/yuzu", "-f", "-g", str(rom)]

        lsfg.apply_lsfg_vk(system, env, backend_key="yuzu_backend", process_name="yuzu")

        return Command.Command(
            array=command_array,
            env=env
        )

    @staticmethod
    def _write_uclamp_wrapper(wrapper_path: Path, executable: str, uclamp_min: int, uclamp_max: int):
        """
        Creates a wrapper script that launches the emulator and sets UCLAMP values
        to pin it to big cores on big.LITTLE systems (e.g., SM8550).
        """
        script_content = f'''#!/bin/bash
# Auto-generated UCLAMP performance wrapper for Yuzu
# Forces scheduler to prefer big cores on big.LITTLE SoCs

EXEC="{executable}"
UCLAMP_MIN={uclamp_min}
UCLAMP_MAX={uclamp_max}

# Launch emulator in background
"$EXEC" "$@" &
EMU_PID=$!

# Brief delay for process to initialize
sleep 0.2

# Apply UCLAMP settings to main process and all threads
apply_uclamp() {{
    local pid=$1
    if [ -d "/proc/$pid" ]; then
        # Main process
        [ -e /proc/$pid/sched_util_min ] && echo $UCLAMP_MIN > /proc/$pid/sched_util_min
        [ -e /proc/$pid/sched_util_max ] && echo $UCLAMP_MAX > /proc/$pid/sched_util_max
        
        # All threads
        for tid in /proc/$pid/task/*/; do
            tid=$(basename "$tid")
            [ -e /proc/$pid/task/$tid/sched_util_min ] && echo $UCLAMP_MIN > /proc/$pid/task/$tid/sched_util_min
            [ -e /proc/$pid/task/$tid/sched_util_max ] && echo $UCLAMP_MAX > /proc/$pid/task/$tid/sched_util_max
        done
    fi
}}

# Initial application
apply_uclamp $EMU_PID

# Background task to apply UCLAMP to new threads periodically
(
    while kill -0 $EMU_PID 2>/dev/null; do
        sleep 2
        apply_uclamp $EMU_PID
    done
) &
MONITOR_PID=$!

# Wait for emulator to exit
wait $EMU_PID
EXIT_CODE=$?

# Cleanup monitor
kill $MONITOR_PID 2>/dev/null

exit $EXIT_CODE
'''
        with open(wrapper_path, 'w') as f:
            f.write(script_content)
        
        os.chmod(wrapper_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)

    @staticmethod
    def writeConfig(cfg: Path, system: Emulator, players_controllers: Controllers):

        c = CaseSensitiveRawConfigParser()
        if cfg.exists():
            c.read(cfg)

        def set_override(section: str, option: str, value: str) -> None:
            c.set(section, f"{option}\\default", "false")
            c.set(section, option, value)

        # ---------- UI ----------
        if not c.has_section("UI"):
            c.add_section("UI")

        set_override("UI", "fullscreen", "true")
        set_override("UI", "singleWindowMode", system.config.get("yuzu_single_window", "true"))
        set_override("UI", "enable_discord_presence", "false")
        set_override("UI", "firstStart", "false")
        set_override("UI", "calloutFlags", "1")
        set_override("UI", "confirmClose", "false")
        set_override("UI", "confirmExit", "false")
        set_override("UI", "confirmStop", "2")
        set_override("UI", "check_for_updates_on_start", "false")
        set_override("UI", "UIGameList\\cache_game_list", "false")
        _clear_controller_shortcut(c, *_YUZU_CONTROLLER_SHORTCUTS)
        _set_shortcut(c, "Capture%20Screenshot", "Ctrl+P", context="3")
        _set_shortcut(c, "Continue\\Pause%20Emulation", "F4")
        _set_shortcut(c, "Restart%20Emulation", "F6")
        _set_shortcut(c, "Toggle%20Framerate%20Limit", "Ctrl+U")
        _disable_shortcut(c, "Load\\Remove%20Amiibo")

        set_override("UI", "Paths\\gamedirs\\1\\path", "/userdata/roms/switch")
        set_override("UI", "Paths\\gamedirs\\size", "1")

        # ---------- Data Storage ----------
        if not c.has_section("Data%20Storage"):
            c.add_section("Data%20Storage")

        c.set("Data%20Storage", "nand_directory", str(YUZU_DATA / "nand"))
        c.set("Data%20Storage", "load_directory", str(YUZU_DATA / "load"))
        c.set("Data%20Storage", "sdmc_directory", str(YUZU_DATA / "sdmc"))
        c.set("Data%20Storage", "use_virtual_sd", "true")

        # ---------- Core ----------
        if not c.has_section("Core"):
            c.add_section("Core")

        c.set("Core", "use_multi_core", "true")

        # ---------- Cpu ----------
        if not c.has_section("Cpu"):
            c.add_section("Cpu")

        c.set("Cpu", "cpu_accuracy",
              system.config.get("yuzu_cpuaccuracy", "0"))

        # CPU Backend: 0 = Dynamic (Dynarmic), 1 = NCE
        # Yuzu only exposes this backend switch on aarch64 targets.
        cpu_backend = system.config.get("yuzu_cpu_backend", "")
        if _is_aarch64() and cpu_backend in ("0", "1"):
            c.set("Cpu", "cpu_backend", cpu_backend)
            c.set("Cpu", "cpu_backend\\default", "false")
        else:
            c.set("Cpu", "cpu_backend\\default", "true")

        # ---------- Renderer ----------
        if not c.has_section("Renderer"):
            c.add_section("Renderer")

        # Graphics Backend: 0 = OpenGL, 1 = Vulkan
        backend = system.config.get("yuzu_backend", "1")
        c.set("Renderer", "backend", backend)

        # OpenGL shader backend:
        # 1 = GLASM (NVIDIA), 2 = SPIR-V (AMD/Intel)
        if backend == "0":
            shader_backend = system.config.get("yuzu_opengl_shader_backend", "2")
            if shader_backend == "1" and not _is_nvidia_gpu():
                shader_backend = "2"
            if shader_backend in ("1", "2"):
                c.set("Renderer", "shader_backend", shader_backend)
                c.set("Renderer", "shader_backend\\default", "false")
            else:
                c.set("Renderer", "shader_backend\\default", "true")
        else:
            c.set("Renderer", "shader_backend\\default", "true")

        if backend == "1" and vulkan.is_available():
            if vulkan.has_discrete_gpu():
                idx = vulkan.get_discrete_gpu_index()
                if idx is not None:
                    c.set("Renderer", "vulkan_device", str(idx))

        c.set("Renderer", "use_asynchronous_gpu_emulation",
              system.config.get("yuzu_async_gpu", "true"))
        c.set("Renderer", "use_asynchronous_shaders",
              system.config.get("yuzu_async_shaders", "true"))
        c.set("Renderer", "nvdec_emulation",
              system.config.get("yuzu_nvdec_emu", "2"))
        c.set("Renderer", "gpu_accuracy",
              system.config.get("yuzu_accuracy", "0"))
        c.set("Renderer", "resolution_setup",
              system.config.get("yuzu_scale", "2"))
        c.set("Renderer", "accelerate_astc",
              system.config.get("yuzu_astc", "1"))

        # VSync: 0 = Off, 1 = Mailbox, 2 = FIFO, 3 = FIFO Relaxed
        vsync = system.config.get("yuzu_vsync", "")
        if vsync in ("0", "1", "2", "3"):
            c.set("Renderer", "use_vsync", vsync)
            c.set("Renderer", "use_vsync\\default", "false")
        else:
            c.set("Renderer", "use_vsync\\default", "true")

        # Aspect Ratio: 0-5
        ratio = system.config.get("yuzu_ratio", "")
        if ratio in ("0", "1", "2", "3", "4", "5"):
            c.set("Renderer", "aspect_ratio", ratio)
            c.set("Renderer", "aspect_ratio\\default", "false")
        else:
            c.set("Renderer", "aspect_ratio\\default", "true")

        # Scaling Filter: 0-5
        scaling_filter = system.config.get("yuzu_scaling_filter", "")
        if scaling_filter in ("0", "1", "2", "3", "4", "5"):
            c.set("Renderer", "scaling_filter", scaling_filter)
            c.set("Renderer", "scaling_filter\\default", "false")
        else:
            c.set("Renderer", "scaling_filter\\default", "true")

        # Anti-Aliasing: 0 = None, 1 = FXAA, 2 = SMAA
        anti_aliasing = system.config.get("yuzu_anti_aliasing", "")
        if anti_aliasing in ("0", "1", "2"):
            c.set("Renderer", "anti_aliasing", anti_aliasing)
            c.set("Renderer", "anti_aliasing\\default", "false")
        else:
            c.set("Renderer", "anti_aliasing\\default", "true")

        # Anisotropic Filtering: 0-4
        anisotropy = system.config.get("yuzu_anisotropy", "")
        if anisotropy in ("0", "1", "2", "3", "4"):
            c.set("Renderer", "max_anisotropy", anisotropy)
            c.set("Renderer", "max_anisotropy\\default", "false")
        else:
            c.set("Renderer", "max_anisotropy\\default", "true")

        # ASTC Recompression: 0 = Uncompressed, 1 = BC1, 2 = BC3
        astc_recomp = system.config.get("yuzu_astc_recompression", "")
        if astc_recomp in ("0", "1", "2"):
            c.set("Renderer", "astc_recompression", astc_recomp)
            c.set("Renderer", "astc_recompression\\default", "false")
        else:
            c.set("Renderer", "astc_recompression\\default", "true")

        # VRAM Usage Mode: 0 = Conservative, 1 = Aggressive
        vram_mode = system.config.get("yuzu_vram_mode", "")
        if vram_mode in ("0", "1"):
            c.set("Renderer", "vram_usage_mode", vram_mode)
            c.set("Renderer", "vram_usage_mode\\default", "false")
        else:
            c.set("Renderer", "vram_usage_mode\\default", "true")

        # Async Presentation (Vulkan)
        async_pres = system.config.get("yuzu_async_presentation", "")
        if async_pres == "true":
            c.set("Renderer", "async_presentation", "true")
            c.set("Renderer", "async_presentation\\default", "false")
        elif async_pres == "false":
            c.set("Renderer", "async_presentation", "false")
            c.set("Renderer", "async_presentation\\default", "false")
        else:
            c.set("Renderer", "async_presentation\\default", "true")

        # Fast GPU Time
        fast_gpu = system.config.get("yuzu_fast_gpu_time", "")
        if fast_gpu == "true":
            c.set("Renderer", "use_fast_gpu_time", "true")
            c.set("Renderer", "fast_gpu_time", "1")
            c.set("Renderer", "use_fast_gpu_time\\default", "false")
        elif fast_gpu == "false":
            c.set("Renderer", "use_fast_gpu_time", "false")
            c.set("Renderer", "fast_gpu_time", "0")
            c.set("Renderer", "use_fast_gpu_time\\default", "false")
        else:
            c.set("Renderer", "use_fast_gpu_time\\default", "true")

        # ---------- Controls (Rumble) ----------
        if not c.has_section("Controls"):
            c.add_section("Controls")

        # Prefer SDL controller path for Steam Deck reliability.
        c.set("Controls", "enable_procon_driver", "false")
        c.set("Controls", "enable_procon_driver\\default", "false")
        c.set("Controls", "enable_joycon_driver", "false")
        c.set("Controls", "enable_joycon_driver\\default", "false")

        rumble = system.config.get("yuzu_rumble", "")
        if rumble == "true":
            c.set("Controls", "vibration_enabled", "true")
            c.set("Controls", "vibration_enabled\\default", "false")
        elif rumble == "false":
            c.set("Controls", "vibration_enabled", "false")
            c.set("Controls", "vibration_enabled\\default", "false")
        else:
            c.set("Controls", "vibration_enabled\\default", "true")

        rumble_str = system.config.get("yuzu_rumble_strength", "")
        if rumble_str in ("100", "75", "50", "25"):
            c.set("Controls", "player_0_vibration_strength", rumble_str)
            c.set("Controls", "player_0_vibration_strength\\default", "false")
        else:
            c.set("Controls", "player_0_vibration_strength\\default", "true")

        # Generate per-player pad bindings from ES controller mappings.
        set_yuzu_controllers(c, system, players_controllers)

        # ---------- System ----------
        if not c.has_section("System"):
            c.add_section("System")

        c.set("System", "language_index",
              system.config.get("yuzu_language", "1"))
        c.set("System", "region_index",
              system.config.get("yuzu_region", "2"))

        # Docked Mode: 0-1
        dock_mode = system.config.get("yuzu_dock_mode", "")
        if dock_mode in ("0", "1"):
            c.set("System", "use_docked_mode", dock_mode)
            c.set("System", "use_docked_mode\\default", "false")
        elif dock_mode in ("true", "false"):
            c.set("System", "use_docked_mode", dock_mode)
            c.set("System", "use_docked_mode\\default", "false")
        else:
            c.set("System", "use_docked_mode", "true")
            c.set("System", "use_docked_mode\\default", "true")

        # ---------- Telemetry ----------
        if not c.has_section("WebService"):
            c.add_section("WebService")

        set_override("WebService", "enable_telemetry", "false")
        set_override("WebService", "enable_auto_update_check", "false")
        set_override("WebService", "yuzu_username", "")
        set_override("WebService", "yuzu_token", "")

        with ensure_parents_and_open(cfg, "w") as f:
            c.write(f)
