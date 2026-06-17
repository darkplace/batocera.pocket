from __future__ import annotations

import logging
import os
import shutil
import stat
from pathlib import Path
from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import BIOS, CONFIGS, SAVES, CACHE, mkdir_if_not_exists, ensure_parents_and_open
from ...controller import Controller, generate_sdl_game_controller_config
from ...utils import lsfg, vulkan
from ...utils.configparser import CaseSensitiveRawConfigParser
from ..Generator import Generator

if TYPE_CHECKING:
    from ...Emulator import Emulator
    from ...controller import Controllers
    from ...input import Input, InputMapping

_logger = logging.getLogger(__name__)

CITRON_CONFIG = CONFIGS / "citron"
CITRON_SAVE = SAVES / "switch" / "citron"
CITRON_CACHE = CACHE.parent / "cache" / "citron"
SWITCH_BIOS = BIOS / "switch"
_SWITCH_KEYS = ("prod.keys", "title.keys")

# UCLAMP values (out of 1024)
# 819 = ~80% utilization floor, forces scheduler to use big cores
UCLAMP_MIN = 819
UCLAMP_MAX = 1024

_MAX_PLAYERS = 10

_CITRON_PLAYER_COLORS: tuple[dict[str, str], ...] = (
    {
        "body_color_left": "4278893030",
        "body_color_right": "4294917160",
        "button_color_left": "4278197790",
        "button_color_right": "4280158730",
        "body_color_left_default": "false",
        "body_color_right_default": "false",
        "button_color_left_default": "false",
        "button_color_right_default": "false",
    },
    {
        "body_color_left": "702950",
        "body_color_right": "16727080",
        "button_color_left": "7710",
        "button_color_right": "1968650",
        "body_color_left_default": "true",
        "body_color_right_default": "true",
        "button_color_left_default": "true",
        "button_color_right_default": "true",
    },
)

_CITRON_BUTTONS: dict[str, str | None] = {
    "button_a": "a",
    "button_b": "b",
    "button_x": "x",
    "button_y": "y",
    "button_lstick": "l3",
    "button_rstick": "r3",
    "button_l": "pageup",
    "button_r": "pagedown",
    "button_zl": "l2",
    "button_zr": "r2",
    "button_plus": "start",
    "button_minus": "select",
    "button_dleft": "left",
    "button_dup": "up",
    "button_dright": "right",
    "button_ddown": "down",
    "button_slleft": "pageup",
    "button_srleft": "pagedown",
    "button_home": "hotkey",
    "button_screenshot": None,
    "button_slright": "pageup",
    "button_srright": "pagedown",
}

_CITRON_STICKS: dict[str, str] = {
    "lstick": "joystick1",
    "rstick": "joystick2",
}

# Some Android handheld pads expose button ids to Batocera starting at 1 instead
# of 0. Citron expects SDL-style zero-based button numbering.
_ONE_BASED_SDL_BUTTON_GUIDS = {
    "03000000202000000130000001000000",
}

_QLAUNCH_SUFFIX = ".qlaunch"


