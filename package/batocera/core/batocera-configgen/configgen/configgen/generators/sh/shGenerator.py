from __future__ import annotations

import json
import logging
import os
from pathlib import Path
import re
import subprocess
from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import BATOCERA_SHARE_DIR
from ...controller import generate_sdl_game_controller_config, write_sdl_controller_db
from ...utils import lsfg
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext

_logger = logging.getLogger(__name__)


def _is_sm8550() -> bool:
    try:
        return (BATOCERA_SHARE_DIR / "batocera.arch").read_text().strip() in ("sm8550", "sm8750")
    except OSError:
        return False


def _is_aarch64() -> bool:
    return os.uname().machine in {"aarch64", "arm64"}


def _apply_ports_translator(config) -> None:
    """Ensure Box64 and FEX binfmt handlers are mutually exclusive for ports."""
    if not _is_aarch64():
        return
    mode = config.get_str("ports_translator", "box64").strip().lower()
    if mode not in {"box64", "fex"}:
        mode = "box64"
    helper = Path("/usr/bin/batocera-ports-translator")
    if not helper.is_file():
        _logger.warning("batocera-ports-translator missing; skipping binfmt switch")
        return
    try:
        subprocess.run([str(helper), mode], check=False, timeout=20)
    except (OSError, subprocess.TimeoutExpired) as exc:
        _logger.warning("ports translator switch failed (%s): %s", mode, exc)


def _is_portmaster_launcher(path) -> bool:
    return "portmaster" in path.name.lower()


def _patch_portmaster_batocera_device_profile() -> None:
    hardware_py = Path("/userdata/system/.local/share/PortMaster/pylibs/harbourmaster/hardware.py")
    try:
        hardware = hardware_py.read_text()
    except OSError:
        return

    old = """    # Works on Batocera
    batocera_version = safe_cat('/usr/share/batocera/batocera.version')
    if batocera_version != '':
        info.setdefault('name', 'Batocera')
        info['version'] = subprocess.getoutput('batocera-version').strip().split(' ', 1)[0]
        info['device'] = safe_cat('/boot/boot/batocera.board').strip()
"""
    new = """    # Works on Batocera
    batocera_version = safe_cat('/usr/share/batocera/batocera.version')
    if batocera_version != '':
        info.setdefault('name', 'Batocera')
        info['version'] = subprocess.getoutput('batocera-version').strip().split(' ', 1)[0]

        batocera_device = safe_cat('/boot/boot/batocera.board').strip()
        # Batocera board names can be generic SoC families, such as sm8550.
        # Keep an earlier device-tree match when the board is not a PortMaster
        # hardware profile, otherwise PortMaster falls back to 640x480.
        if batocera_device in HW_INFO or info.get('device') in (None, '', 'default'):
            info['device'] = batocera_device
"""

    if old not in hardware or new in hardware:
        return

    try:
        backup = hardware_py.with_name(f"{hardware_py.name}.batocera-bak")
        if not backup.exists():
            backup.write_text(hardware)
        hardware_py.write_text(hardware.replace(old, new, 1))
    except OSError:
        return


