from __future__ import annotations

import filecmp
import logging
import os
import platform
import re
import shutil
import stat
import sys
from pathlib import Path
from typing import TYPE_CHECKING, Any

import toml

from ... import Command
from ...batoceraPaths import CACHE, CONFIGS, SAVES, configure_emulator, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ...utils import vulkan, wine
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext

_logger = logging.getLogger(__name__)

# UCLAMP values (out of 1024) for big.LITTLE optimization
UCLAMP_MIN = 819
UCLAMP_MAX = 1024

def _cfg_get(system: Any, key: str, default: Any, *aliases: str) -> Any:
    missing = system.config.MISSING
    value = system.config.get(key, missing)
    if value is not missing:
        return value
    for alias in aliases:
        value = system.config.get(alias, missing)
        if value is not missing:
            return value
    return default

def _cfg_get_bool(system: Any, key: str, default: bool = False, *aliases: str) -> bool:
    missing = system.config.MISSING
    if system.config.get(key, missing) is not missing:
        return system.config.get_bool(key, default)
    for alias in aliases:
        if system.config.get(alias, missing) is not missing:
            return system.config.get_bool(alias, default)
    return default

def _cfg_get_int(system: Any, key: str, default: int, *aliases: str) -> int:
    missing = system.config.MISSING
    if system.config.get(key, missing) is not missing:
        return system.config.get_int(key, default)
    for alias in aliases:
        if system.config.get(alias, missing) is not missing:
            return system.config.get_int(alias, default)
    return default