class CitronGenerator(Generator):

    def getHotkeysContext(self):
        return {
            "name": "citron",
            "keys": {
                # Let the AppImage unwind cleanly first, then force-kill only if it ignores SIGTERM.
                "exit": "pkill -TERM -f '/tmp/.mount_citro.*/bin/citron|/usr/share/citron/citron.AppImage'; sleep 2; pkill -KILL -f '/tmp/.mount_citro.*/bin/citron|/usr/share/citron/citron.AppImage|/userdata/system/configs/citron/citron-perf.sh'"
            }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):

        # ---- filesystem layout ----
        mkdir_if_not_exists(SWITCH_BIOS)
        mkdir_if_not_exists(SWITCH_BIOS / "keys")
        mkdir_if_not_exists(SWITCH_BIOS / "firmware")

        mkdir_if_not_exists(CITRON_CONFIG)
        mkdir_if_not_exists(CITRON_CONFIG / "nand")
        mkdir_if_not_exists(CITRON_CONFIG / "nand" / "system")
        mkdir_if_not_exists(CITRON_CONFIG / "nand" / "user")
        mkdir_if_not_exists(CITRON_CONFIG / "load")
        mkdir_if_not_exists(CITRON_CONFIG / "nand" / "system" / "Contents")
        mkdir_if_not_exists(CITRON_CONFIG / "nand" / "system" / "Contents" / "registered")

        mkdir_if_not_exists(CITRON_SAVE)
        mkdir_if_not_exists(CITRON_SAVE / "keys")
        mkdir_if_not_exists(CITRON_SAVE / "sdmc")
        mkdir_if_not_exists(CITRON_SAVE / "dump")
        mkdir_if_not_exists(CITRON_SAVE / "tas")
        mkdir_if_not_exists(CITRON_SAVE / "screenshots")
        mkdir_if_not_exists(CITRON_CACHE)

        CitronGenerator._sync_bios_keys(CITRON_SAVE / "keys")
        CitronGenerator._sync_bios_firmware(CITRON_CONFIG / "nand" / "system" / "Contents" / "registered")

        CitronGenerator.writeConfig(
            CITRON_CONFIG / "qt-config.ini",
            system,
            playersControllers,
        )

        # ---- UCLAMP performance tuning for big.LITTLE ----
        use_uclamp = system.config.get_bool("perf_uclamp", True)
        uclamp_min = system.config.get_int("perf_uclamp_min", UCLAMP_MIN)

        launch_menu = rom.suffix.lower() == _QLAUNCH_SUFFIX

        if use_uclamp:
            wrapper_path = CITRON_CONFIG / "citron-perf.sh"
            CitronGenerator._write_uclamp_wrapper(
                wrapper_path, "/usr/bin/citron", uclamp_min, UCLAMP_MAX
            )
            command_array = [str(wrapper_path), "-platform", "xcb"]
        else:
            command_array = ["/usr/bin/citron", "-platform", "xcb"]

        if not launch_menu:
            command_array.extend(["-f", "-g", rom])

        env = {
            "XDG_CONFIG_HOME": CONFIGS,
            # Citron appends its own "citron" subdir under XDG roots.
            # Keep these roots aligned with the working desktop launcher.
            "XDG_DATA_HOME": SAVES / "switch",
            "XDG_CACHE_HOME": CACHE.parent / "cache",
            "QT_QPA_PLATFORM": "xcb",
            "SDL_GAMECONTROLLERCONFIG": CitronGenerator._build_sdl_game_controller_config(playersControllers),
        }
        lsfg.apply_lsfg_vk(system, env, backend_key="citron_backend", process_name="citron")

        return Command.Command(array=command_array, env=env)

    @staticmethod
    def _sync_bios_keys(target_keys_dir: Path) -> None:
        for key_name in _SWITCH_KEYS:
            source = CitronGenerator._resolve_bios_key(key_name)
            if source is None:
                continue
            CitronGenerator._copy_if_updated(source, target_keys_dir / key_name)

    @staticmethod
    def _resolve_bios_key(key_name: str) -> Path | None:
        for candidate in (SWITCH_BIOS / key_name, SWITCH_BIOS / "keys" / key_name):
            if candidate.is_file():
                return candidate
        return None

    @staticmethod
    def _sync_bios_firmware(target_registered_dir: Path) -> None:
        source_dir = CitronGenerator._resolve_bios_firmware_dir()
        if source_dir is None:
            return
        CitronGenerator._copy_tree_if_updated(source_dir, target_registered_dir)

    @staticmethod
    def _resolve_bios_firmware_dir() -> Path | None:
        firmware_root = SWITCH_BIOS / "firmware"
        candidates = (
            SWITCH_BIOS / "registered",
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
                CitronGenerator._copy_tree_if_updated(child, destination)
            elif child.is_file():
                CitronGenerator._copy_if_updated(child, destination)

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
# Auto-generated UCLAMP performance wrapper for Citron
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
        set_override("UI", "singleWindowMode", system.config.get("citron_single_window", "true"))
        set_override("UI", "enable_discord_presence", "false")
        set_override("UI", "confirmClose", "false")
        set_override("UI", "confirmStop", "2")
        set_override("UI", "UIGameList\\cache_game_list", "false")

        set_override("UI", "Paths\\gamedirs\\1\\path", "/userdata/roms/switch")
        set_override("UI", "Paths\\gamedirs\\size", "1")

        # ---------- Data Storage ----------
        if not c.has_section("Data%20Storage"):
            c.add_section("Data%20Storage")

        set_override("Data%20Storage", "nand_directory", str(CITRON_CONFIG / "nand"))
        set_override("Data%20Storage", "load_directory", str(CITRON_CONFIG / "load"))
        set_override("Data%20Storage", "sdmc_directory", str(CITRON_SAVE / "sdmc"))
        set_override("Data%20Storage", "dump_directory", str(CITRON_SAVE / "dump"))
        set_override("Data%20Storage", "tas_directory", str(CITRON_SAVE / "tas"))
        set_override("Data%20Storage", "use_virtual_sd", "true")

        if not c.has_section("Screenshots"):
            c.add_section("Screenshots")
        set_override("Screenshots", "screenshot_path", str(CITRON_SAVE / "screenshots"))

        # ---------- Core ----------
        if not c.has_section("Core"):
            c.add_section("Core")

        set_override("Core", "use_multi_core", system.config.get("citron_multicore", "true"))
        set_override("Core", "memory_layout_mode", system.config.get("citron_memory", "0"))

        # ---------- Cpu ----------
        if not c.has_section("Cpu"):
            c.add_section("Cpu")

        set_override("Cpu", "cpu_accuracy",
                     system.config.get("citron_cpuaccuracy", "0"))

        # CPU Backend: 0 = Dynarmic, 1 = NCE
        cpu_backend = system.config.get("citron_cpu_backend", "")
        if cpu_backend in ("0", "1"):
            set_override("Cpu", "cpu_backend", cpu_backend)
        else:
            c.set("Cpu", "cpu_backend\\default", "true")

        # ---------- Renderer ----------
        if not c.has_section("Renderer"):
            c.add_section("Renderer")

        # Graphics Backend: 0 = OpenGL, 1 = Vulkan
        backend = system.config.get("citron_backend", "1")
        set_override("Renderer", "backend", backend)
        set_override("Renderer", "shader_backend",
                     system.config.get("citron_opengl_shader_backend", "0"))

        if backend == "1" and vulkan.is_available():
            if vulkan.has_discrete_gpu():
                idx = vulkan.get_discrete_gpu_index()
                if idx is not None:
                    set_override("Renderer", "vulkan_device", str(idx))

        set_override("Renderer", "use_asynchronous_gpu_emulation",
                     system.config.get("citron_async_gpu", "true"))
        set_override("Renderer", "use_asynchronous_shaders",
                     system.config.get("citron_async_shaders", "true"))
        set_override("Renderer", "nvdec_emulation",
                     system.config.get("citron_nvdec_emu", "2"))
        set_override("Renderer", "gpu_accuracy",
                     system.config.get("citron_accuracy", "0"))
        set_override("Renderer", "resolution_setup",
                     system.config.get("citron_scale", "2"))
        set_override("Renderer", "accelerate_astc",
                     system.config.get("citron_astc", "1"))

        # VSync: 0 = Off, 1 = Mailbox, 2 = FIFO, 3 = FIFO Relaxed
        vsync = system.config.get("citron_vsync", "")
        if vsync in ("0", "1", "2", "3"):
            set_override("Renderer", "use_vsync", vsync)
        else:
            c.set("Renderer", "use_vsync\\default", "true")

        # Aspect Ratio: 0-5
        ratio = system.config.get("citron_ratio", "")
        if ratio in ("0", "1", "2", "3", "4", "5"):
            set_override("Renderer", "aspect_ratio", ratio)
        else:
            c.set("Renderer", "aspect_ratio\\default", "true")

        # Scaling Filter: 0-5
        scaling_filter = system.config.get("citron_scaling_filter",
                                           system.config.get("citron_scale_filter", ""))
        if scaling_filter in ("0", "1", "2", "3", "4", "5"):
            set_override("Renderer", "scaling_filter", scaling_filter)
        else:
            c.set("Renderer", "scaling_filter\\default", "true")

        # Anti-Aliasing: 0 = None, 1 = FXAA, 2 = SMAA
        anti_aliasing = system.config.get("citron_anti_aliasing",
                                          system.config.get("citron_aliasing_method", ""))
        if anti_aliasing in ("0", "1", "2"):
            set_override("Renderer", "anti_aliasing", anti_aliasing)
        else:
            c.set("Renderer", "anti_aliasing\\default", "true")

        # Anisotropic Filtering: 0-4
        anisotropy = system.config.get("citron_anisotropy", "")
        if anisotropy in ("0", "1", "2", "3", "4"):
            set_override("Renderer", "max_anisotropy", anisotropy)
        else:
            c.set("Renderer", "max_anisotropy\\default", "true")

        # ASTC Recompression: 0 = Uncompressed, 1 = BC1, 2 = BC3
        astc_recomp = system.config.get("citron_astc_recompression", "")
        if astc_recomp in ("0", "1", "2"):
            set_override("Renderer", "astc_recompression", astc_recomp)
        else:
            c.set("Renderer", "astc_recompression\\default", "true")

        # VRAM Usage Mode: 0 = Conservative, 1 = Aggressive
        vram_mode = system.config.get("citron_vram_mode", "")
        if vram_mode in ("0", "1"):
            set_override("Renderer", "vram_usage_mode", vram_mode)
        else:
            c.set("Renderer", "vram_usage_mode\\default", "true")

        # Async Presentation (Vulkan)
        async_pres = system.config.get("citron_async_presentation", "")
        if async_pres == "true":
            set_override("Renderer", "async_presentation", "true")
        elif async_pres == "false":
            set_override("Renderer", "async_presentation", "false")
        else:
            c.set("Renderer", "async_presentation\\default", "true")

        # Fast GPU Time
        fast_gpu = system.config.get("citron_fast_gpu_time", "")
        if fast_gpu == "true":
            set_override("Renderer", "use_fast_gpu_time", "true")
            set_override("Renderer", "fast_gpu_time", "1")
        elif fast_gpu == "false":
            set_override("Renderer", "use_fast_gpu_time", "false")
            set_override("Renderer", "fast_gpu_time", "0")
        else:
            c.set("Renderer", "use_fast_gpu_time\\default", "true")

        # ---------- Controls (Rumble) ----------
        if not c.has_section("Controls"):
            c.add_section("Controls")

        c.set("Controls", "touch_from_button_maps\\size", "1")
        c.set("Controls", "controller_navigation\\default", "true")
        c.set("Controls", "controller_navigation", "true")
        c.set("Controls", "enable_joycon_driver\\default", "true")
        c.set("Controls", "enable_joycon_driver", "true")
        c.set("Controls", "enable_procon_driver\\default", "true")
        c.set("Controls", "enable_procon_driver", "false")

        rumble = system.config.get("citron_rumble", "")
        if rumble == "true":
            set_override("Controls", "vibration_enabled", "true")
        elif rumble == "false":
            set_override("Controls", "vibration_enabled", "false")
        else:
            c.set("Controls", "vibration_enabled\\default", "true")

        rumble_str = system.config.get("citron_rumble_strength", "")
        if rumble_str in ("100", "75", "50", "25"):
            set_override("Controls", "player_0_vibration_strength", rumble_str)
        else:
            c.set("Controls", "player_0_vibration_strength\\default", "true")

        for player_index in range(_MAX_PLAYERS):
            controller = Controller.find_player_number(playersControllers, player_index + 1)
            colors = _CITRON_PLAYER_COLORS[0 if player_index < 8 else 1]

            c.set("Controls", f"player_{player_index}_type\\default", "true")
            c.set("Controls", f"player_{player_index}_type", "0")
            c.set("Controls", f"player_{player_index}_profile_name\\default", "true")
            c.set("Controls", f"player_{player_index}_profile_name", "")
            c.set("Controls", f"player_{player_index}_connected\\default", "true")
            c.set("Controls", f"player_{player_index}_connected", "true" if controller else "false")
            c.set("Controls", f"player_{player_index}_vibration_enabled\\default", "true")
            c.set("Controls", f"player_{player_index}_vibration_enabled", "true")
            c.set("Controls", f"player_{player_index}_vibration_strength\\default", "true")
            c.set("Controls", f"player_{player_index}_vibration_strength", rumble_str if rumble_str in ("100", "75", "50", "25") else "100")
            c.set("Controls", f"player_{player_index}_body_color_left\\default", colors["body_color_left_default"])
            c.set("Controls", f"player_{player_index}_body_color_left", colors["body_color_left"])
            c.set("Controls", f"player_{player_index}_body_color_right\\default", colors["body_color_right_default"])
            c.set("Controls", f"player_{player_index}_body_color_right", colors["body_color_right"])
            c.set("Controls", f"player_{player_index}_button_color_left\\default", colors["button_color_left_default"])
            c.set("Controls", f"player_{player_index}_button_color_left", colors["button_color_left"])
            c.set("Controls", f"player_{player_index}_button_color_right\\default", colors["button_color_right_default"])
            c.set("Controls", f"player_{player_index}_button_color_right", colors["button_color_right"])

            if controller is None:
                continue

            controller = CitronGenerator._normalize_controller(controller)

            c.set("Controls", f"player_{player_index}_body_color\\default", "false")
            c.set("Controls", f"player_{player_index}_body_color", "e1e1e1")
            c.set("Controls", f"player_{player_index}_gyro_overlay_visible\\default", "true")
            c.set("Controls", f"player_{player_index}_gyro_overlay_visible", "true")

            for citron_key, batocera_key in _CITRON_BUTTONS.items():
                c.set("Controls", f"player_{player_index}_{citron_key}\\default", "false")
                c.set(
                    "Controls",
                    f"player_{player_index}_{citron_key}",
                    CitronGenerator._build_button_binding(controller, player_index, batocera_key),
                )

            for citron_key, batocera_key in _CITRON_STICKS.items():
                c.set("Controls", f"player_{player_index}_{citron_key}\\default", "false")
                c.set(
                    "Controls",
                    f"player_{player_index}_{citron_key}",
                    CitronGenerator._build_stick_binding(controller, player_index, batocera_key),
                )

            for motion_key in ("motionleft", "motionright"):
                c.set("Controls", f"player_{player_index}_{motion_key}\\default", "false")
                c.set("Controls", f"player_{player_index}_{motion_key}", "[empty]")

        # ---------- System ----------
        if not c.has_section("System"):
            c.add_section("System")

        set_override("System", "language_index",
                     system.config.get("citron_language", "1"))
        set_override("System", "region_index",
                     system.config.get("citron_region", "2"))
        set_override("System", "time_zone_index",
                     system.config.get("citron_timezone", "0"))
        set_override("System", "sound_index",
                     system.config.get("citron_sound_index", system.config.get("citron_sound_mode", "1")))

        # Docked Mode: 0-1
        dock_mode = system.config.get("citron_dock_mode", "")
        if dock_mode in ("0", "1"):
            set_override("System", "use_docked_mode", dock_mode)
        elif dock_mode in ("true", "false"):
            # Citron persists this field as 0/1, not false/true.
            set_override("System", "use_docked_mode", "1" if dock_mode == "true" else "0")
        else:
            c.set("System", "use_docked_mode", "true")
            c.set("System", "use_docked_mode\\default", "true")

        # ---------- Audio ----------
        if not c.has_section("Audio"):
            c.add_section("Audio")

        set_override("Audio", "output_engine",
                     system.config.get("citron_audio_backend", "auto"))

        # ---------- Telemetry ----------
        if not c.has_section("WebService"):
            c.add_section("WebService")

        set_override("WebService", "enable_telemetry", "false")

        with ensure_parents_and_open(cfg, "w") as f:
            c.write(f)

    @staticmethod
    def _build_button_binding(controller: Controller, player_index: int, key: str | None) -> str:
        if key is None:
            return "[empty]"

        if key not in controller.inputs:
            return "[empty]"

        input = controller.inputs[key]
        guid = controller.guid
        pad = str(controller.index)
        port = str(player_index)

        if input.type == "button":
            return f'"pad:{pad},button:{input.id},port:{port},guid:{guid},engine:sdl"'
        if input.type == "hat":
            direction = CitronGenerator._hat_direction(input.value)
            return f'"engine:sdl,port:{port},guid:{guid},direction:{direction},hat:{input.id}"'
        if input.type == "axis":
            invert = "+" if int(input.value) >= 0 else "-"
            return f'"engine:sdl,invert:{invert},port:{port},guid:{guid},axis:{input.id},threshold:0.500000"'

        return "[empty]"

    @staticmethod
    def _build_sdl_game_controller_config(playersControllers: Controllers) -> str:
        return generate_sdl_game_controller_config(
            [CitronGenerator._normalize_controller(controller) for controller in playersControllers]
        )

    @staticmethod
    def _normalize_controller(controller: Controller) -> Controller:
        if not CitronGenerator._needs_one_based_button_fix(controller):
            return controller

        normalized = controller.replace()
        normalized.inputs = {
            name: CitronGenerator._normalize_input(input)
            for name, input in controller.inputs.items()
        }
        return normalized

    @staticmethod
    def _normalize_input(input: Input) -> Input:
        if input.type != "button":
            return input

        try:
            button_id = int(input.id)
        except ValueError:
            return input

        if button_id <= 0:
            return input

        return input.replace(id=str(button_id - 1))

    @staticmethod
    def _needs_one_based_button_fix(controller: Controller) -> bool:
        if controller.guid not in _ONE_BASED_SDL_BUTTON_GUIDS:
            return False

        button_ids = {
            int(input.id)
            for input in controller.inputs.values()
            if input.type == "button" and input.id.isdigit()
        }

        return 0 not in button_ids and set(range(1, 12)).issubset(button_ids)

    @staticmethod
    def _build_stick_binding(controller: Controller, player_index: int, key: str) -> str:
        x_input: Input | None = None
        y_input: Input | None = None

        if key == "joystick1":
            x_input = controller.inputs.get("joystick1left")
            y_input = controller.inputs.get("joystick1up")
        elif key == "joystick2":
            x_input = controller.inputs.get("joystick2left")
            y_input = controller.inputs.get("joystick2up")

        if x_input is None or y_input is None or x_input.type != "axis" or y_input.type != "axis":
            return "[empty]"

        invert_x = "+" if int(x_input.value) < 0 else "-"
        invert_y = "+" if int(y_input.value) < 0 else "-"

        return (
            f'"engine:sdl,port:{player_index},guid:{controller.guid},axis_x:{x_input.id},offset_x:-0.000000,'
            f'axis_y:{y_input.id},offset_y:0.000000,invert_x:{invert_x},invert_y:{invert_y},deadzone:0.150000"'
        )

    @staticmethod
    def _hat_direction(value: str) -> str:
        if int(value) == 1:
            return "up"
        if int(value) == 4:
            return "down"
        if int(value) == 2:
            return "right"
        if int(value) == 8:
            return "left"
        return "unknown"
