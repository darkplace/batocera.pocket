from __future__ import annotations

import filecmp
import logging
import platform
import re
import shutil
import sys
from pathlib import Path
from typing import TYPE_CHECKING, Any

import toml

from ... import Command
from ...batoceraPaths import CACHE, CONFIGS, SAVES, configure_emulator, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ...utils import vulkan
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext

_logger = logging.getLogger(__name__)

XENIA_EDGE_BIN     = Path('/usr/xenia_edge/xenia_edge')
XENIA_EDGE_PATCHES_SRC = Path('/usr/share/xenia-edge/patches')
XENIA_EDGE_CONFIG_SRC = Path('/usr/share/xenia-edge/config')
XENIA_ACHIEVEMENT_SOUND_ROOT = Path('/usr/share/libretro/assets/sounds')
XENIA_DEFAULT_ACHIEVEMENT_SOUND = 'xbox360-achievement'
# XenDroid GAME_COMPAT: Adreno/Turnip mid-frame submits cut GPU idle bubbles.
XENIA_EDGE_QCOM_MID_FRAME_DRAWS = 1300


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
    profile_hints: dict[int, Any] = {}

    profile_hint = system.config.get('xenia_profile', system.config.MISSING)
    if profile_hint is not system.config.MISSING:
        profile_hints[0] = profile_hint

    for slot in range(4):
        profile_hint = system.config.get(f'xenia_profile{slot + 1}', system.config.MISSING)
        if profile_hint is system.config.MISSING:
            continue
        profile_hints[slot] = profile_hint

    auto_profile = True
    for slot, profile_hint in profile_hints.items():
        profile_text = str(profile_hint or '').strip().lower()
        profile_is_auto = profile_text in ('', 'auto', 'prompt', 'ask', 'ask each time')
        if slot == 0:
            auto_profile = profile_is_auto
        if profile_is_auto:
            continue

        profile = _normalize_xenia_profile_xuid(profile_hint)
        if profile:
            profiles_cfg[f'logged_profile_slot_{slot}_xuid'] = profile
        else:
            profiles_cfg[f'logged_profile_slot_{slot}_xuid'] = ''

    profiles_cfg['batocera_auto_profile'] = auto_profile


def _achievement_sound_path(system: Any) -> str:
    sound = str(system.config.get('retroachievements.sound', XENIA_DEFAULT_ACHIEVEMENT_SOUND))
    if sound.lower() in ('', '0', 'false', 'none'):
        return ''

    if '/' in sound:
        path = Path(sound)
        return str(path) if path.is_file() else ''

    for suffix in ('.ogg', '.wav'):
        path = XENIA_ACHIEVEMENT_SOUND_ROOT / f'{sound}{suffix}'
        if path.is_file():
            return str(path)

    return ''


