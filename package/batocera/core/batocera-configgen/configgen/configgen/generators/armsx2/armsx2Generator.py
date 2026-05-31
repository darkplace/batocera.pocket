from __future__ import annotations

import shutil
import time
from pathlib import Path
from typing import Final

from ...batoceraPaths import BATOCERA_SHARE_DIR, BIOS, CACHE, CHEATS, CONFIGS, SAVES, SCREENSHOTS, ensure_parents_and_open
from ...utils.configparser import CaseSensitiveConfigParser
from ..aethersx2.aethersx2Generator import AetherSX2Generator

_AETHERSX2_INI: Final = Path("/userdata/system/.config/aethersx2/inis/PCSX2.ini")
_ARMSX2_CONFIG: Final = CONFIGS / "PCSX2"
_ARMSX2_INI: Final = _ARMSX2_CONFIG / "inis" / "PCSX2.ini"
_ACHIEVEMENT_SOUND_ROOT: Final = Path("/usr/share/libretro/assets/sounds")


def _is_sm8550() -> bool:
    try:
        return (BATOCERA_SHARE_DIR / "batocera.arch").read_text().strip() in ("sm8550", "sm8750")
    except OSError:
        return False


def _prepare_armsx2_layout() -> None:
    for path in (
        _ARMSX2_CONFIG / "cache",
        _ARMSX2_CONFIG / "covers",
        _ARMSX2_CONFIG / "gamesettings",
        _ARMSX2_CONFIG / "inis",
        _ARMSX2_CONFIG / "inputprofiles",
        _ARMSX2_CONFIG / "logs",
        _ARMSX2_CONFIG / "textures",
        BIOS / "ps2",
        CHEATS / "ps2",
        CHEATS / "ps2" / "cheats_ni",
        CHEATS / "ps2" / "cheats_ws",
        SAVES / "ps2" / "pcsx2",
        SAVES / "ps2" / "pcsx2" / "sstates",
        SAVES / "ps2" / "pcsx2" / "videos",
        SCREENSHOTS,
    ):
        path.mkdir(parents=True, exist_ok=True)


def _retroachievements_sound_path(system) -> str | None:
    sound = system.config.get("retroachievements.sound", "mario-1up")
    if _retroachievements_sound_disabled(sound):
        return None

    if "/" in sound:
        path = Path(sound)
        return str(path) if path.is_file() else None

    for suffix in (".ogg", ".wav"):
        path = _ACHIEVEMENT_SOUND_ROOT / f"{sound}{suffix}"
        if path.is_file():
            return str(path)

    return None


def _retroachievements_sound_disabled(sound: str) -> bool:
    return sound.lower() in ("", "0", "false", "none")


def _normalize_controller_bindings(ini: CaseSensitiveConfigParser) -> None:
    face_bindings = {
        "Triangle": "FaceNorth",
        "Circle": "FaceEast",
        "Cross": "FaceSouth",
        "Square": "FaceWest",
    }

    for nplayer in range(1, 9):
        section = f"Pad{nplayer}"
        if not ini.has_section(section):
            continue

        for button, face_name in face_bindings.items():
            value = ini.get(section, button, fallback="")
            if value.startswith("SDL-") and "/" in value:
                device = value.split("/", 1)[0]
                ini.set(section, button, f"{device}/{face_name}")