class XeniaGenerator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "xenia",
            "keys": { "exit": ["KEY_LEFTALT", "KEY_F4"] }
        }

    @staticmethod
    def is_aarch64() -> bool:
        """Check if running on aarch64 architecture"""
        return platform.machine().lower() in ('aarch64', 'arm64')

    @staticmethod
    def sync_directories(source_dir: Path, dest_dir: Path):
        dcmp = filecmp.dircmp(source_dir, dest_dir)
        # Files that are only in the source directory or are different
        differing_files = dcmp.diff_files + dcmp.left_only
        for file in differing_files:
            src_path = source_dir / file
            dest_path = dest_dir / file
            # Copy and overwrite the files from source to destination
            shutil.copy2(src_path, dest_path)

    @staticmethod
    def _write_box64_wrapper(wrapper_path: Path, box64_bin: str, wine_bin: str) -> None:
        """
        Creates a wrapper script that runs wine through box64 on aarch64.
        This is needed because Xenia is an x86_64 Windows application.
        """
        script_content = f'''#!/bin/bash
# Auto-generated box64 wrapper for Wine/Xenia on aarch64
exec {box64_bin} {wine_bin} "$@"
'''
        with open(wrapper_path, 'w') as f:
            f.write(script_content)
        os.chmod(wrapper_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)

    @staticmethod
    def _write_uclamp_box64_wrapper(wrapper_path: Path, box64_bin: str, wine_bin: str,
                                     uclamp_min: int, uclamp_max: int) -> None:
        """
        Creates a wrapper script that runs wine through box64 with UCLAMP support.
        Combines box64 emulation with big.LITTLE core pinning.
        """
        script_content = f'''#!/bin/bash
# Auto-generated box64 + UCLAMP wrapper for Wine/Xenia on aarch64
# Forces scheduler to prefer big cores on big.LITTLE SoCs

BOX64_BIN="{box64_bin}"
WINE_BIN="{wine_bin}"
UCLAMP_MIN={uclamp_min}
UCLAMP_MAX={uclamp_max}

# Launch wine through box64 in background
"$BOX64_BIN" "$WINE_BIN" "$@" &
EMU_PID=$!

# Brief delay for process to initialize
sleep 0.3

# Apply UCLAMP settings to main process and all threads
apply_uclamp() {{
    local pid=$1
    if [ -d "/proc/$pid" ]; then
        # Main process
        echo $UCLAMP_MIN > /proc/$pid/sched_util_min 2>/dev/null
        echo $UCLAMP_MAX > /proc/$pid/sched_util_max 2>/dev/null
        
        # All threads (box64 creates many)
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

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        # Use wine proton
        wine_runner = wine.Runner("wine-proton", 'xbox360')

        xeniaConfig = CONFIGS / 'xenia'
        xeniaCache = CACHE / 'xenia'
        xeniaSaves = SAVES / 'xbox360'
        emupath = wine_runner.bottle_dir / 'xenia'
        canarypath = wine_runner.bottle_dir / 'xenia-canary'

        core = system.config.core

        # check Vulkan first before doing anything
        if vulkan.is_available():
            _logger.debug("Vulkan driver is available on the system.")
            vulkan_version = vulkan.get_version()
            if vulkan_version > "1.3":
                _logger.debug("Using Vulkan version: %s", vulkan_version)
            else:
                if str(_cfg_get(system, 'xenia_api', 'D3D12', 'gpu')).upper() == "D3D12":
                    _logger.debug("Vulkan version: %s is not compatible with Xenia when using D3D12", vulkan_version)
                    _logger.debug("You may have performance & graphical errors, switching to native Vulkan")
                    system.config['xenia_api'] = "Vulkan"
                else:
                    _logger.debug("Vulkan version: %s is not recommended with Xenia", vulkan_version)
        else:
            _logger.debug("*** Vulkan driver required is not available on the system!!! ***")
            sys.exit()

        # set to 64bit environment by default
        os.environ['WINEARCH'] = 'win64'

        # make system directories
        mkdir_if_not_exists(wine_runner.bottle_dir)
        mkdir_if_not_exists(xeniaConfig)
        mkdir_if_not_exists(xeniaCache)
        mkdir_if_not_exists(xeniaSaves)

        # create dir & copy xenia exe to wine bottle as necessary
        if not emupath.exists():
            shutil.copytree('/usr/xenia', emupath)
        if not canarypath.exists():
            shutil.copytree('/usr/xenia-canary', canarypath)
        # check binary then copy updated xenia exe's as necessary
        if not filecmp.cmp('/usr/xenia/xenia.exe', emupath / 'xenia.exe'):
            shutil.copytree('/usr/xenia', emupath, dirs_exist_ok=True)
        # xenia canary - copy patches directory also
        if not filecmp.cmp('/usr/xenia-canary/xenia_canary.exe', canarypath / 'xenia_canary.exe'):
            shutil.copytree('/usr/xenia-canary', canarypath, dirs_exist_ok=True)
        if not (canarypath / 'patches').exists():
            shutil.copytree('/usr/xenia-canary', canarypath, dirs_exist_ok=True)
        # update patches accordingly
        self.sync_directories(Path('/usr/xenia-canary'), canarypath)

        # create portable txt file to try & stop file spam
        if not (emupath / 'portable.txt').exists():
            with (emupath / 'portable.txt').open('w'):
                pass
        if not (canarypath / 'portable.txt').exists():
            with (canarypath / 'portable.txt').open('w'):
                pass

        wine_runner.install_wine_trick('vcrun2022')

        dll_files = ["d3d12.dll", "d3d12core.dll", "d3d11.dll", "d3d10core.dll", "d3d9.dll", "d3d8.dll", "dxgi.dll"]
        # Create symbolic links for 64-bit DLLs
        for dll in dll_files:
            try:
                src_path = wine.WINE_BASE / "dxvk" / "x64" / dll
                dest_path = wine_runner.bottle_dir / "drive_c" / "windows" / "system32" / dll
                # Remove existing link if it already exists
                if dest_path.exists() or dest_path.is_symlink():
                    dest_path.unlink()
                dest_path.symlink_to(src_path)
            except Exception as e:
                _logger.debug("Error creating 64-bit link for %s: %s", dll, e)

        # Create symbolic links for 32-bit DLLs
        for dll in dll_files:
            try:
                src_path = wine.WINE_BASE / "dxvk" / "x32" / dll
                dest_path = wine_runner.bottle_dir / "drive_c" / "windows" / "syswow64" / dll
                # Remove existing link if it already exists
                if dest_path.exists() or dest_path.is_symlink():
                    dest_path.unlink()
                dest_path.symlink_to(src_path)
            except Exception as e:
                _logger.debug("Error creating 32-bit link for %s: %s", dll, e)

        # If we got a directory, attempt to resolve the first ISO recursively.
        if rom.is_dir():
            iso_files = sorted(rom.glob("**/*.iso"))
            if iso_files:
                rom = iso_files[0]
                _logger.debug("Resolved folder rom to ISO: %s", rom)
            else:
                raise FileNotFoundError(f"Unable to find any .iso in folder: {rom}")

        # are we loading a digital title playlist?
        if rom.suffix.lower() in ('.xbox360', '.m3u'):
            _logger.debug('Found playlist file: %s', rom)
            pathLead = rom.parent
            with rom.open(encoding='utf-8', errors='ignore') as openFile:
                first_line = ""
                for line in openFile:
                    stripped = line.strip()
                    if stripped:
                        first_line = stripped
                        break

                if not first_line:
                    _logger.error('Playlist file %s does not contain any valid path.', rom)
                else:
                    if first_line.startswith(("/", "\\", "#")):
                        first_line = first_line[1:]
                    elif first_line.startswith((".\\", "./")):
                        first_line = first_line[2:]

                    _logger.debug('Checking if specified disc installation / XBLA file actually exists...')
                    playlist_target = pathLead / first_line
                    if playlist_target.exists():
                        _logger.debug('Found! Switching active rom to: %s', first_line)
                        rom = playlist_target
                    else:
                        _logger.error('Disc installation/XBLA title %s from %s not found, check path or filename.', first_line, rom)

        # adjust the config toml file accordingly
        config: dict[str, dict[str, Any]] = {}
        if core == 'xenia-canary':
            toml_file = canarypath / 'xenia-canary.config.toml'
        else:
            toml_file = emupath / 'xenia.config.toml'
        if toml_file.is_file():
            with toml_file.open() as f:
                config: dict[str, dict[str, Any]] = toml.load(f)

        # [ Now adjust the config file defaults & options we want ]
        cpu_cfg = config.setdefault('CPU', {})
        cpu_cfg['break_on_unimplemented_instructions'] = _cfg_get_bool(system, 'break_on_unimplemented_instructions', False)

        content_cfg = config.setdefault('Content', {})
        content_cfg['license_mask'] = _cfg_get_int(system, 'license_mask', _cfg_get_int(system, 'xenia_license', 1), 'xenia_license')

        d3d12_cfg = config.setdefault('D3D12', {})
        d3d12_cfg['d3d12_readback_resolve'] = _cfg_get_bool(system, 'd3d12_readback_resolve', _cfg_get_bool(system, 'xenia_readback_resolve', False), 'xenia_readback_resolve')
        d3d12_cfg['d3d12_queue_priority'] = _cfg_get_int(system, 'xenia_queue_priority', 0)
        d3d12_cfg['d3d12_debug'] = _cfg_get_bool(system, 'xenia_d3d12_debug', False)

        vulkan_cfg = config.setdefault('Vulkan', {})
        vulkan_cfg['vulkan_sparse_shared_memory'] = False
        allow_tearing = _cfg_get_bool(system, 'xenia_allow_variable_refresh_rate_and_tearing', True)
        d3d12_cfg['d3d12_allow_variable_refresh_rate_and_tearing'] = allow_tearing
        vulkan_cfg['vulkan_allow_present_mode_immediate'] = allow_tearing

        display_cfg = config.setdefault('Display', {})
        display_cfg['fullscreen'] = True
        default_internal_res = _cfg_get_int(system, 'xenia_resolution', 8)
        display_cfg['internal_display_resolution'] = _cfg_get_int(system, 'xenia_internal_display_resolution', default_internal_res, 'xenia_resolution')
        display_cfg['postprocess_antialiasing'] = str(_cfg_get(system, 'postprocess_antialiasing', 'off'))
        display_cfg['postprocess_scaling_and_sharpening'] = str(_cfg_get(system, 'postprocess_scaling_and_sharpening', ''))

        # Canary/Edge use a dedicated "Video" node; keep it synced for compatibility.
        video_cfg = config.setdefault('Video', {})
        video_cfg['internal_display_resolution'] = display_cfg['internal_display_resolution']
        video_cfg['video_standard'] = _cfg_get_int(system, 'xenia_video_standard', 1)
        video_cfg['avpack'] = _cfg_get_int(system, 'xenia_avpack', 8)
        video_cfg['widescreen'] = _cfg_get_bool(system, 'xenia_widescreen', True)
        video_cfg['use_50Hz_mode'] = _cfg_get_bool(system, 'xenia_pal50', False)
        video_cfg['async_shader_compilation'] = _cfg_get_bool(system, 'async_shader_compilation', False)

        gpu_cfg = config.setdefault('GPU', {})
        gpu_backend = str(_cfg_get(system, 'gpu', _cfg_get(system, 'xenia_api', 'D3D12'), 'xenia_api')).lower()
        gpu_cfg['gpu'] = gpu_backend
        gpu_cfg['vsync'] = _cfg_get_bool(system, 'vsync', _cfg_get_bool(system, 'xenia_vsync', True), 'xenia_vsync')
        gpu_cfg['framerate_limit'] = _cfg_get_int(system, 'xenia_framerate_limit', _cfg_get_int(system, 'xenia_vsync_fps', 0), 'xenia_vsync_fps')
        gpu_cfg['clear_memory_page_state'] = _cfg_get_bool(system, 'xenia_clear_memory_page_state', _cfg_get_bool(system, 'xenia_page_state', False), 'xenia_page_state')
        gpu_cfg['gpu_allow_invalid_fetch_constants'] = _cfg_get_bool(system, 'gpu_allow_invalid_fetch_constants', False)

        render_target_path = str(_cfg_get(system, 'render_target_path', _cfg_get(system, 'xenia_target_path', 'rtv'), 'xenia_target_path'))
        gpu_cfg['render_target_path'] = render_target_path
        if render_target_path == 'performance':
            gpu_cfg['render_target_path_d3d12'] = 'rtv'
            gpu_cfg['render_target_path_vulkan'] = 'fbo'
        elif render_target_path == 'accuracy':
            gpu_cfg['render_target_path_d3d12'] = 'rov'
            gpu_cfg['render_target_path_vulkan'] = 'fsi'
        else:
            if render_target_path in ('any', 'rtv', 'rov'):
                gpu_cfg['render_target_path_d3d12'] = render_target_path
            if render_target_path in ('any', 'fbo', 'fsi'):
                gpu_cfg['render_target_path_vulkan'] = render_target_path

        gpu_cfg['query_occlusion_fake_sample_count'] = _cfg_get_int(system, 'query_occlusion_fake_sample_count', _cfg_get_int(system, 'xenia_query_occlusion', 1000), 'xenia_query_occlusion')
        gpu_cfg['query_occlusion_sample_lower_threshold'] = _cfg_get_int(system, 'query_occlusion_sample_lower_threshold', 80)
        gpu_cfg['query_occlusion_sample_upper_threshold'] = _cfg_get_int(system, 'query_occlusion_sample_upper_threshold', 100)
        if gpu_cfg['query_occlusion_sample_upper_threshold'] == 0:
            gpu_cfg['query_occlusion_sample_lower_threshold'] = 0

        readback_resolve = _cfg_get(system, 'readback_resolve', system.config.MISSING)
        if readback_resolve is not system.config.MISSING:
            gpu_cfg['readback_resolve'] = str(readback_resolve)

        # texture cache controls
        gpu_cfg['texture_cache_memory_limit_hard'] = _cfg_get_int(system, 'xenia_limit_hard', 768)
        gpu_cfg['texture_cache_memory_limit_render_to_texture'] = _cfg_get_int(system, 'xenia_limit_render_to_texture', 24)
        gpu_cfg['texture_cache_memory_limit_soft'] = _cfg_get_int(system, 'xenia_limit_soft', 384)
        gpu_cfg['texture_cache_memory_limit_soft_lifetime'] = _cfg_get_int(system, 'xenia_limit_soft_lifetime', 30)

        general_cfg = config.setdefault('General', {})
        general_cfg['discord'] = _cfg_get_bool(system, 'discord', False)
        general_cfg['apply_patches'] = _cfg_get_bool(system, 'xenia_patches', False)

        hid_cfg = config.setdefault('HID', {})
        hid_cfg['hid'] = str(_cfg_get(system, 'xenia_hid', 'sdl'))

        logging_cfg = config.setdefault('Logging', {})
        logging_cfg['log_level'] = 1

        memory_cfg = config.setdefault('Memory', {})
        memory_cfg['protect_zero'] = _cfg_get_bool(system, 'protect_zero', True)
        memory_cfg['scribble_heap'] = _cfg_get_bool(system, 'scribble_heap', False)

        storage_cfg = config.setdefault('Storage', {})
        storage_cfg['cache_root'] = str(xeniaCache)
        storage_cfg['content_root'] = str(xeniaSaves)
        storage_cfg['mount_scratch'] = True
        storage_cfg['storage_root'] = str(xeniaConfig)
        storage_cfg['mount_cache'] = _cfg_get_bool(system, 'mount_cache', _cfg_get_bool(system, 'xenia_cache', True), 'xenia_cache')

        ui_cfg = config.setdefault('UI', {})
        ui_cfg['headless'] = _cfg_get_bool(system, 'xenia_headless', False)
        ui_cfg['show_achievement_notification'] = _cfg_get_bool(system, 'xenia_achievement', False)

        xconfig_cfg = config.setdefault('XConfig', {})
        xconfig_cfg['user_country'] = _cfg_get_int(system, 'xenia_country', 103)  # 103 = US
        user_language = _cfg_get(system, 'xenia_lang', _cfg_get(system, 'xenia_language', 1), 'xenia_language', 'xenia_lang_edge')
        try:
            xconfig_cfg['user_language'] = int(str(user_language))
        except (TypeError, ValueError):
            xconfig_cfg['user_language'] = str(user_language)

        profiles_cfg = config.setdefault('Profiles', {})
        for i in range(1, 4):
            profile_hint = system.config.get(f'xenia_profile{i}', system.config.MISSING)
            if profile_hint is system.config.MISSING or not str(profile_hint):
                continue
            profile = Path(str(profile_hint)).stem
            profiles_cfg[f'logged_profile_slot_{i - 1}_xuid'] = profile

        # now write the updated toml
        with toml_file.open('w') as f:
            toml.dump(config, f)

        # handle patches files to set all matching toml files keys to true
        rom_name = rom.stem
        # simplify the name for matching
        rom_name = re.sub(r'\[.*?\]', '', rom_name)
        rom_name = re.sub(r'\(.*?\)', '', rom_name)
        if system.config.get_bool('xenia_patches'):
            # pattern to search for matching .patch.toml files
            matching_files = [file_path for file_path in (canarypath / 'patches').glob(f'*{rom_name}*.patch.toml') if re.search(rom_name, file_path.name, re.IGNORECASE)]
            if matching_files:
                for file_path in matching_files:
                    _logger.debug('Enabling patches for: %s', file_path)
                    # load the matchig .patch.toml file
                    with file_path.open('r') as f:
                        patch_toml = toml.load(f)
                    # modify all occurrences of the `is_enabled` key to `true`
                    for patch in patch_toml.get('patch', []):
                        if 'is_enabled' in patch:
                            patch['is_enabled'] = True
                    # save the updated .patch.toml file
                    with file_path.open('w') as f:
                        toml.dump(patch_toml, f)
            else:
                _logger.debug('No patch file found for %s', rom_name)

        # Determine the executable path
        if core == 'xenia-canary':
            xenia_exe = canarypath / 'xenia_canary.exe'
        else:
            xenia_exe = emupath / 'xenia.exe'

        # Get wine64 binary path
        wine64_bin = str(wine_runner.wine64)

        # Check for aarch64 and setup box64 wrapping
        use_box64 = self.is_aarch64()
        use_uclamp = system.config.get_bool("perf_uclamp", True) and use_box64
        uclamp_min = system.config.get_int("perf_uclamp_min", UCLAMP_MIN)

        if use_box64:
            _logger.info("Running on aarch64 - enabling box64 wrapper for Wine/Xenia")
            box64_bin = "box64"

            # Create wrapper directory
            wrapper_dir = xeniaConfig / "box64-wrappers"
            mkdir_if_not_exists(wrapper_dir)

            if use_uclamp:
                # Create combined box64 + UCLAMP wrapper
                wrapper_path = wrapper_dir / "xenia-box64-uclamp.sh"
                self._write_uclamp_box64_wrapper(
                    wrapper_path, box64_bin, wine64_bin, uclamp_min, UCLAMP_MAX
                )
                _logger.info("Created box64 + UCLAMP wrapper at %s", wrapper_path)
            else:
                # Create simple box64 wrapper
                wrapper_path = wrapper_dir / "xenia-box64.sh"
                self._write_box64_wrapper(wrapper_path, box64_bin, wine64_bin)
                _logger.info("Created box64 wrapper at %s", wrapper_path)

            # Build command using wrapper
            if configure_emulator(rom):
                commandArray = [str(wrapper_path), str(xenia_exe)]
            else:
                commandArray = [str(wrapper_path), str(xenia_exe), f'z:{rom}']
        else:
            # Native x86_64 - use wine directly
            if configure_emulator(rom):
                commandArray = [wine_runner.wine64, xenia_exe]
            else:
                commandArray = [wine_runner.wine64, xenia_exe, f'z:{rom}']

        # Build environment
        environment = wine_runner.get_environment()
        environment.update(
            {
                'LD_LIBRARY_PATH': f'/usr/lib:{environment["LD_LIBRARY_PATH"]}',
                'LIBGL_DRIVERS_PATH': '/usr/lib/dri',
                'SDL_GAMECONTROLLERCONFIG': generate_sdl_game_controller_config(playersControllers),
                'SDL_JOYSTICK_HIDAPI': '0',
                'VKD3D_SHADER_CACHE_PATH': str(xeniaCache),
                'WINEDLLOVERRIDES': "winemenubuilder.exe=;dxgi,d3d8,d3d9,d3d10core,d3d11,d3d12,d3d12core=n",
            }
        )

        # Add box64 environment variables for aarch64
        if use_box64:
            environment.update(
                {
                    'BOX64_LOG': '0',
                    'BOX64_DYNAREC': '1',
                    'BOX64_DYNAREC_BIGBLOCK': '1',
                    'BOX64_DYNAREC_STRONGMEM': '2',
                    'BOX64_DYNAREC_FASTROUND': '1',
                    'BOX64_DYNAREC_FASTNAN': '1',
                    'BOX64_DYNAREC_SAFEFLAGS': '1',
                    # Additional tuning for Xenia specifically
                    'BOX64_DYNAREC_X87DOUBLE': '1',
                    'BOX64_DYNAREC_BLEEDING_EDGE': '1',
                }
            )
            _logger.debug("Box64 environment configured for optimal Xenia performance")

        # ensure nvidia driver used for vulkan
        if Path('/var/tmp/nvidia.prime').exists():
            variables_to_remove = ['__NV_PRIME_RENDER_OFFLOAD', '__VK_LAYER_NV_optimus', '__GLX_VENDOR_LIBRARY_NAME']
            for variable_name in variables_to_remove:
                if variable_name in os.environ:
                    del os.environ[variable_name]

            environment.update(
                {
                    'VK_ICD_FILENAMES': '/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json',
                    'VK_LAYER_PATH': '/usr/share/vulkan/explicit_layer.d'
                }
            )

        return Command.Command(array=commandArray, env=environment)

    # Show mouse on screen when needed
    # xenia auto-hides
    def getMouseMode(self, config, rom):
        return True
