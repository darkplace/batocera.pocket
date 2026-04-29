from __future__ import annotations

import os
import shlex
from typing import TYPE_CHECKING

from ... import Command
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


class FlatpakGenerator(Generator):

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):

        romId = None
        with rom.open() as f:
            romId = str.strip(f.read())
        # Be tolerant of stale parser output like "app.id --" and only keep the app ID.
        if romId:
            romId = romId.split()[0]

        # bad hack in a first time to get audio for user batocera
        os.system('chown -R root:audio /var/run/pulse')
        os.system('chmod -R g+rwX /var/run/pulse')

        # the directory monitor must exist and all the dirs must be owned by batocera
        commandArray = ["/usr/bin/flatpak", "run", "-v"]
        if system.config.get_bool("flatpak_fs_userdata", True):
            commandArray.append("--filesystem=/userdata")
        if system.config.get_bool("flatpak_fs_media", True):
            commandArray.append("--filesystem=/media")

        # Common runtime toggles
        if system.config.get_bool("flatpak_socket_session_bus"):
            commandArray.append("--socket=session-bus")
        if system.config.get_bool("flatpak_socket_system_bus"):
            commandArray.append("--socket=system-bus")
        if system.config.get_bool("flatpak_socket_pipewire"):
            commandArray.append("--socket=pipewire")
        if system.config.get_bool("flatpak_socket_pulseaudio"):
            commandArray.append("--socket=pulseaudio")

        if system.config.get_bool("flatpak_device_all"):
            commandArray.append("--device=all")
        if system.config.get_bool("flatpak_filesystem_run_udev_ro"):
            commandArray.append("--filesystem=/run/udev:ro")

        # Chromium / ozone / GPU flags
        ozone_platform = system.config.get_str("flatpak_ozone_platform", "")
        if ozone_platform in {"wayland", "x11"}:
            commandArray.append(f"--ozone-platform={ozone_platform}")

        enable_features: list[str] = []
        disable_features: list[str] = []

        ozone_feature = system.config.get_str("flatpak_use_ozone_platform_feature", "")
        if ozone_feature == "enable":
            enable_features.append("UseOzonePlatform")
        elif ozone_feature == "disable":
            disable_features.append("UseOzonePlatform")

        if system.config.get_bool("flatpak_enable_vaapi_video_decoder"):
            enable_features.append("VaapiVideoDecoder")

        if enable_features:
            commandArray.append(f"--enable-features={','.join(enable_features)}")
        if disable_features:
            commandArray.append(f"--disable-features={','.join(disable_features)}")

        if system.config.get_bool("flatpak_enable_accelerated_video_decode"):
            commandArray.append("--enable-accelerated-video-decode")

        if system.config.get_bool("flatpak_use_gl_egl"):
            commandArray.append("--use-gl=egl")

        use_angle = system.config.get_str("flatpak_use_angle", "")
        if use_angle in {"gl", "vulkan"}:
            commandArray.append(f"--use-angle={use_angle}")

        # Environment variables
        if system.config.get_bool("flatpak_env_desktop_session_flatpak"):
            commandArray.append("--env=DESKTOP_SESSION=flatpak")
        if system.config.get_bool("flatpak_env_xdg_current_desktop_gnome"):
            commandArray.append("--env=XDG_CURRENT_DESKTOP=GNOME")
        if system.config.get_bool("flatpak_env_xdg_session_type_wayland"):
            commandArray.append("--env=XDG_SESSION_TYPE=wayland")
        if system.config.get_bool("flatpak_env_sdl_video_wayland"):
            commandArray.append("--env=SDL_VIDEODRIVER=wayland")

        sdl_audio = system.config.get_str("flatpak_sdl_audio_driver", "")
        if sdl_audio in {"pipewire", "pulse"}:
            commandArray.append(f"--env=SDL_AUDIODRIVER={sdl_audio}")

        qt_qpa_platform = system.config.get_str("flatpak_qt_qpa_platform", "")
        if qt_qpa_platform in {"wayland", "xcb"}:
            commandArray.append(f"--env=QT_QPA_PLATFORM={qt_qpa_platform}")

        if system.config.get_bool("flatpak_qt_platformtheme_gtk3"):
            commandArray.append("--env=QT_QPA_PLATFORMTHEME=gtk3")
        if system.config.get_bool("flatpak_qt_wayland_disable_windowdecoration"):
            commandArray.append("--env=QT_WAYLAND_DISABLE_WINDOWDECORATION=1")

        if system.config.get_bool("flatpak_env_sdl_gamecontrollerconfig"):
            commandArray.append("--env=SDL_GAMECONTROLLERCONFIG=/userdata/system/gamecontrollerdb.txt")

        pipewire_latency = system.config.get_str("flatpak_pipewire_latency", "")
        if pipewire_latency:
            commandArray.append(f"--env=PIPEWIRE_LATENCY={pipewire_latency}")

        extra_run_args = system.config.get_str("flatpak_run_args", "")
        if extra_run_args:
            commandArray.extend(shlex.split(extra_run_args))

        commandArray.append(romId)
        if system.config.get_bool("flatpak_no_sandbox"):
            # Pass through to the app commandline explicitly.
            # Do not prepend "--" here: after app ID, flatpak already forwards
            # args to the app command, and an extra "--" becomes a literal app
            # argument, which breaks chromium's --no-sandbox handling.
            commandArray.append("--no-sandbox")

        # Prefer the session runtime dir from ES (Batocera often uses /var/run).
        # Falling back to /run/user/<uid> can break Wayland socket discovery.
        xdg_runtime_dir = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
        os.makedirs(xdg_runtime_dir, mode=0o700, exist_ok=True)
        env = {
            "SDL_JOYSTICK_HIDAPI_XBOX": "0",
            "XDG_RUNTIME_DIR": xdg_runtime_dir,
        }

        return Command.Command(array=["/usr/bin/dbus-run-session", "--", *commandArray], env=env)

    def getMouseMode(self, config, rom):
        return True

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "flatpak",
            "keys": { "exit": "flatpak kill $(flatpak ps --columns=application | head -n 1)" }
        }
