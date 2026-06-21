from __future__ import annotations

import platform
import shlex
from typing import TYPE_CHECKING

from ... import Command
from ...utils import lsfg
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


def _parse_steam_rom_entry(content: str) -> dict[str, str]:
    entry: dict[str, str] = {}
    raw = content.strip()
    if not raw:
        return entry

    # Backward compatibility: plain numeric appid in file.
    if "=" not in raw and raw.isdigit():
        entry["appid"] = raw
        return entry
    if "=" not in raw and raw.startswith("steam://rungameid/"):
        appid = raw.removeprefix("steam://rungameid/").strip()
        if appid.isdigit():
            entry["appid"] = appid
            return entry

    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        if line.startswith("steam://rungameid/"):
            appid = line.removeprefix("steam://rungameid/").strip()
            if appid.isdigit():
                entry["appid"] = appid
            continue

        if line.lower().startswith("appid:"):
            appid = line.split(":", 1)[1].strip()
            if appid.isdigit():
                entry["appid"] = appid
            continue

        if "=" not in line:
            parts = line.split()
            if len(parts) == 2 and parts[0].lower() == "appid" and parts[1].isdigit():
                entry["appid"] = parts[1]
            continue
        key, value = line.split("=", 1)
        key = key.strip().lower()
        value = value.strip()
        if key and value:
            entry[key] = value
    return entry


def _normalize_bool_override(value: str | None) -> str | None:
    if value is None:
        return None

    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return "1"
    if normalized in {"0", "false", "no", "off"}:
        return "0"
    return None


def _normalize_steam_mode(value: str | None) -> str | None:
    if value is None:
        return None

    normalized = value.strip().lower()
    if not normalized:
        return None

    if normalized in {"steamos", "gamescope", "gamemode"}:
        return "steamos"
    if normalized in {"gamepadui", "gamepad-ui"}:
        return "gamepadui"
    if normalized in {"desktop", "plasma"}:
        return "desktop"

    return None


def _normalize_steam_user(value: str | None) -> str:
    if value is None:
        return "auto"

    normalized = value.strip()
    if not normalized:
        return "auto"

    lowered = normalized.lower()
    if lowered in {"auto", "default", "current"}:
        return "auto"
    if lowered in {"prompt", "ask", "ask-each-time", "ask-every-time", "chooser", "choose"}:
        return "prompt"

    return normalized


def _normalize_hud_level(value: str | None) -> int | None:
    if value is None:
        return None

    normalized = value.strip()
    if not normalized:
        return None

    try:
        level = int(normalized)
    except ValueError:
        return None

    if 0 <= level <= 4:
        return level
    return None


def _append_unique_arg(value: str, arg: str) -> str:
    current = value.strip()
    if not current:
        return arg

    try:
        args = shlex.split(current)
    except ValueError:
        args = current.split()

    if arg in args:
        return current

    return f"{current} {arg}"


