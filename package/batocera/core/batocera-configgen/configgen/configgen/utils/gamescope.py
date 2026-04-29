from __future__ import annotations

import subprocess
from functools import lru_cache
from pathlib import Path
from typing import TYPE_CHECKING

from ..exceptions import BatoceraException

if TYPE_CHECKING:
    from ..Command import Command
    from ..Emulator import Emulator
    from ..types import Resolution


def _parse_resolution(raw: str) -> tuple[str, str] | None:
    width, _, height = raw.partition("x")
    width = width.strip()
    height = height.strip()
    if not width or not height:
        return None
    if not width.isdigit() or not height.isdigit():
        return None
    return width, height

def _parse_positive_int(raw: str) -> int | None:
    value = raw.strip()
    if not value:
        return None
    if not value.isdigit():
        return None
    parsed = int(value)
    if parsed <= 0:
        return None
    return parsed

def _get_select_or_custom(system: Emulator, key: str, custom_key: str) -> str:
    value = system.config.get_str(key, "").strip()
    if value == "custom":
        return system.config.get_str(custom_key, "").strip()
    return value


def _supports_gbm_platform() -> bool:
    eglinfo_bin = Path("/usr/bin/eglinfo")
    if not eglinfo_bin.exists():
        return False

    result = subprocess.run(
        [str(eglinfo_bin)],
        capture_output=True,
        text=True,
        check=False,
    )
    output = f"{result.stdout}\n{result.stderr}"
    return "EGL_KHR_platform_gbm" in output


@lru_cache(maxsize=1)
def _gamescope_supported_flags(gamescope_bin: str) -> set[str]:
    result = subprocess.run(
        [gamescope_bin, "--help"],
        capture_output=True,
        text=True,
        check=False,
    )
    output = f"{result.stdout}\n{result.stderr}"
    known_flags = {
        "--disable-damage-tracking",
        "--disable-hw-composition",
        "--disable-layers",
        "--adaptive-sync",
        "--force-composition-pipeline",
        "--force-composition",
        "--backend",
        "--xwayland-count",
        "--prefer-vk-device",
        "--framerate-limit",
        "--mangoapp",
        "--immediate-flips",
        "--force-windows-fullscreen",
        "--nested-unfocused-refresh",
        "--stats-path",
        "--disable-color-management",
        "--disable-xres",
    }
    return {flag for flag in known_flags if flag in output}


def _append_supported_flag(
    args: list[str],
    supported_flags: set[str],
    preferred: str,
    fallback: str | None = None,
) -> None:
    if preferred in supported_flags:
        args.append(preferred)
        return

    if fallback and fallback in supported_flags:
        args.append(fallback)


def _append_supported_option(
    args: list[str],
    supported_flags: set[str],
    option: str,
    value: str,
) -> None:
    if option in supported_flags:
        args.extend([option, value])