class XeniaEdgeGenerator(Generator):

    @staticmethod
    def sync_directories(source_dir: Path, dest_dir: Path) -> None:
        dcmp = filecmp.dircmp(source_dir, dest_dir)
        for file in dcmp.diff_files + dcmp.left_only:
            shutil.copy2(source_dir / file, dest_dir / file)

    @staticmethod
    def seed_missing_files(source_dir: Path, dest_dir: Path) -> None:
        """Copy share templates that the user does not already have (never overwrite)."""
        if not source_dir.is_dir():
            return
        mkdir_if_not_exists(dest_dir)
        for src in source_dir.iterdir():
            if not src.is_file():
                continue
            dest = dest_dir / src.name
            if not dest.exists():
                shutil.copy2(src, dest)

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "xenia-edge",
            "keys": { "exit": ["KEY_LEFTALT", "KEY_F4"] }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        xeniaConfig = CONFIGS / 'xenia_edge'
        xeniaCache  = CACHE  / 'xenia_edge'
        xeniaSaves  = SAVES  / 'xbox360'

        if vulkan.is_available():
            _logger.debug("Vulkan driver is available on the system.")
            vulkan_version = vulkan.get_version()
            if vulkan_version <= "1.3":
                _logger.warning("Vulkan version %s may not meet xenia-edge requirements (1.3+)", vulkan_version)
        else:
            _logger.error("*** Vulkan driver required by xenia-edge is not available! ***")
            sys.exit(1)

        mkdir_if_not_exists(xeniaConfig)
        mkdir_if_not_exists(xeniaCache)
        mkdir_if_not_exists(xeniaSaves)

        xeniaPatches = xeniaConfig / 'patches'
        mkdir_if_not_exists(xeniaPatches)
        if XENIA_EDGE_PATCHES_SRC.is_dir():
            self.sync_directories(XENIA_EDGE_PATCHES_SRC, xeniaPatches)

        # XenDroid GAME_COMPAT per-title TOMLs (NG2, Fable II, …).
        self.seed_missing_files(XENIA_EDGE_CONFIG_SRC, xeniaConfig / 'config')

        if rom.suffix == '.xbox360':
            _logger.debug('Found .xbox360 playlist: %s', rom)
            with rom.open() as f:
                first_line = f.readlines(1)[0].strip('\n').strip('\r').lstrip('/')
            xbla_path = rom.parent / first_line
            if xbla_path.exists():
                _logger.debug('Resolved playlist to: %s', xbla_path)
                rom = xbla_path
            else:
                _logger.error('Playlist target %s not found', xbla_path)

        toml_file = xeniaConfig / 'xenia-edge.config.toml'
        config: dict[str, dict[str, Any]] = {}
        if toml_file.is_file():
            with toml_file.open() as f:
                config = toml.load(f)

        config['APU'] = {
            'apu': system.config.get('xenia_apu', 'alsa')
        }

        config['CPU'] = {
            'break_on_unimplemented_instructions': False
        }

        config['Content'] = {
            'license_mask': system.config.get_int('xenia_license', 1)
        }

        config['Display'] = {
            'fullscreen': True,
            'internal_display_resolution': system.config.get_int('xenia_resolution', 8),
            'postprocess_scaling_and_sharpening': system.config.get('xenia_postprocess_scaling_and_sharpening', 'bilinear'),
            'postprocess_antialiasing': system.config.get('xenia_postprocess_antialiasing', 'none'),
            'postprocess_ffx_cas_additional_sharpness': float(system.config.get('xenia_postprocess_ffx_cas_additional_sharpness', '0.0')),
            'postprocess_ffx_fsr_sharpness_reduction': float(system.config.get('xenia_postprocess_ffx_fsr_sharpness_reduction', '0.2')),
        }

        if 'General' not in config:
            config['General'] = {}
        config['General']['discord'] = False
        if system.config.get_bool('xenia_patches'):
            config['General']['apply_patches'] = True
        elif 'apply_patches' not in config['General']:
            config['General']['apply_patches'] = False

        if 'GPU' not in config:
            config['GPU'] = {}
        config['GPU']['gpu'] = 'vulkan'
        config['GPU']['vsync'] = system.config.get_bool('xenia_vsync', True)
        config['GPU']['framerate_limit'] = system.config.get_int('xenia_vsync_fps', 0)
        config['GPU']['texture_cache_memory_limit_hard'] = system.config.get_int('xenia_limit_hard', 768)
        config['GPU']['texture_cache_memory_limit_render_to_texture'] = system.config.get_int('xenia_limit_render_to_texture', 24)
        config['GPU']['texture_cache_memory_limit_soft'] = system.config.get_int('xenia_limit_soft', 384)
        config['GPU']['texture_cache_memory_limit_soft_lifetime'] = system.config.get_int('xenia_limit_soft_lifetime', 30)
        # Opt-in mid-frame submits on aarch64 (Adreno/Turnip); user toml wins if set.
        if platform.machine() == 'aarch64' and 'vulkan_mid_frame_submission_draws' not in config['GPU']:
            config['GPU']['vulkan_mid_frame_submission_draws'] = XENIA_EDGE_QCOM_MID_FRAME_DRAWS

        config['HID'] = {
            'hid': 'sdl'
        }

        config['Logging'] = {
            'log_level': 1
        }

        config['Memory'] = {
            'protect_zero': False
        }

        config['Storage'] = {
            'storage_root': str(xeniaConfig),
            'content_root': str(xeniaSaves),
            'cache_root':   str(xeniaCache),
            'mount_scratch': True,
            'mount_cache':   system.config.get_bool('xenia_cache', True)
        }

        achievements_enabled = system.config.get_bool('xenia_achievement', True)
        achievement_sound = ''
        if achievements_enabled and system.config.get_bool('xenia_achievement_sound', True):
            achievement_sound = _achievement_sound_path(system)

        config['UI'] = {
            'headless': system.config.get_bool('xenia_headless', False),
            'show_achievement_notification': achievements_enabled,
            'notification_sound_path': achievement_sound,
            'achievement_sound_path': achievement_sound,
        }

        _apply_xenia_profiles(system, config)

        config['Vulkan'] = {
            'vulkan_sparse_shared_memory': False
        }

        config['XConfig'] = {
            'user_country':  system.config.get('xenia_country', 'United States'),
            'user_language': system.config.get('xenia_language', 'English')
        }

        with toml_file.open('w') as f:
            toml.dump(config, f)

        launching_title = not configure_emulator(rom)

        commandArray = [
            str(XENIA_EDGE_BIN),
            f'--config={toml_file}',
            '--gpu=vulkan',
            f'--storage_root={xeniaConfig}',
            f'--content_root={xeniaSaves}',
            f'--cache_root={xeniaCache}',
        ]
        if launching_title:
            commandArray.append('--fullscreen=true')
            commandArray.append(str(rom))

        environment = {
            'SDL_GAMECONTROLLERCONFIG': generate_sdl_game_controller_config(playersControllers),
            'SDL_JOYSTICK_HIDAPI': '0',
            'BATOCERA_SKIP_GAMESCOPE': '1',
        }

        if Path('/var/tmp/nvidia.prime').exists():
            import os
            for var in ('__NV_PRIME_RENDER_OFFLOAD', '__VK_LAYER_NV_optimus', '__GLX_VENDOR_LIBRARY_NAME'):
                if var in os.environ:
                    del os.environ[var]
            environment.update({
                'VK_ICD_FILENAMES': '/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json',
                'VK_LAYER_PATH': '/usr/share/vulkan/explicit_layer.d',
            })

        return Command.Command(array=commandArray, env=environment)

    def getMouseMode(self, config, rom):
        return True