class ShGenerator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "shell",
            "keys": { "exit": ["KEY_LEFTALT", "KEY_F4"] }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        # in case of squashfs, the root directory is passed
        runsh = rom / "run.sh"
        shrom = runsh if runsh.exists() else rom

        # PortMaster uses this. Its installer also greps for gamecontrollerdb.txt
        # before deciding whether to replace Batocera's shGenerator.py.
        write_sdl_controller_db(playersControllers)

        if system.name == "ports":
            _apply_ports_translator(system.config)

        commandArray = ["/bin/bash", shrom]
        sdl_controller_config = generate_sdl_game_controller_config(playersControllers)
        env = {
            "SDL_GAMECONTROLLERCONFIG": sdl_controller_config
        }
        is_appimage = rom.is_file() and rom.suffix.lower() == ".appimage"
        if system.name == "ports" and not is_appimage:
            env.update(self._ports_env(system.config))

        if is_appimage:
            app_id = self._appimage_id(rom.stem)
            metadata = self._appimage_metadata(rom)
            default_no_sandbox = "1" if metadata.get("no_sandbox") is True else "0"
            ports_env = self._ports_env(system.config, apps_compat=False)
            env.update(ports_env)
            commandArray = ["/usr/libexec/batocera-appimage-launcher", rom, app_id, default_no_sandbox]
            env.update({
                "BATOCERA_APPS_HOME": f"/userdata/saves/ports/{app_id}",
                "BATOCERA_APPIMAGE_NO_SANDBOX": ports_env["BATOCERA_PORTS_NO_SANDBOX"],
                "BATOCERA_APPIMAGE_EXTRA_ARGS": ports_env["BATOCERA_PORTS_EXTRA_ARGS"],
                "BATOCERA_APPIMAGE_LD_LIBRARY_PATHS": ports_env["BATOCERA_PORTS_LD_LIBRARY_PATHS"],
                "BATOCERA_APPIMAGE_EXTRACT_AND_RUN": system.config.get_str("ports_appimage_extract_and_run", ""),
                "BATOCERA_APPIMAGE_DISPLAY_BACKEND": ports_env["BATOCERA_PORTS_DISPLAY_BACKEND"],
                "BATOCERA_APPIMAGE_OZONE_PLATFORM": ports_env["BATOCERA_PORTS_OZONE_PLATFORM"],
                "BATOCERA_APPIMAGE_USE_OZONE_PLATFORM_FEATURE": ports_env["BATOCERA_PORTS_USE_OZONE_PLATFORM_FEATURE"],
                "BATOCERA_APPIMAGE_ENABLE_VAAPI_VIDEO_DECODER": ports_env["BATOCERA_PORTS_ENABLE_VAAPI_VIDEO_DECODER"],
                "BATOCERA_APPIMAGE_ENABLE_ACCELERATED_VIDEO_DECODE": ports_env["BATOCERA_PORTS_ENABLE_ACCELERATED_VIDEO_DECODE"],
                "BATOCERA_APPIMAGE_USE_GL_EGL": ports_env["BATOCERA_PORTS_USE_GL_EGL"],
                "BATOCERA_APPIMAGE_USE_ANGLE": ports_env["BATOCERA_PORTS_USE_ANGLE"],
                "BATOCERA_APPIMAGE_DESKTOP_SESSION_FLATPAK": ports_env["BATOCERA_PORTS_DESKTOP_SESSION_FLATPAK"],
                "BATOCERA_APPIMAGE_XDG_CURRENT_DESKTOP_GNOME": ports_env["BATOCERA_PORTS_XDG_CURRENT_DESKTOP_GNOME"],
                "BATOCERA_APPIMAGE_XDG_SESSION_TYPE": ports_env["BATOCERA_PORTS_XDG_SESSION_TYPE"],
                "BATOCERA_APPIMAGE_SDL_VIDEODRIVER": ports_env["BATOCERA_PORTS_SDL_VIDEODRIVER"],
                "BATOCERA_APPIMAGE_SDL_AUDIODRIVER": ports_env["BATOCERA_PORTS_SDL_AUDIODRIVER"],
                "BATOCERA_APPIMAGE_QT_QPA_PLATFORM": ports_env["BATOCERA_PORTS_QT_QPA_PLATFORM"],
                "BATOCERA_APPIMAGE_QT_PLATFORMTHEME_GTK3": ports_env["BATOCERA_PORTS_QT_PLATFORMTHEME_GTK3"],
                "BATOCERA_APPIMAGE_QT_WAYLAND_DISABLE_WINDOWDECORATION": ports_env["BATOCERA_PORTS_QT_WAYLAND_DISABLE_WINDOWDECORATION"],
                "BATOCERA_APPIMAGE_SDL_CONTROLLERDB": ports_env["BATOCERA_PORTS_SDL_CONTROLLERDB"],
                "BATOCERA_APPIMAGE_PIPEWIRE_LATENCY": ports_env["BATOCERA_PORTS_PIPEWIRE_LATENCY"],
            })
            return Command.Command(array=commandArray, env=env)

        if system.config.emulator == "heroic":
            env["BATOCERA_HEROIC_EXTRA_ARGS"] = system.config.get_str("heroic_extra_args", "")
            env["BATOCERA_HEROIC_MODE"] = system.config.core
            env["SDL_JOYSTICK_HIDAPI"] = "0"
            env["SDL_JOYSTICK_HIDAPI_XBOX"] = "0"
            env["SDL_JOYSTICK_RAWINPUT"] = "0"
            env["SDL_JOYSTICK_DIRECTINPUT"] = "0"
            env["SDL_DIRECTINPUT_ENABLED"] = "0"
            lsfg.apply_lsfg_vk(system, env, process_name="heroic")
        elif system.config.emulator == "lutris":
            env["BATOCERA_LUTRIS_EXTRA_ARGS"] = system.config.get_str("lutris_extra_args", "")
            env["BATOCERA_LUTRIS_MODE"] = system.config.core
            lsfg.apply_lsfg_vk(system, env, process_name="lutris")
        elif system.config.emulator == "n64recomp":
            env["BATOCERA_N64RECOMP_EXTRA_ARGS"] = system.config.get_str("n64recomp_extra_args", "")
        elif system.config.emulator == "apps":
            env["BATOCERA_APPS_EXTRA_ARGS"] = system.config.get_str("apps_extra_args", "")
            env["BATOCERA_APPS_NO_SANDBOX"] = system.config.get_bool("apps_no_sandbox", return_values=("1", "0"))

        if _is_sm8550() and _is_portmaster_launcher(shrom):
            _patch_portmaster_batocera_device_profile()
            env.update({
                "SDL_VIDEODRIVER": "wayland",
                "SDL_RENDER_VSYNC": "0",
                "DISABLE_MANGOHUD": "1",
                "DISABLE_LSFG": "1",
            })

        return Command.Command(array=commandArray, env=env)

    def getMouseMode(self, config, rom):
        return True

    @staticmethod
    def _appimage_id(stem: str) -> str:
        app_id = re.sub(r"[^A-Za-z0-9._-]+", "-", stem).strip("-._").lower()
        return app_id or "appimage"

    @staticmethod
    def _appimage_metadata(rom) -> dict:
        manifest = rom.parent / ".appimage-metadata.json"
        try:
            data = json.loads(manifest.read_text(encoding="utf-8"))
        except Exception:
            return {}

        if not isinstance(data, dict):
            return {}

        entry = data.get(rom.name, {})
        return entry if isinstance(entry, dict) else {}

    @classmethod
    def _ports_env(cls, config, *, apps_compat: bool = True) -> dict[str, str]:
        no_sandbox = cls._config_str(config, "ports_no_sandbox", "ports_appimage_no_sandbox")
        extra_args = cls._config_str(config, "ports_extra_args", "ports_appimage_extra_args")

        env = {
            "BATOCERA_PORTS_NO_SANDBOX": no_sandbox,
            "BATOCERA_PORTS_EXTRA_ARGS": extra_args,
            "BATOCERA_PORTS_LD_LIBRARY_PATHS": cls._config_str(config, "ports_ld_library_paths", "ports_appimage_ld_library_paths"),
            "BATOCERA_PORTS_DISPLAY_BACKEND": cls._config_str(config, "ports_display_backend", "ports_appimage_display_backend"),
            "BATOCERA_PORTS_OZONE_PLATFORM": cls._config_str(config, "ports_ozone_platform", "ports_appimage_ozone_platform"),
            "BATOCERA_PORTS_USE_OZONE_PLATFORM_FEATURE": cls._config_str(config, "ports_use_ozone_platform_feature", "ports_appimage_use_ozone_platform_feature"),
            "BATOCERA_PORTS_ENABLE_VAAPI_VIDEO_DECODER": cls._config_bool(config, "ports_enable_vaapi_video_decoder", "ports_appimage_enable_vaapi_video_decoder"),
            "BATOCERA_PORTS_ENABLE_ACCELERATED_VIDEO_DECODE": cls._config_bool(config, "ports_enable_accelerated_video_decode", "ports_appimage_enable_accelerated_video_decode"),
            "BATOCERA_PORTS_USE_GL_EGL": cls._config_bool(config, "ports_use_gl_egl", "ports_appimage_use_gl_egl"),
            "BATOCERA_PORTS_USE_ANGLE": cls._config_str(config, "ports_use_angle", "ports_appimage_use_angle"),
            "BATOCERA_PORTS_DESKTOP_SESSION_FLATPAK": cls._config_bool(config, "ports_env_desktop_session_flatpak", "ports_appimage_env_desktop_session_flatpak"),
            "BATOCERA_PORTS_XDG_CURRENT_DESKTOP_GNOME": cls._config_bool(config, "ports_env_xdg_current_desktop_gnome", "ports_appimage_env_xdg_current_desktop_gnome"),
            "BATOCERA_PORTS_XDG_SESSION_TYPE": cls._config_str(config, "ports_xdg_session_type", "ports_appimage_xdg_session_type"),
            "BATOCERA_PORTS_SDL_VIDEODRIVER": cls._config_str(config, "ports_sdl_video_driver", "ports_appimage_sdl_video_driver"),
            "BATOCERA_PORTS_SDL_AUDIODRIVER": cls._config_str(config, "ports_sdl_audio_driver", "ports_appimage_sdl_audio_driver"),
            "BATOCERA_PORTS_QT_QPA_PLATFORM": cls._config_str(config, "ports_qt_qpa_platform", "ports_appimage_qt_qpa_platform"),
            "BATOCERA_PORTS_QT_PLATFORMTHEME_GTK3": cls._config_bool(config, "ports_qt_platformtheme_gtk3", "ports_appimage_qt_platformtheme_gtk3"),
            "BATOCERA_PORTS_QT_WAYLAND_DISABLE_WINDOWDECORATION": cls._config_bool(config, "ports_qt_wayland_disable_windowdecoration", "ports_appimage_qt_wayland_disable_windowdecoration"),
            "BATOCERA_PORTS_SDL_CONTROLLERDB": cls._config_bool(config, "ports_env_sdl_gamecontrollerconfig", "ports_appimage_env_sdl_gamecontrollerconfig"),
            "BATOCERA_PORTS_PIPEWIRE_LATENCY": cls._config_str(config, "ports_pipewire_latency", "ports_appimage_pipewire_latency"),
        }
        if apps_compat:
            # Compatibility with existing app-oriented .sh launch helpers.
            env["BATOCERA_APPS_NO_SANDBOX"] = "1" if no_sandbox in {"1", "true", "on", "enabled"} else "0"
            env["BATOCERA_APPS_EXTRA_ARGS"] = extra_args
        return env

    @staticmethod
    def _config_str(config, *keys: str) -> str:
        for key in keys:
            value = config.get_str(key, config.MISSING)
            if value is not config.MISSING:
                return value
        return ""

    @staticmethod
    def _config_bool(config, *keys: str) -> str:
        for key in keys:
            value = config.get(key, config.MISSING)
            if value is config.MISSING:
                continue
            if isinstance(value, str):
                value = value.lower()
            return "1" if value in config.TRUE_VALUES else "0"
        return "0"
