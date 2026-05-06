from __future__ import annotations

import logging
import os
import shutil
import stat
from pathlib import Path
from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import BIOS, CONFIGS, SAVES, CACHE, mkdir_if_not_exists, ensure_parents_and_open
from ...controller import Controllers
from ...utils import lsfg, vulkan
from ...utils.configparser import CaseSensitiveRawConfigParser
from ..Generator import Generator
from .edenController import build_eden_sdl_game_controller_config, set_eden_controllers

if TYPE_CHECKING:
    from ...Emulator import Emulator

_logger = logging.getLogger(__name__)

HOME = Path("/userdata/system")
EDEN_CONFIG = CONFIGS / "eden"
EDEN_SAVE = SAVES / "switch" / "eden"
EDEN_LEGACY_SAVE = EDEN_SAVE / "eden"
EDEN_CACHE = CACHE.parent / "cache" / "eden"
SWITCH_BIOS = BIOS / "switch"
_SWITCH_KEYS = ("prod.keys", "title.keys")

# UCLAMP values (out of 1024)
# 819 = ~80% utilization floor, forces scheduler to use big cores
UCLAMP_MIN = 819
UCLAMP_MAX = 1024
_QLAUNCH_SUFFIX = ".qlaunch"


class EdenGenerator(Generator):

    def getHotkeysContext(self):
        return {
            "name": "eden",
            "keys": {"exit": ["KEY_LEFTALT", "KEY_F4"]}
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):

        # ---- Create directory structure ----
        mkdir_if_not_exists(EDEN_CONFIG)
        mkdir_if_not_exists(EDEN_CONFIG / "nand")
        mkdir_if_not_exists(EDEN_CONFIG / "nand" / "system")
        mkdir_if_not_exists(EDEN_CONFIG / "nand" / "user")
        mkdir_if_not_exists(EDEN_CONFIG / "load")
        mkdir_if_not_exists(EDEN_CONFIG / "nand" / "system" / "Contents")
        mkdir_if_not_exists(EDEN_CONFIG / "nand" / "system" / "Contents" / "registered")
        mkdir_if_not_exists(EDEN_SAVE)
        EdenGenerator._migrate_legacy_save_layout(EDEN_LEGACY_SAVE, EDEN_SAVE)
        mkdir_if_not_exists(EDEN_SAVE / "keys")
        mkdir_if_not_exists(EDEN_SAVE / "sdmc")
        mkdir_if_not_exists(EDEN_SAVE / "dump")
        mkdir_if_not_exists(EDEN_SAVE / "tas")
        mkdir_if_not_exists(EDEN_SAVE / "screenshots")
        mkdir_if_not_exists(EDEN_CACHE)
        mkdir_if_not_exists(SWITCH_BIOS)
        mkdir_if_not_exists(SWITCH_BIOS / "keys")
        mkdir_if_not_exists(SWITCH_BIOS / "firmware")

        EdenGenerator._sync_bios_keys(EDEN_SAVE / "keys")
        EdenGenerator._sync_bios_firmware(EDEN_CONFIG / "nand" / "system" / "Contents" / "registered")

        # ---- Write configuration ----
        EdenGenerator.writeConfig(
            EDEN_CONFIG / "qt-config.ini",
            system,
            playersControllers
        )

        # ---- Build environment ----
        env = {
            "HOME": str(HOME),
            "USER": "root",
            "LOGNAME": "root",
            "PWD": "/userdata",
            "SHELL": "/bin/sh",
            "TERM": "linux",
            "DISPLAY": ":0",
            "WAYLAND_DISPLAY": "wayland-0",
            "XDG_RUNTIME_DIR": "/var/run",
            # Eden appends its own "eden" subdir under these XDG roots.
            "XDG_CONFIG_HOME": CONFIGS,
            "XDG_DATA_HOME": SAVES / "switch",
            "XDG_CACHE_HOME": CACHE.parent / "cache",
            "LANG": "en_US.UTF-8",
            "LC_ALL": "en_US.UTF-8",
            "QT_QPA_PLATFORM": "xcb",
            "SDL_GAMECONTROLLERCONFIG": build_eden_sdl_game_controller_config(playersControllers),
        }

        # ---- UCLAMP performance tuning for big.LITTLE ----
        use_uclamp = system.config.get_bool("perf_uclamp", True)
        uclamp_min = system.config.get_int("perf_uclamp_min", UCLAMP_MIN)

        launch_menu = rom.suffix.lower() == _QLAUNCH_SUFFIX

        if use_uclamp:
            wrapper_path = EDEN_CONFIG / "eden-perf.sh"
            EdenGenerator._write_uclamp_wrapper(
                wrapper_path, "/usr/bin/eden", uclamp_min, UCLAMP_MAX
            )
            command_array = [str(wrapper_path), "-platform", "xcb"]
        else:
            command_array = ["/usr/bin/eden", "-platform", "xcb"]

        if not launch_menu:
            command_array.extend(["-f", "-g", str(rom)])

        lsfg.apply_lsfg_vk(system, env, backend_key="eden_backend", process_name="eden")

        return Command.Command(
            array=command_array,
            env=env
        )

    @staticmethod
    def _migrate_legacy_save_layout(legacy_root: Path, target_root: Path) -> None:
        if not legacy_root.is_dir():
            return

        for child in legacy_root.iterdir():
            target = target_root / child.name
            if target.exists():
                if child.is_dir() and target.is_dir():
                    EdenGenerator._merge_directory(child, target)
                continue
            shutil.move(str(child), str(target))

        try:
            legacy_root.rmdir()
        except OSError:
            pass

    @staticmethod
    def _merge_directory(source: Path, target: Path) -> None:
        for child in source.iterdir():
            destination = target / child.name
            if destination.exists():
                if child.is_dir() and destination.is_dir():
                    EdenGenerator._merge_directory(child, destination)
                continue
            shutil.move(str(child), str(destination))

        try:
            source.rmdir()
        except OSError:
            pass

    @staticmethod
    def _sync_bios_keys(target_keys_dir: Path) -> None:
        for key_name in _SWITCH_KEYS:
            source = EdenGenerator._resolve_bios_key(key_name)
            if source is None:
                continue
            EdenGenerator._copy_if_updated(source, target_keys_dir / key_name)

    @staticmethod
    def _resolve_bios_key(key_name: str) -> Path | None:
        for candidate in (SWITCH_BIOS / key_name, SWITCH_BIOS / "keys" / key_name):
            if candidate.is_file():
                return candidate
        return None

    @staticmethod
    def _sync_bios_firmware(target_registered_dir: Path) -> None:
        source_dir = EdenGenerator._resolve_bios_firmware_dir()
        if source_dir is None:
            return
        EdenGenerator._copy_tree_if_updated(source_dir, target_registered_dir)

    @staticmethod
    def _resolve_bios_firmware_dir() -> Path | None:
        firmware_root = SWITCH_BIOS / "firmware"
        candidates = (
            firmware_root / "registered",
            firmware_root / "Contents" / "registered",
            firmware_root / "system" / "Contents" / "registered",
        )

        for candidate in candidates:
            if candidate.is_dir():
                return candidate

        if firmware_root.is_dir() and any(child.is_file() for child in firmware_root.iterdir()):
            return firmware_root

        return None

    @staticmethod
    def _copy_tree_if_updated(source_dir: Path, target_dir: Path) -> None:
        for child in source_dir.iterdir():
            destination = target_dir / child.name
            if child.is_dir():
                mkdir_if_not_exists(destination)
                EdenGenerator._copy_tree_if_updated(child, destination)
            elif child.is_file():
                EdenGenerator._copy_if_updated(child, destination)

    @staticmethod
    def _copy_if_updated(source: Path, destination: Path) -> None:
        if destination.exists():
            source_stat = source.stat()
            destination_stat = destination.stat()
            if (
                destination_stat.st_size == source_stat.st_size
                and destination_stat.st_mtime_ns >= source_stat.st_mtime_ns
            ):
                return

        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)

    @staticmethod
    def _write_uclamp_wrapper(wrapper_path: Path, executable: str, uclamp_min: int, uclamp_max: int):
        """
        Creates a wrapper script that launches the emulator and sets UCLAMP values
        to pin it to big cores on big.LITTLE systems (e.g., SM8550).
        """
        script_content = f'''#!/bin/bash
# Auto-generated UCLAMP performance wrapper for Eden
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
        echo $UCLAMP_MIN > /proc/$pid/sched_util_min 2>/dev/null
        echo $UCLAMP_MAX > /proc/$pid/sched_util_max 2>/dev/null
        
        # All threads
        for tid in /proc/$pid/task/*/; do
            tid=$(basename "$tid")
            echo $UCLAMP_MIN > /proc/$pid/task/$tid/sched_util_min 2>/dev/null
            echo $UCLAMP_MAX > /proc/$pid/task/$tid/sched_util_max 2>/dev/null
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
    def writeConfig(cfg: Path, system: Emulator, playersControllers: Controllers):

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
        set_override("UI", "singleWindowMode", system.config.get("eden_single_window", "true"))
        set_override("UI", "enable_discord_presence", "false")
        set_override("UI", "confirmClose", "false")
        set_override("UI", "UIGameList\\cache_game_list", "false")

        set_override("UI", "Paths\\gamedirs\\1\\path", "/userdata/roms/switch")
        set_override("UI", "Paths\\gamedirs\\size", "1")

        # ---------- Data Storage ----------
        if not c.has_section("Data%20Storage"):
            c.add_section("Data%20Storage")

        set_override("Data%20Storage", "nand_directory", str(EDEN_CONFIG / "nand"))
        set_override("Data%20Storage", "load_directory", str(EDEN_CONFIG / "load"))
        set_override("Data%20Storage", "sdmc_directory", str(EDEN_SAVE / "sdmc"))
        set_override("Data%20Storage", "dump_directory", str(EDEN_SAVE / "dump"))
        set_override("Data%20Storage", "tas_directory", str(EDEN_SAVE / "tas"))
        set_override("Data%20Storage", "use_virtual_sd", "true")

        if not c.has_section("Screenshots"):
            c.add_section("Screenshots")
        set_override("Screenshots", "screenshot_path", str(EDEN_SAVE / "screenshots"))

        # ---------- Core ----------
        if not c.has_section("Core"):
            c.add_section("Core")

        # Multicore CPU emulation
        set_override("Core", "use_multi_core", system.config.get("eden_multicore", "true"))
        
        # Memory size (RAM)
        set_override("Core", "memory_layout_mode", system.config.get("eden_memory", "0"))

        # ---------- Renderer ----------
        if not c.has_section("Renderer"):
            c.add_section("Renderer")

        # Eden behaves better on this chipset when every OpenGL selection resolves to GLSL.
        requested_backend = system.config.get("eden_backend", "1")
        backend = "1" if requested_backend == "1" else "0"
        set_override("Renderer", "backend", backend)

        if backend == "1" and vulkan.is_available():
            if vulkan.has_discrete_gpu():
                idx = vulkan.get_discrete_gpu_index()
                if idx is not None:
                    set_override("Renderer", "vulkan_device", str(idx))

        # Async GPU emulation
        set_override("Renderer", "use_asynchronous_gpu_emulation",
                     system.config.get("eden_async_gpu", "true"))
        
        # Async shaders
        set_override("Renderer", "use_asynchronous_shaders",
                     system.config.get("eden_async_shaders", "true"))
        
        # NVDEC emulation
        set_override("Renderer", "nvdec_emulation",
                     system.config.get("eden_nvdec_emu", "2"))
        
        # GPU accuracy
        set_override("Renderer", "gpu_accuracy",
                     system.config.get("eden_accuracy", "1"))
        
        # Internal resolution scale
        set_override("Renderer", "resolution_setup",
                     system.config.get("eden_scale", "3"))
        
        # ASTC texture decoding/recompression
        set_override("Renderer", "astc_recompression",
                     system.config.get("eden_astc", "0"))
        
        # VSync
        set_override("Renderer", "use_vsync",
                     system.config.get("eden_vsync", "2"))
        
        # Aspect ratio
        set_override("Renderer", "aspect_ratio",
                     system.config.get("eden_ratio", "0"))
        
        # Anti-aliasing
        set_override("Renderer", "anti_aliasing",
                     system.config.get("eden_anti_aliasing", "0"))
        
        # Scaling filter
        set_override("Renderer", "scaling_filter",
                     system.config.get("eden_scaling_filter", "1"))
        
        # Anisotropic filtering
        set_override("Renderer", "max_anisotropy",
                     system.config.get("eden_anisotropy", "1"))

        # ---------- CPU ----------
        if not c.has_section("Cpu"):
            c.add_section("Cpu")

        set_override("Cpu", "cpu_accuracy",
                     system.config.get("eden_cpuaccuracy", "0"))

        # ---------- System ----------
        if not c.has_section("System"):
            c.add_section("System")

        set_override("System", "language_index",
                     system.config.get("eden_language", "1"))
        set_override("System", "region_index",
                     system.config.get("eden_region", "1"))
        
        # Docked mode (true = docked, false = handheld)
        dock_mode = system.config.get("eden_dock_mode", "")
        if dock_mode in ("0", "1"):
            set_override("System", "use_docked_mode", dock_mode)
        elif dock_mode in ("true", "false"):
            set_override("System", "use_docked_mode", "1" if dock_mode == "true" else "0")
        else:
            c.set("System", "use_docked_mode\\default", "true")
            c.set("System", "use_docked_mode", "1")

        # ---------- Audio ----------
        if not c.has_section("Audio"):
            c.add_section("Audio")

        # Audio backend
        set_override("Audio", "output_engine",
                     system.config.get("eden_audio_backend", "auto"))
        
        # Audio channels (sound_index)
        set_override("Audio", "sound_index",
                     system.config.get("eden_sound_index", "1"))

        # ---------- Controls ----------
        set_eden_controllers(c, system, playersControllers)

        # ---------- Telemetry ----------
        if not c.has_section("WebService"):
            c.add_section("WebService")

        set_override("WebService", "enable_telemetry", "false")

        with ensure_parents_and_open(cfg, "w") as f:
            c.write(f)