def _prepare_armsx2_settings(system) -> None:
    ini = CaseSensitiveConfigParser(interpolation=None)
    if _ARMSX2_INI.exists():
        ini.read(_ARMSX2_INI)

    for section in ("UI", "Achievements", "EmuCore/GS", "Folders", "Logging"):
        if not ini.has_section(section):
            ini.add_section(section)

    ini.set("UI", "SettingsVersion", "1")
    ini.set("UI", "SetupWizardIncomplete", "false")
    ini.set("UI", "Fullscreen", "true")
    ini.set("UI", "ConfirmShutdown", "false")
    ini.set("UI", "InhibitScreensaver", "true")
    ini.set("UI", "StartPaused", "false")
    ini.set("UI", "PauseOnFocusLoss", "false")
    ini.set("UI", "StartFullscreen", "true")
    ini.set("UI", "HideMouseCursor", "true")
    ini.set("UI", "RenderToSeparateWindow", "false")
    ini.set("UI", "HideMainWindowWhenRunning", "true")
    ini.set("UI", "DoubleClickTogglesFullscreen", "false")

    renderer = system.config.get("aethersx2_renderer", "-1")
    if renderer == "-1":
        renderer = "14" if _is_sm8550() else ini.get("EmuCore/GS", "Renderer", fallback="-1")
    if renderer == "-1":
        renderer = "14"
    ini.set("EmuCore/GS", "Renderer", renderer)
    ini.set("EmuCore/GS", "DisableFramebufferFetch", "false")
    ini.set("EmuCore/GS", "OverrideTextureBarriers", "-1")
    ini.set("EmuCore/GS", "DisableMailboxPresentation", "false")

    ini.set("Achievements", "Enabled", "false")
    ini.set("Achievements", "Notifications", "true")
    ini.set("Achievements", "LeaderboardNotifications", "true")
    sound_enabled = not _retroachievements_sound_disabled(
        system.config.get("retroachievements.sound", "mario-1up"))
    ini.set("Achievements", "SoundEffects", "true" if sound_enabled else "false")
    ini.set("Achievements", "InfoSound", "true")
    ini.set("Achievements", "UnlockSound", "true")
    ini.set("Achievements", "LBSubmitSound", "true")
    if sound_path := _retroachievements_sound_path(system):
        ini.set("Achievements", "InfoSoundName", sound_path)
        ini.set("Achievements", "UnlockSoundName", sound_path)
        ini.set("Achievements", "LBSubmitSoundName", sound_path)
    if system.config.get_bool("retroachievements"):
        ini.set("Achievements", "Enabled", "true")
        ini.set("Achievements", "Username",
                system.config.get("retroachievements.username", ""))
        ini.set("Achievements", "Token",
                system.config.get("retroachievements.token", ""))
        ini.set("Achievements", "LoginTimestamp", str(int(time.time())))
        challenge_indicators = system.config.get_bool("retroachievements.challenge_indicators",
                                                      return_values=("true", "false"))
        leaderboards = system.config.get_bool("retroachievements.leaderboards",
                                             return_values=("true", "false"))
        ini.set("Achievements", "ChallengeMode",
                system.config.get_bool("retroachievements.hardcore",
                                       return_values=("true", "false")))
        ini.set("Achievements", "PrimedIndicators", challenge_indicators)
        ini.set("Achievements", "Overlays", challenge_indicators)
        ini.set("Achievements", "RichPresence",
                system.config.get_bool("retroachievements.richpresence",
                                       return_values=("true", "false")))
        ini.set("Achievements", "Leaderboards", leaderboards)
        ini.set("Achievements", "LBOverlays", leaderboards)
        ini.set("Achievements", "EncoreMode",
                system.config.get_bool("retroachievements.encore",
                                       return_values=("true", "false")))
        ini.set("Achievements", "SpectatorMode", "false")
        ini.set("Achievements", "UnofficialTestMode",
                system.config.get_bool("retroachievements.unofficial",
                                       return_values=("true", "false")))
    ini.set("Achievements", "TestMode", "false")

    ini.set("Folders", "Bios", "../../../bios/ps2")
    ini.set("Folders", "Snapshots", "../../../screenshots")
    ini.set("Folders", "Savestates", "../../../saves/ps2/pcsx2/sstates")
    ini.set("Folders", "MemoryCards", "../../../saves/ps2/pcsx2")
    ini.set("Folders", "Logs", "../../logs")
    ini.set("Folders", "Cheats", "../../../cheats/ps2")
    ini.set("Folders", "CheatsWS", "../../../cheats/ps2/cheats_ws")
    ini.set("Folders", "CheatsNI", "../../../cheats/ps2/cheats_ni")
    ini.set("Folders", "Cache", "../../cache/ps2")
    ini.set("Folders", "Textures", "textures")
    ini.set("Folders", "InputProfiles", "inputprofiles")
    ini.set("Folders", "Videos", "../../../saves/ps2/pcsx2/videos")

    ini.set("Logging", "EnableSystemConsole", "false")
    ini.set("Logging", "EnableFileLogging", "false")

    _normalize_controller_bindings(ini)

    with ensure_parents_and_open(_ARMSX2_INI, "w") as f:
        ini.write(f)


class Armsx2Generator(AetherSX2Generator):

    def getHotkeysContext(self):
        context = super().getHotkeysContext()
        context["name"] = "armsx2"
        return context

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        command = super().generate(system, rom, playersControllers, metadata, guns, wheels, gameResolution)
        _prepare_armsx2_layout()
        if _AETHERSX2_INI.exists():
            shutil.copyfile(_AETHERSX2_INI, _ARMSX2_INI)
        _prepare_armsx2_settings(system)
        command.array = ["/usr/bin/start_armsx2.sh", str(Path(rom))]
        command.env["XDG_CONFIG_HOME"] = str(CONFIGS)
        command.env["XDG_DATA_HOME"] = "/userdata/system"
        command.env["XDG_CACHE_HOME"] = str(CACHE)
        command.env["DISABLE_MANGOHUD"] = "1"
        command.env["DISABLE_LSFG"] = "1"
        command.env["VK_LOADER_LAYERS_DISABLE"] = "~implicit~"
        return command
