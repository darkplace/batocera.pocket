from __future__ import annotations

import filecmp
import logging
import os
import platform
import re
import shlex
import shutil
import stat
import subprocess
import sys
from pathlib import Path
from typing import TYPE_CHECKING, Any

import toml

from ... import Command
from ...batoceraPaths import BATOCERA_SHARE_DIR, CACHE, CONFIGS, SAVES, configure_emulator, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ...utils import lsfg, vulkan, wine
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext

_logger = logging.getLogger(__name__)

# UCLAMP values (out of 1024) for big.LITTLE optimization
UCLAMP_MIN = 819
UCLAMP_MAX = 1024
_BATOCERA_ACHIEVEMENT_SOUND_ROOT = Path('/usr/share/libretro/assets/sounds')
_BATOCERA_DEFAULT_XENIA_ACHIEVEMENT_SOUND = 'xbox360-achievement'

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

def _wine_path_from_unix(path: Path) -> str:
    return 'Z:/' + str(path).lstrip('/')

def _retroachievements_sound_disabled(sound: str) -> bool:
    return sound.lower() in ('', '0', 'false', 'none')

def _retroachievements_sound_path(sound: str) -> Path | None:
    if _retroachievements_sound_disabled(sound):
        return None

    if '/' in sound:
        path = Path(sound)
        return path if path.is_file() else None

    for suffix in ('.ogg', '.wav'):
        path = _BATOCERA_ACHIEVEMENT_SOUND_ROOT / f'{sound}{suffix}'
        if path.is_file():
            return path

    return None

def _prepare_wine_achievement_sound(source: Path, config_root: Path) -> Path | None:
    if source.suffix.lower() == '.wav':
        return source

    target = config_root / 'batocera-achievement.wav'
    mkdir_if_not_exists(target.parent)

    try:
        if not target.exists() or target.stat().st_mtime < source.stat().st_mtime:
            ffmpeg = shutil.which('ffmpeg')
            if ffmpeg is None:
                _logger.warning('ffmpeg is missing; cannot convert %s for Wine Xenia achievement sound', source)
                return None
            subprocess.run(
                [ffmpeg, '-y', '-loglevel', 'error', '-i', str(source), str(target)],
                check=True,
            )
    except (OSError, subprocess.CalledProcessError) as exc:
        _logger.warning('Failed to prepare Wine Xenia achievement sound from %s: %s', source, exc)
        return None

    return target if target.is_file() else None

def _xenia_achievement_sound_path(system: Any, native_linux: bool, config_root: Path) -> str:
    sound = system.config.get('retroachievements.sound', _BATOCERA_DEFAULT_XENIA_ACHIEVEMENT_SOUND)
    path = _retroachievements_sound_path(str(sound))
    if path is None:
        return ''

    if native_linux:
        return str(path)

    wine_path = _prepare_wine_achievement_sound(path, config_root)
    return _wine_path_from_unix(wine_path) if wine_path else ''

def _batocera_arch() -> str:
    try:
        return (BATOCERA_SHARE_DIR / 'batocera.arch').read_text().strip().lower()
    except OSError:
        return ''

def _normalize_xenia_profile_xuid(value: Any) -> str:
    text = str(value or '').strip()
    if text.lower() in ('', 'auto', 'prompt', 'ask', 'ask each time', 'none', 'disabled', '0', 'false'):
        return ''

    for candidate in (text.split(':', 1)[0], Path(text).stem, text):
        match = re.search(r'(?i)(?:0x)?([0-9a-f]{16})', candidate)
        if match:
            return match.group(1).upper()

    return ''

def _apply_xenia_profiles(system: Any, config: dict[str, dict[str, Any]]) -> None:
    profiles_cfg = config.setdefault('Profiles', {})
    selected: dict[int, str] = {}

    primary_profile = _normalize_xenia_profile_xuid(_cfg_get(system, 'xenia_profile', ''))
    if primary_profile:
        selected[0] = primary_profile

    for slot in range(4):
        profile_hint = system.config.get(f'xenia_profile{slot + 1}', system.config.MISSING)
        if profile_hint is system.config.MISSING:
            continue

        profile = _normalize_xenia_profile_xuid(profile_hint)
        if profile:
            selected[slot] = profile
        else:
            selected.pop(slot, None)

    for slot in range(4):
        profiles_cfg[f'logged_profile_slot_{slot}_xuid'] = selected.get(slot, '')