class SteamGenerator(Generator):

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        is_aarch64 = platform.machine() in {"aarch64", "arm64"}

        def _select_or_custom(key: str, custom_key: str) -> str:
            value = system.config.get_str(key, "").strip()
            if value == "custom":
                return system.config.get_str(custom_key, "").strip()
            return value

        def _positive_int(value: str) -> int | None:
            if not value or not value.isdigit():
                return None
            parsed = int(value)
            if parsed <= 0:
                return None
            return parsed

        basename = rom.name
        gameId = None
        command_override = None
        mode_override = None
        extra_args_override = None
        gamepadui_override = None
        gamescope_override = None
        visible_update_preflight_override = None
        update_preflight_no_update_secs_override = None
        steam_user_override = None
        if basename != "Steam.steam":
            # read the id inside the file
            with rom.open() as f:
                entry = _parse_steam_rom_entry(f.read())
            steam_uri = entry.get("steam_uri") or entry.get("uri") or entry.get("url")
            if steam_uri and steam_uri.startswith("steam://"):
                gameId = steam_uri
            else:
                gameId = entry.get("appid") or entry.get("gameid")
            mode_override = entry.get("mode")
            command_override = entry.get("command") or entry.get("exec")
            extra_args_override = entry.get("extra_args") or entry.get("args")
            gamepadui_override = entry.get("gamepadui")
            gamescope_override = entry.get("gamescope")
            visible_update_preflight_override = entry.get("visible_update_preflight") or entry.get("update_preflight")
            update_preflight_no_update_secs_override = entry.get("update_preflight_no_update_secs") or entry.get("preflight_no_update_secs")
            steam_user_override = entry.get("steam_user") or entry.get("user") or entry.get("account")

        if command_override:
            try:
                commandArray = shlex.split(command_override)
            except ValueError:
                commandArray = [command_override]
            if not commandArray:
                commandArray = ["batocera-steam"]
        elif gameId is None:
            commandArray = ["batocera-steam"]
        else:
            commandArray = ["batocera-steam", gameId]

        # Fix for Xbox Bluetooth controllers not working with Steam (issue #12731)
        # xpadneo fixes mappings at evdev level, but Steam reads raw HIDAPI data
        normalized_mode_override = _normalize_steam_mode(mode_override)
        normalized_core = _normalize_steam_mode(system.config.core)
        legacy_mode = _normalize_steam_mode(system.config.get_str("steam_session_mode", "steamos")) or "steamos"
        mode = normalized_mode_override or normalized_core or legacy_mode
        nested_refresh = system.config.get_int("gamescope_nested_refresh", -1)
        nested_unfocused_refresh_raw = _select_or_custom("gamescope_nested_unfocused_refresh", "gamescope_nested_unfocused_refresh_custom")
        nested_unfocused_refresh = _positive_int(nested_unfocused_refresh_raw)
        output_resolution = _select_or_custom("gamescope_output_resolution", "gamescope_output_resolution_custom")
        nested_resolution = _select_or_custom("gamescope_nested_resolution", "gamescope_nested_resolution_custom")
        xwayland_count_raw = _select_or_custom("gamescope_xwayland_count", "gamescope_xwayland_count_custom")
        xwayland_count = _positive_int(xwayland_count_raw)
        sharpness = _select_or_custom("gamescope_sharpness", "gamescope_sharpness_custom")
        framerate_limit_raw = _select_or_custom("gamescope_framerate_limit", "gamescope_framerate_limit_custom")
        framerate_limit = _positive_int(framerate_limit_raw)
        backend = system.config.get_str("gamescope_backend", "").strip()
        if backend not in {"auto", "drm", "wayland", "sdl", "headless"}:
            backend = ""
        steam_user = _normalize_steam_user(system.config.get_str("steam_user", "auto"))
        steam_gamepadui = system.config.get_bool("steam_gamepadui", True, return_values=("1", "0"))
        use_gamescope = system.config.get_bool("gamescope", True)
        default_mangoapp = False

        if normalized_mode_override is not None or normalized_core is not None:
            if mode == "desktop":
                steam_gamepadui = "0"
                use_gamescope = False
            elif mode == "gamepadui":
                steam_gamepadui = "1"
            else:
                steam_gamepadui = "1"
                use_gamescope = True

        normalized_gamepadui = _normalize_bool_override(gamepadui_override)
        if normalized_gamepadui is not None:
            steam_gamepadui = normalized_gamepadui

        normalized_gamescope = _normalize_bool_override(gamescope_override)
        if normalized_gamescope is not None and mode != "desktop":
            use_gamescope = normalized_gamescope == "1"

        if mode == "desktop":
            steam_gamepadui = "0"
            use_gamescope = False

        if is_aarch64 and mode != "steamos" and normalized_gamescope is None:
            use_gamescope = False

        if is_aarch64 and mode == "steamos" and use_gamescope and not command_override:
            commandArray = ["steam-direct-session.sh"]
            if gameId is not None:
                commandArray.append(gameId)

        default_visible_update_preflight = is_aarch64 and mode == "steamos" and use_gamescope
        steam_extra_args = extra_args_override if extra_args_override else system.config.get_str("steam_extra_args", "")
        if system.config.get_bool("steam_noshaders", False):
            steam_extra_args = _append_unique_arg(steam_extra_args, "-noshaders")
        hud_level = _normalize_hud_level(system.config.get_str("hud_level", ""))
        mangoapp_enabled = system.config.get_bool("gamescope_mangoapp", default_mangoapp)
        if hud_level is not None:
            mangoapp_enabled = hud_level > 0
        mangoapp_level = hud_level if hud_level is not None else (2 if mangoapp_enabled else 0)

        env = {
            "SDL_JOYSTICK_HIDAPI_XBOX": "0",
            "BATOCERA_STEAM_MODE": mode,
            "BATOCERA_STEAM_USE_GAMESCOPE": "1" if use_gamescope else "0",
            "BATOCERA_STEAM_GS_OUTPUT_RES": output_resolution,
            "BATOCERA_STEAM_GS_NESTED_RES": nested_resolution,
            "BATOCERA_STEAM_GS_BACKEND": backend,
            "BATOCERA_STEAM_GS_PREFER_VK_DEVICE": system.config.get_str("gamescope_prefer_vk_device", "").strip(),
            "BATOCERA_STEAM_GS_SCALER": system.config.get_str("gamescope_scaler", ""),
            "BATOCERA_STEAM_GS_FILTER": system.config.get_str("gamescope_filter", ""),
            "BATOCERA_STEAM_GS_SHARPNESS": sharpness,
            "BATOCERA_STEAM_GS_HDR": system.config.get_bool("gamescope_hdr", return_values=("1", "0")),
            "BATOCERA_STEAM_GS_ADAPTIVE_SYNC": system.config.get_bool("gamescope_adaptive_sync", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_DISABLE_DAMAGE_TRACKING": system.config.get_bool("gamescope_disable_damage_tracking", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_DISABLE_HW_COMPOSITION": system.config.get_bool("gamescope_disable_hw_composition", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_FORCE_COMPOSITION_PIPELINE": system.config.get_bool("gamescope_force_composition_pipeline", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_MANGOAPP": "1" if mangoapp_enabled else "0",
            "BATOCERA_STEAM_GS_MANGOAPP_LEVEL": str(mangoapp_level),
            "BATOCERA_STEAM_GS_FORCE_WINDOWS_FULLSCREEN": system.config.get_bool("gamescope_force_windows_fullscreen", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_IMMEDIATE_FLIPS": system.config.get_bool("gamescope_immediate_flips", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_DISABLE_COLOR_MANAGEMENT": system.config.get_bool("gamescope_disable_color_management", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_DISABLE_XRES": system.config.get_bool("gamescope_disable_xres", False, return_values=("1", "0")),
            "BATOCERA_STEAM_GS_STATS_PATH": system.config.get_str("gamescope_stats_path", "").strip(),
            "BATOCERA_STEAM_GAMEPADUI": steam_gamepadui,
            "BATOCERA_STEAM_EXTRA_ARGS": steam_extra_args,
            "BATOCERA_STEAM_UNSET_MESA_LOADER_DRIVER_OVERRIDE": system.config.get_bool("steam_unset_mesa_loader_driver_override", False, return_values=("1", "0")),
            "BATOCERA_STEAM_VISIBLE_UPDATE_PREFLIGHT": system.config.get_bool("steam_visible_update_preflight", default_visible_update_preflight, return_values=("1", "0")),
        }
        steam_user = _normalize_steam_user(steam_user_override) if steam_user_override is not None else steam_user
        if steam_user != "auto":
            env["BATOCERA_STEAM_USER"] = steam_user
        if system.config.get_bool("steam_proton_log", False):
            env["PROTON_LOG"] = "1"
            env["PROTON_LOG_DIR"] = "/userdata/system/logs"
        normalized_update_preflight = _normalize_bool_override(visible_update_preflight_override)
        if normalized_update_preflight is not None:
            env["BATOCERA_STEAM_VISIBLE_UPDATE_PREFLIGHT"] = normalized_update_preflight
        update_preflight_no_update_secs = _positive_int(update_preflight_no_update_secs_override or "")
        if update_preflight_no_update_secs is not None:
            env["BATOCERA_STEAM_PREFLIGHT_NO_UPDATE_SECS"] = str(update_preflight_no_update_secs)
        if nested_refresh > 0:
            env["BATOCERA_STEAM_GS_NESTED_REFRESH"] = str(nested_refresh)
        if nested_unfocused_refresh is not None:
            env["BATOCERA_STEAM_GS_NESTED_UNFOCUSED_REFRESH"] = str(nested_unfocused_refresh)
        if xwayland_count is not None:
            env["BATOCERA_STEAM_GS_XWAYLAND_COUNT"] = str(xwayland_count)
        if framerate_limit is not None:
            env["BATOCERA_STEAM_GS_FRAMERATE_LIMIT"] = str(framerate_limit)
        if gameResolution and "width" in gameResolution and "height" in gameResolution:
            env["BATOCERA_STEAM_GS_DEFAULT_RES"] = f"{gameResolution['width']}x{gameResolution['height']}"
        if not use_gamescope:
            env["BATOCERA_SKIP_GAMESCOPE"] = "1"
        if is_aarch64 and mode == "steamos" and use_gamescope:
            env["BATOCERA_SKIP_GAMESCOPE"] = "1"

        lsfg.apply_lsfg_vk(system, env, process_name="steam", use_wine_layer=True)

        return Command.Command(array=commandArray, env=env)

    def getMouseMode(self, config, rom):
        return True

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "steam",
            "keys": { "exit": ["KEY_LEFTALT", "KEY_F4"] }
        }