def add_gamescope_arguments(command: Command, system: Emulator, current_resolution: Resolution) -> None:
    skip_gamescope = command.env.get("BATOCERA_SKIP_GAMESCOPE")
    if skip_gamescope in {"1", "true", "TRUE", "True", "yes", "YES", "Yes", "on", "ON", "On"}:
        return

    steam_gamescope = command.env.get("BATOCERA_STEAM_USE_GAMESCOPE")
    if steam_gamescope in {"0", "false", "FALSE", "False", "no", "NO", "No", "off", "OFF", "Off"}:
        return

    if steam_gamescope not in {"1", "true", "TRUE", "True", "yes", "YES", "Yes", "on", "ON", "On"} and not system.config.get_bool("gamescope"):
        return

    gamescope_bin = Path("/usr/bin/gamescope")
    if not gamescope_bin.exists():
        raise BatoceraException("Gamescope is enabled but /usr/bin/gamescope is missing")

    if not _supports_gbm_platform():
        raise BatoceraException("Gamescope is enabled but EGL_KHR_platform_gbm is not available")

    args: list[str] = [
        str(gamescope_bin),
        "-f",
    ]
    supported_flags = _gamescope_supported_flags(str(gamescope_bin))

    if system.config.get_bool("gamescope_disable_damage_tracking", False):
        _append_supported_flag(args, supported_flags, "--disable-damage-tracking")

    if system.config.get_bool("gamescope_disable_hw_composition", False):
        _append_supported_flag(args, supported_flags, "--disable-hw-composition", "--disable-layers")

    if system.config.get_bool("gamescope_adaptive_sync", False):
        _append_supported_flag(args, supported_flags, "--adaptive-sync")

    if system.config.get_bool("gamescope_force_composition_pipeline"):
        _append_supported_flag(args, supported_flags, "--force-composition-pipeline", "--force-composition")

    backend = system.config.get_str("gamescope_backend", "").strip()
    if backend in {"auto", "drm", "wayland", "sdl", "headless"}:
        _append_supported_option(args, supported_flags, "--backend", backend)

    xwayland_count_value = _get_select_or_custom(system, "gamescope_xwayland_count", "gamescope_xwayland_count_custom")
    xwayland_count = _parse_positive_int(xwayland_count_value) if xwayland_count_value else None
    if xwayland_count is not None:
        _append_supported_option(args, supported_flags, "--xwayland-count", str(xwayland_count))

    prefer_vk_device = system.config.get_str("gamescope_prefer_vk_device", "").strip()
    if prefer_vk_device:
        _append_supported_option(args, supported_flags, "--prefer-vk-device", prefer_vk_device)

    if system.config.get_bool("gamescope_mangoapp", False):
        _append_supported_flag(args, supported_flags, "--mangoapp")

    if system.config.get_bool("gamescope_force_windows_fullscreen", False):
        _append_supported_flag(args, supported_flags, "--force-windows-fullscreen")

    output_resolution = _get_select_or_custom(system, "gamescope_output_resolution", "gamescope_output_resolution_custom")
    parsed_output = _parse_resolution(output_resolution) if output_resolution else None
    if parsed_output is None:
        out_w = str(current_resolution["width"])
        out_h = str(current_resolution["height"])
    else:
        out_w, out_h = parsed_output
    args.extend(["-W", out_w, "-H", out_h])

    nested_resolution = _get_select_or_custom(system, "gamescope_nested_resolution", "gamescope_nested_resolution_custom")
    parsed_nested = _parse_resolution(nested_resolution) if nested_resolution else None
    if parsed_nested is not None:
        nest_w, nest_h = parsed_nested
        args.extend(["-w", nest_w, "-h", nest_h])

    nested_refresh = system.config.get_int("gamescope_nested_refresh", -1)
    if nested_refresh > 0:
        args.extend(["-r", str(nested_refresh)])

    nested_unfocused_refresh_value = _get_select_or_custom(
        system,
        "gamescope_nested_unfocused_refresh",
        "gamescope_nested_unfocused_refresh_custom",
    )
    nested_unfocused_refresh = _parse_positive_int(nested_unfocused_refresh_value) if nested_unfocused_refresh_value else None
    if nested_unfocused_refresh is not None:
        _append_supported_option(args, supported_flags, "--nested-unfocused-refresh", str(nested_unfocused_refresh))

    framerate_limit_value = _get_select_or_custom(system, "gamescope_framerate_limit", "gamescope_framerate_limit_custom")
    framerate_limit = _parse_positive_int(framerate_limit_value) if framerate_limit_value else None
    if framerate_limit is not None:
        args.extend(["--framerate-limit", str(framerate_limit)])

    scaler = system.config.get_str("gamescope_scaler", "")
    if scaler:
        args.extend(["-S", scaler])

    upscaler_filter = system.config.get_str("gamescope_filter", "")
    if upscaler_filter:
        args.extend(["-F", upscaler_filter])

    sharpness = _get_select_or_custom(system, "gamescope_sharpness", "gamescope_sharpness_custom")
    if sharpness:
        args.extend(["--sharpness", sharpness])

    if system.config.get_bool("gamescope_hdr"):
        args.append("--hdr-enabled")

    stats_path = system.config.get_str("gamescope_stats_path", "").strip()
    if stats_path:
        _append_supported_option(args, supported_flags, "--stats-path", stats_path)

    if system.config.get_bool("gamescope_disable_color_management", False):
        _append_supported_flag(args, supported_flags, "--disable-color-management")

    if system.config.get_bool("gamescope_disable_xres", False):
        _append_supported_flag(args, supported_flags, "--disable-xres")

    if system.config.get_bool("gamescope_immediate_flips", False):
        _append_supported_flag(args, supported_flags, "--immediate-flips")

    args.append("--")
    command.array = args + command.array