class XeniaGenerator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "xenia",
            "keys": { "exit": ["KEY_LEFTALT", "KEY_F4"], "menu": ["KEY_LEFTSHIFT", "KEY_F10"] }
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
    def _write_wine_cleanup_wrapper(wrapper_path: Path, wine_bin: str, wine_server_bin: str) -> None:
        script_content = f'''#!/bin/bash
# Auto-generated Wine cleanup wrapper for Xenia.

WINE_BIN={shlex.quote(wine_bin)}
WINE_SERVER={shlex.quote(wine_server_bin)}
EMU_PID=""

debug_log() {{
    [ "${{BATOCERA_XENIA_CLEANUP_DEBUG:-0}}" = "1" ] || return 0
    printf '%s %s\\n' "$(date -Is 2>/dev/null || date)" "$*" >> /tmp/xenia-wine-cleanup.log
}}

cleanup() {{
    local status=${{1:-$?}}
    trap - EXIT HUP INT TERM
    debug_log "cleanup status=$status self=$$ parent=$PPID emu=$EMU_PID"

    kill_wineprefix_processes() {{
        local signal=$1
        local pids=""
        local env_file pid comm

        [ -n "${{WINEPREFIX:-}}" ] || return 0

        for env_file in /proc/[0-9]*/environ; do
            pid=${{env_file#/proc/}}
            pid=${{pid%/environ}}
            [ "$pid" = "$$" ] && continue

            if tr '\\0' '\\n' < "$env_file" 2>/dev/null | grep -Fx "WINEPREFIX=$WINEPREFIX" >/dev/null; then
                comm=$(cat "/proc/$pid/comm" 2>/dev/null || true)
                case "$comm" in
                    wineserver|services.exe|winedevice.exe|plugplay.exe|explorer.exe|wine*|*.exe|gamescope*|gamescopereaper)
                        pids="$pids $pid"
                        ;;
                esac
            fi
        done

        debug_log "kill_wineprefix_processes signal=$signal pids=$pids"
        [ -n "$pids" ] && kill "-$signal" $pids 2>/dev/null || true
    }}

    stop_gamescope_parent() {{
        local parent_pid=$PPID
        local parent_comm
        local gamescope_pid

        parent_comm=$(cat "/proc/$parent_pid/comm" 2>/dev/null || true)
        debug_log "stop_gamescope_parent parent=$parent_pid comm=$parent_comm"
        [ "$parent_comm" = "gamescopereaper" ] || return 0

        gamescope_pid=$(awk '/^PPid:/ {{ print $2 }}' "/proc/$parent_pid/status" 2>/dev/null || true)
        debug_log "stop_gamescope_parent gamescope=$gamescope_pid"
        kill -TERM "$parent_pid" "$gamescope_pid" 2>/dev/null || true
        sleep 0.5
        kill -KILL "$parent_pid" "$gamescope_pid" 2>/dev/null || true
    }}

    if [ "$status" -ge 128 ] 2>/dev/null; then
        [ -n "$EMU_PID" ] && kill -KILL "$EMU_PID" 2>/dev/null || true
        [ -n "${{WINEPREFIX:-}}" ] && [ -x "$WINE_SERVER" ] && "$WINE_SERVER" -k >/dev/null 2>&1 || true
        kill_wineprefix_processes KILL
        stop_gamescope_parent
        exit "$status"
    fi

    if [ -n "$EMU_PID" ] && kill -0 "$EMU_PID" 2>/dev/null; then
        kill -TERM "$EMU_PID" 2>/dev/null || true
        sleep 0.5
        kill -KILL "$EMU_PID" 2>/dev/null || true
    fi

    if [ -n "${{WINEPREFIX:-}}" ] && [ -x "$WINE_SERVER" ]; then
        "$WINE_SERVER" -w >/dev/null 2>&1 &
        local wait_pid=$!
        for _ in 1 2 3 4 5; do
            if ! kill -0 "$wait_pid" 2>/dev/null; then
                break
            fi
            sleep 0.2
        done
        kill "$wait_pid" 2>/dev/null || true
        "$WINE_SERVER" -k >/dev/null 2>&1 || true
    fi

    kill_wineprefix_processes TERM
    sleep 0.5
    kill_wineprefix_processes KILL
    stop_gamescope_parent

    exit "$status"
}}

trap 'cleanup $?' EXIT HUP INT TERM

debug_log "start self=$$ parent=$PPID args=$*"
"$WINE_BIN" "$@" &
EMU_PID=$!
debug_log "spawned emu=$EMU_PID"
wait "$EMU_PID"
EXIT_STATUS=$?
debug_log "wait_done status=$EXIT_STATUS emu=$EMU_PID"
cleanup "$EXIT_STATUS"
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
        core = system.config.core

        # Use wine proton
        wine_runner = wine.Runner("wine-proton", 'xbox360')

        xeniaConfig = CONFIGS / 'xenia'
        xeniaCache = CACHE / 'xenia'
        xeniaSaves = SAVES / 'xbox360'
        xeniaCanaryConfig = CONFIGS / 'xenia-canary'
        xeniaCanaryCache = CACHE / 'xenia-canary'
        xeniaEdgeConfig = CONFIGS / 'xenia-edge'
        xeniaEdgeCache = CACHE / 'xenia-edge'
        emupath = wine_runner.bottle_dir / 'xenia'
        canarypath = wine_runner.bottle_dir / 'xenia-canary'
        canaryPatchesSource = Path('/usr/share/xenia-canary/patches')
        edgePatchesSource = Path('/usr/share/xenia-edge/patches')
        is_aarch64 = self.is_aarch64()
        batocera_arch = _batocera_arch()

        if is_aarch64 and core == 'xenia':
            _logger.error("Xenia Wine/D3D12 path is not supported on aarch64")
            sys.exit()
        if is_aarch64 and core == 'xenia-canary' and batocera_arch not in ('sm8550', 'sm8750'):
            _logger.error("Native Xenia Canary is gated to sm8x50; current target is %s", batocera_arch or "unknown")
            sys.exit()

        requested_gpu_backend = str(
            _cfg_get(system, 'gpu', _cfg_get(system, 'xenia_api', 'Vulkan' if is_aarch64 else 'D3D12'), 'xenia_api')
        ).lower()
        canary_native_requested = (
            core == 'xenia-canary'
            and (is_aarch64 or requested_gpu_backend not in ('', 'any', 'd3d12', 'direct3d12'))
        )
        native_canary = canary_native_requested and Path('/usr/bin/xenia-canary').exists()
        native_linux = core == 'xenia-edge' or native_canary
        if core == 'xenia-canary' and canary_native_requested and not native_canary:
            _logger.error("Native Xenia Canary binary is missing; refusing to create a Wine bottle for Vulkan mode")
            sys.exit()
        if core == 'xenia-edge' and not Path('/usr/bin/xenia-edge').exists():
            _logger.error("Native Xenia Edge binary is missing")
            sys.exit()

        allow_d3d12 = not native_linux and not is_aarch64
        default_gpu_backend = 'D3D12' if allow_d3d12 else 'Vulkan'
        configured_gpu_backend = str(_cfg_get(system, 'gpu', _cfg_get(system, 'xenia_api', default_gpu_backend), 'xenia_api'))
        if not allow_d3d12 and configured_gpu_backend.lower() in ('', 'any', 'd3d12', 'direct3d12'):
            _logger.info("Forcing native Vulkan for this Xenia target")
            system.config['gpu'] = "Vulkan"
            system.config['xenia_api'] = "Vulkan"

        # check Vulkan first before doing anything
        if vulkan.is_available():
            _logger.debug("Vulkan driver is available on the system.")
            vulkan_version = vulkan.get_version()
            if vulkan_version > "1.3":
                _logger.debug("Using Vulkan version: %s", vulkan_version)
            else:
                if str(_cfg_get(system, 'xenia_api', default_gpu_backend, 'gpu')).upper() == "D3D12":
                    _logger.debug("Vulkan version: %s is not compatible with Xenia when using D3D12", vulkan_version)
                    _logger.debug("You may have performance & graphical errors, switching to native Vulkan")
                    system.config['xenia_api'] = "Vulkan"
                else:
                    _logger.debug("Vulkan version: %s is not recommended with Xenia", vulkan_version)
        else:
            _logger.debug("*** Vulkan driver required is not available on the system!!! ***")
            sys.exit()

        if core == 'xenia-edge':
            mkdir_if_not_exists(xeniaEdgeConfig)
            mkdir_if_not_exists(xeniaEdgeCache)
            mkdir_if_not_exists(xeniaSaves)
            mkdir_if_not_exists(xeniaEdgeConfig / 'patches')
            if edgePatchesSource.exists():
                self.sync_directories(edgePatchesSource, xeniaEdgeConfig / 'patches')
        elif native_canary:
            mkdir_if_not_exists(xeniaCanaryConfig)
            mkdir_if_not_exists(xeniaCanaryCache)
            mkdir_if_not_exists(xeniaSaves)
            mkdir_if_not_exists(xeniaCanaryConfig / 'patches')
            if canaryPatchesSource.exists():
                self.sync_directories(canaryPatchesSource, xeniaCanaryConfig / 'patches')
        else:
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

            dll_files = ["d3d11.dll", "d3d10core.dll", "d3d9.dll", "d3d8.dll", "dxgi.dll"]
            if allow_d3d12:
                dll_files.extend(["d3d12.dll", "d3d12core.dll"])
            # Create symbolic links for 64-bit DLLs
            for dll in dll_files:
                try:
                    src_path = wine.WINE_BASE / "dxvk" / "x64" / dll
                    dest_path = wine_runner.bottle_dir / "drive_c" / "windows" / "system32" / dll
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
                    if dest_path.exists() or dest_path.is_symlink():
                        dest_path.unlink()
                    dest_path.symlink_to(src_path)
                except Exception as e:
                    _logger.debug("Error creating 32-bit link for %s: %s", dll, e)

            if not allow_d3d12:
                for dll in ("d3d12.dll", "d3d12core.dll"):
                    for windows_dir in ("system32", "syswow64"):
                        dest_path = wine_runner.bottle_dir / "drive_c" / "windows" / windows_dir / dll
                        if dest_path.is_symlink():
                            dest_path.unlink()

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
            toml_file = (xeniaCanaryConfig if native_canary else canarypath) / 'xenia-canary.config.toml'
        elif core == 'xenia-edge':
            toml_file = xeniaEdgeConfig / 'xenia-edge.config.toml'
        else:
            toml_file = emupath / 'xenia.config.toml'
        if toml_file.is_file():
            try:
                with toml_file.open() as f:
                    config: dict[str, dict[str, Any]] = toml.load(f)
            except toml.TomlDecodeError as exc:
                _logger.warning("Ignoring invalid Xenia config %s: %s", toml_file, exc)

        # [ Now adjust the config file defaults & options we want ]
        if core == 'xenia-edge':
            sound_config_root = xeniaEdgeConfig
        elif native_canary:
            sound_config_root = xeniaCanaryConfig
        else:
            sound_config_root = xeniaConfig

        xenia_achievement_sound = _cfg_get_bool(system, 'xenia_achievement_sound', True)
        xenia_achievement_sound_path = ''
        if xenia_achievement_sound and _cfg_get_bool(system, 'xenia_achievement', True):
            xenia_achievement_sound_path = _xenia_achievement_sound_path(system, native_linux, sound_config_root)

        cpu_cfg = config.setdefault('CPU', {})
        cpu_cfg['break_on_unimplemented_instructions'] = _cfg_get_bool(system, 'break_on_unimplemented_instructions', False)
        cpu_cfg['disable_context_promotion'] = _cfg_get_bool(
            system, 'xenia_disable_context_promotion', False, 'disable_context_promotion'
        )

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
        video_cfg['async_shader_compilation'] = _cfg_get_bool(
            system, 'xenia_async_shader_compilation', _cfg_get_bool(system, 'async_shader_compilation', False),
            'async_shader_compilation'
        )

        apu_cfg = config.setdefault('APU', {})
        apu_cfg['use_dedicated_xma_thread'] = _cfg_get_bool(
            system, 'xenia_use_dedicated_xma_thread', True, 'use_dedicated_xma_thread'
        )

        gpu_cfg = config.setdefault('GPU', {})
        gpu_backend = str(_cfg_get(system, 'gpu', _cfg_get(system, 'xenia_api', default_gpu_backend), 'xenia_api')).lower()
        if not allow_d3d12 and gpu_backend in ('', 'any', 'd3d12', 'direct3d12'):
            gpu_backend = 'vulkan'
        gpu_cfg['gpu'] = gpu_backend
        gpu_cfg['vsync'] = _cfg_get_bool(system, 'vsync', _cfg_get_bool(system, 'xenia_vsync', True), 'xenia_vsync')
        gpu_cfg['framerate_limit'] = _cfg_get_int(system, 'xenia_framerate_limit', _cfg_get_int(system, 'xenia_vsync_fps', 0), 'xenia_vsync_fps')
        gpu_cfg['clear_memory_page_state'] = _cfg_get_bool(system, 'xenia_clear_memory_page_state', _cfg_get_bool(system, 'xenia_page_state', False), 'xenia_page_state')
        gpu_cfg['gpu_allow_invalid_fetch_constants'] = _cfg_get_bool(
            system, 'xenia_gpu_allow_invalid_fetch_constants', False, 'gpu_allow_invalid_fetch_constants'
        )

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
        gpu_cfg['query_occlusion_sample_lower_threshold'] = _cfg_get_int(
            system, 'xenia_query_occlusion_sample_lower_threshold', 80, 'query_occlusion_sample_lower_threshold'
        )
        gpu_cfg['query_occlusion_sample_upper_threshold'] = _cfg_get_int(
            system, 'xenia_query_occlusion_sample_upper_threshold', 100, 'query_occlusion_sample_upper_threshold'
        )
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
        general_cfg['controller_hotkeys'] = False

        hid_cfg = config.setdefault('HID', {})
        hid_cfg['hid'] = str(_cfg_get(system, 'xenia_hid', 'sdl'))

        logging_cfg = config.setdefault('Logging', {})
        logging_cfg['log_level'] = 1

        memory_cfg = config.setdefault('Memory', {})
        memory_cfg['protect_zero'] = _cfg_get_bool(system, 'xenia_protect_zero', True, 'protect_zero')
        memory_cfg['scribble_heap'] = _cfg_get_bool(system, 'scribble_heap', False)

        storage_cfg = config.setdefault('Storage', {})
        if core == 'xenia-edge':
            native_config_root = xeniaEdgeConfig
            native_cache_root = xeniaEdgeCache
        elif native_canary:
            native_config_root = xeniaCanaryConfig
            native_cache_root = xeniaCanaryCache
        else:
            native_config_root = xeniaConfig
            native_cache_root = xeniaCache

        storage_cfg['cache_root'] = str(native_cache_root)
        storage_cfg['content_root'] = str(xeniaSaves)
        storage_cfg['mount_scratch'] = True
        storage_cfg['storage_root'] = str(native_config_root)
        storage_cfg['mount_cache'] = _cfg_get_bool(system, 'mount_cache', _cfg_get_bool(system, 'xenia_cache', True), 'xenia_cache')

        ui_cfg = config.setdefault('UI', {})
        ui_cfg['headless'] = _cfg_get_bool(system, 'xenia_headless', False)
        ui_cfg['show_achievement_notification'] = _cfg_get_bool(system, 'xenia_achievement', True)
        ui_cfg['notification_sound_path'] = xenia_achievement_sound_path
        ui_cfg['achievement_sound_path'] = xenia_achievement_sound_path

        xconfig_cfg = config.setdefault('XConfig', {})
        xconfig_cfg['user_country'] = _cfg_get_int(system, 'xenia_country', 103)  # 103 = US
        user_language = _cfg_get(system, 'xenia_lang', _cfg_get(system, 'xenia_language', 1), 'xenia_language', 'xenia_lang_edge')
        try:
            xconfig_cfg['user_language'] = int(str(user_language))
        except (TypeError, ValueError):
            xconfig_cfg['user_language'] = str(user_language)

        _apply_xenia_profiles(system, config)

        # now write the updated toml
        with toml_file.open('w') as f:
            toml.dump(config, f)

        # handle patches files to set all matching toml files keys to true
        rom_name = rom.stem
        # simplify the name for matching
        rom_name = re.sub(r'\[.*?\]', '', rom_name)
        rom_name = re.sub(r'\(.*?\)', '', rom_name)
        if core == 'xenia-edge':
            patch_root = xeniaEdgeConfig / 'patches'
        elif native_canary:
            patch_root = xeniaCanaryConfig / 'patches'
        else:
            patch_root = canarypath / 'patches'
        if system.config.get_bool('xenia_patches'):
            # pattern to search for matching .patch.toml files
            matching_files = [file_path for file_path in patch_root.glob(f'*{rom_name}*.patch.toml') if re.search(rom_name, file_path.name, re.IGNORECASE)]
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
            xenia_exe = Path('/usr/bin/xenia-canary') if native_canary else canarypath / 'xenia_canary.exe'
        elif core == 'xenia-edge':
            xenia_exe = Path('/usr/bin/xenia-edge')
        else:
            xenia_exe = emupath / 'xenia.exe'

        # Get wine64 binary path
        wine64_bin = str(wine_runner.wine64)

        # Native Linux Xenia paths
        if native_linux:
            commandArray = [
                str(xenia_exe),
                f'--config={toml_file}',
                f'--gpu={gpu_backend}',
                f'--storage_root={native_config_root}',
                f'--content_root={xeniaSaves}',
                f'--cache_root={native_cache_root}',
            ]
            if not configure_emulator(rom):
                commandArray.append(str(rom))

            environment = {
                'SDL_GAMECONTROLLERCONFIG': generate_sdl_game_controller_config(playersControllers),
                'SDL_JOYSTICK_HIDAPI': '0',
                'BATOCERA_SKIP_GAMESCOPE': '1',
            }
            lsfg.apply_lsfg_vk(system, environment)
            return Command.Command(array=commandArray, env=environment)

        # Check for aarch64 and setup box64 wrapping
        use_box64 = is_aarch64
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
            wrapper_dir = xeniaConfig / "wine-wrappers"
            mkdir_if_not_exists(wrapper_dir)
            wrapper_path = wrapper_dir / "xenia-wine-cleanup.sh"
            self._write_wine_cleanup_wrapper(
                wrapper_path,
                wine64_bin,
                str(Path(wine64_bin).parent / "wineserver"),
            )
            if configure_emulator(rom):
                commandArray = [str(wrapper_path), xenia_exe]
            else:
                commandArray = [str(wrapper_path), xenia_exe, f'z:{rom}']

        # Build environment
        environment = wine_runner.get_environment()
        dll_overrides = "winemenubuilder.exe=;dxgi,d3d8,d3d9,d3d10core,d3d11=n"
        if allow_d3d12:
            dll_overrides = "winemenubuilder.exe=;dxgi,d3d8,d3d9,d3d10core,d3d11,d3d12,d3d12core=n"

        environment.update(
            {
                'LD_LIBRARY_PATH': f'/usr/lib:{environment["LD_LIBRARY_PATH"]}',
                'LIBGL_DRIVERS_PATH': '/usr/lib/dri',
                'SDL_GAMECONTROLLERCONFIG': generate_sdl_game_controller_config(playersControllers),
                'SDL_JOYSTICK_HIDAPI': '0',
                'VKD3D_SHADER_CACHE_PATH': str(xeniaCache),
                'WINEDLLOVERRIDES': dll_overrides,
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

        lsfg.apply_lsfg_vk(system, environment, use_wine_layer=True)

        return Command.Command(array=commandArray, env=environment)

    # Show mouse on screen when needed
    # xenia auto-hides
    def getMouseMode(self, config, rom):
        return True
