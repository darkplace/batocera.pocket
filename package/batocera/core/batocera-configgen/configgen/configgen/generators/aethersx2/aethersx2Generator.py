from __future__ import annotations

import time
from pathlib import Path
from typing import Final

from ..Generator import Generator
from ... import Command
from ...batoceraPaths import BIOS, SAVES, ensure_parents_and_open
from ...utils.configparser import CaseSensitiveConfigParser

_AETHERSX2_CONFIG: Final = Path("/userdata/system/.config/aethersx2")
_AETHERSX2_INI: Final = _AETHERSX2_CONFIG / "inis" / "PCSX2.ini"
_AETHERSX2_REG: Final = _AETHERSX2_CONFIG / "PCSX2-reg.ini"
_AETHERSX2_BIN: Final = Path("/usr/bin/aethersx2")


def _prepare_aethersx2_layout() -> None:
    for path in (
        _AETHERSX2_CONFIG / "bios",
        _AETHERSX2_CONFIG / "cache",
        _AETHERSX2_CONFIG / "cheats",
        _AETHERSX2_CONFIG / "cheats_ni",
        _AETHERSX2_CONFIG / "cheats_ws",
        _AETHERSX2_CONFIG / "covers",
        _AETHERSX2_CONFIG / "gamesettings",
        _AETHERSX2_CONFIG / "inis",
        _AETHERSX2_CONFIG / "inputprofiles",
        _AETHERSX2_CONFIG / "logs",
        _AETHERSX2_CONFIG / "memcards",
        _AETHERSX2_CONFIG / "snaps",
        _AETHERSX2_CONFIG / "sstates",
        _AETHERSX2_CONFIG / "textures",
        _AETHERSX2_CONFIG / "videos",
    ):
        path.mkdir(parents=True, exist_ok=True)

    with ensure_parents_and_open(_AETHERSX2_REG, "w") as f:
        f.write("DocumentsFolderMode=User\n")
        f.write(f"CustomDocumentsFolder={_AETHERSX2_CONFIG}\n")
        f.write("UseDefaultSettingsFolder=enabled\n")
        f.write(f"SettingsFolder={_AETHERSX2_CONFIG / 'inis'}\n")
        f.write(f"Install_Dir={_AETHERSX2_CONFIG}\n")
        f.write("RunWizard=0\n")


class AetherSX2Generator(Generator):

    def getHotkeysContext(self):
        return {
            "name": "aethersx2",
            "keys": {"exit": ["KEY_LEFTALT", "KEY_F4"]},
        }

    # AetherSX2 crashes if MangoHUD is injected
    def hasInternalMangoHUDCall(self):
        return True

    # Critical: allow emulator to receive raw input
    def getInGameSettings(self, system, rom):
        return {
            "nograb": True
        }

    def generate(self, system, rom, controllers, metadata, guns, wheels, gameResolution):
        _prepare_aethersx2_layout()

        ini = CaseSensitiveConfigParser(interpolation=None)
        if _AETHERSX2_INI.exists():
            ini.read(_AETHERSX2_INI)

        for section in (
            "UI",
            "EmuCore",
            "EmuCore/GS",
            "EmuCore/Speedhacks",
            "EmuCore/Gamefixes",
            "SPU2/Mixing",
            "SPU2/Output",
            "Folders",
            "Filenames",
            "MemoryCards",
            "Logging",
            "InputSources",
            "Hotkeys",
            "Pad",
            "Achievements",
            "USB1",
            "USB2",
        ):
            if not ini.has_section(section):
                ini.add_section(section)

        for nplayer in range(1, 9):
            section = f"Pad{nplayer}"
            if not ini.has_section(section):
                ini.add_section(section)

        ini.set("UI", "ConfirmShutdown", "false")
        ini.set("UI", "InhibitScreensaver", "true")
        ini.set("UI", "StartPaused", "false")
        ini.set("UI", "PauseOnFocusLoss", "false")
        ini.set("UI", "StartFullscreen", "true")
        ini.set("UI", "HideMouseCursor", "true")
        ini.set("UI", "RenderToSeparateWindow", "false")
        ini.set("UI", "HideMainWindowWhenRunning", "true")
        ini.set("UI", "DoubleClickTogglesFullscreen", "false")

        ini.set("EmuCore/GS", "Renderer",
                system.config.get_str("aethersx2_renderer", "-1"))
        ini.set("EmuCore/GS", "upscale_multiplier",
                system.config.get_str("aethersx2_resolution", "1"))
        ini.set("EmuCore/GS", "MaxAnisotropy",
                system.config.get_str("aethersx2_anisotropic", "0"))
        ini.set("EmuCore/GS", "fxaa",
                system.config.get_bool("aethersx2_fxaa",
                                       return_values=("true", "false")))
        ini.set("EmuCore/GS", "mipmap_hw",
                system.config.get_str("aethersx2_mipmapping", "-1"))
        ini.set("EmuCore/GS", "TriFilter",
                system.config.get_str("aethersx2_trilinear_filtering", "-1"))
        ini.set("EmuCore/GS", "texture_preloading",
                system.config.get_str("aethersx2_texture_preload", "2"))
        ini.set("EmuCore/GS", "accurate_blending_unit",
                system.config.get_str("aethersx2_blending", "1"))
        ini.set("EmuCore/GS", "AspectRatio",
                system.config.get_str("aethersx2_aspect_ratio", "4:3"))
        ini.set("EmuCore/GS", "FMVAspectRatioSwitch",
                system.config.get_str("aethersx2_fmv_ratio", "off"))
        ini.set("EmuCore/GS", "filter",
                system.config.get_str("aethersx2_bilinear", "2"))
        ini.set("EmuCore/GS", "linear_present_mode",
                system.config.get_str("aethersx2_bilinear_filtering", "1"))
        ini.set("EmuCore/GS", "VsyncEnable",
                system.config.get_str("aethersx2_vsync", "0"))
        ini.set("EmuCore/GS", "deinterlace_mode",
                system.config.get_str("aethersx2_deinterlace", "0"))
        ini.set("EmuCore/GS", "dithering_ps2",
                system.config.get_str("aethersx2_dithering", "2"))
        ini.set("EmuCore/GS", "IntegerScaling",
                system.config.get_bool("aethersx2_integer_scaling",
                                       return_values=("true", "false")))
        ini.set("EmuCore/GS", "pcrtc_antiblur",
                system.config.get_bool("aethersx2_antiblur", True,
                                       return_values=("true", "false")))
        ini.set("EmuCore/GS", "LoadTextureReplacements",
                system.config.get_bool("aethersx2_texture_replacements",
                                       return_values=("true", "false")))
        ini.set("EmuCore/GS", "OsdShowMessages",
                system.config.get_bool("aethersx2_osd_messages", True,
                                       return_values=("true", "false")))
        ini.set("EmuCore/GS", "OsdMessagesPos",
                system.config.get_str("aethersx2_osd_messages_position", "2"))
        ini.set("EmuCore/GS", "OsdPerformancePos",
                system.config.get_str("aethersx2_osd_performance_position", "0"))
        ini.set("EmuCore/GS", "OsdShowFPS",
                system.config.get_bool("aethersx2_show_fps",
                                       return_values=("true", "false")))
        ini.set("EmuCore/GS", "HWDownloadMode",
                system.config.get_str("aethersx2_hw_download", "0"))

        ini.set("EmuCore/Speedhacks", "EECycleRate",
                system.config.get_str("aethersx2_ee_cycle_rate", "0"))
        ini.set("EmuCore/Speedhacks", "EECycleSkip",
                system.config.get_str("aethersx2_ee_cycle_skip", "0"))
        ini.set("EmuCore/Speedhacks", "vuThread",
                system.config.get_bool("aethersx2_mtvu", True,
                                       return_values=("true", "false")))
        ini.set("EmuCore/Speedhacks", "vu1Instant",
                system.config.get_bool("aethersx2_instant_vu1", True,
                                       return_values=("true", "false")))
        ini.set("EmuCore/Speedhacks", "fastCDVD",
                system.config.get_bool("aethersx2_fast_cdvd",
                                       return_values=("true", "false")))

        ini.set("EmuCore", "EnableFastBoot",
                system.config.get_bool("aethersx2_fastboot", True,
                                       return_values=("true", "false")))
        ini.set("EmuCore", "EnableWideScreenPatches",
                system.config.get_bool("aethersx2_widescreen",
                                       return_values=("true", "false")))
        ini.set("EmuCore", "EnableNoInterlacingPatches",
                system.config.get_bool("aethersx2_nointerlace_patches",
                                       return_values=("true", "false")))
        ini.set("EmuCore", "EnableCheats",
                system.config.get_bool("aethersx2_cheats",
                                       return_values=("true", "false")))
        ini.set("EmuCore", "EnableGameFixes",
                system.config.get_bool("aethersx2_game_fixes", True,
                                       return_values=("true", "false")))
        ini.set("EmuCore", "AutoIncrementSlot",
                system.config.get_bool("incrementalsavestates", True,
                                       return_values=("true", "false")))
        ini.set("EmuCore", "SaveStateOnShutdown",
                system.config.get_bool("autosave",
                                       return_values=("true", "false")))

        ini.set("SPU2/Mixing", "Interpolation",
                system.config.get_str("aethersx2_audio_interpolation", "5"))
        ini.set("SPU2/Output", "Latency",
                system.config.get_str("aethersx2_audio_latency", "100"))

        ini.set("Achievements", "Enabled", "false")
        ini.set("Achievements", "Notifications", "true")
        ini.set("Achievements", "SoundEffects", "true")
        if system.config.get_bool("retroachievements"):
            ini.set("Achievements", "Enabled", "true")
            ini.set("Achievements", "Username",
                    system.config.get_str("retroachievements.username", ""))
            ini.set("Achievements", "Token",
                    system.config.get_str("retroachievements.token", ""))
            ini.set("Achievements", "LoginTimestamp", str(int(time.time())))
            ini.set("Achievements", "ChallengeMode",
                    system.config.get_bool("retroachievements.hardcore",
                                           return_values=("true", "false")))
            ini.set("Achievements", "PrimedIndicators",
                    system.config.get_bool("retroachievements.challenge_indicators",
                                           return_values=("true", "false")))
            ini.set("Achievements", "RichPresence",
                    system.config.get_bool("retroachievements.richpresence",
                                           return_values=("true", "false")))
            ini.set("Achievements", "Leaderboards",
                    system.config.get_bool("retroachievements.leaderboards",
                                           return_values=("true", "false")))
            ini.set("Achievements", "EncoreMode",
                    system.config.get_bool("retroachievements.encore",
                                           return_values=("true", "false")))
            ini.set("Achievements", "UnofficialTestMode",
                    system.config.get_bool("retroachievements.unofficial",
                                           return_values=("true", "false")))
        ini.set("Achievements", "TestMode", "false")

        ini.set("Folders", "Bios", str(BIOS / "ps2"))
        ini.set("Folders", "Savestates", str(SAVES / "ps2"))
        ini.set("Folders", "MemoryCards", str(SAVES / "ps2"))
        ini.set("Folders", "Snapshots", "snaps")
        ini.set("Folders", "Cheats", "cheats")
        ini.set("Folders", "CheatsWS", "cheats_ws")
        ini.set("Folders", "CheatsNI", "cheats_ni")
        ini.set("Folders", "Cache", "cache")
        ini.set("Folders", "Textures", "textures")
        ini.set("Folders", "InputProfiles", "inputprofiles")
        ini.set("Folders", "Logs", "logs")
        ini.set("Folders", "Videos", "videos")

        if bios_name := _get_aethersx2_bios_name():
            ini.set("Filenames", "BIOS", bios_name)

        ini.set("MemoryCards", "Slot1_Enable", "true")
        ini.set("MemoryCards", "Slot1_Filename", "Mcd001.ps2")
        ini.set("MemoryCards", "Slot2_Enable", "true")
        ini.set("MemoryCards", "Slot2_Filename", "Mcd002.ps2")
        ini.set("MemoryCards", "Multitap1_Slot2_Enable", "false")
        ini.set("MemoryCards", "Multitap1_Slot2_Filename", "Mcd-Multitap1-Slot02.ps2")
        ini.set("MemoryCards", "Multitap1_Slot3_Enable", "false")
        ini.set("MemoryCards", "Multitap1_Slot3_Filename", "Mcd-Multitap1-Slot03.ps2")
        ini.set("MemoryCards", "Multitap1_Slot4_Enable", "false")
        ini.set("MemoryCards", "Multitap1_Slot4_Filename", "Mcd-Multitap1-Slot04.ps2")
        ini.set("MemoryCards", "Multitap2_Slot2_Enable", "false")
        ini.set("MemoryCards", "Multitap2_Slot2_Filename", "Mcd-Multitap2-Slot02.ps2")
        ini.set("MemoryCards", "Multitap2_Slot3_Enable", "false")
        ini.set("MemoryCards", "Multitap2_Slot3_Filename", "Mcd-Multitap2-Slot03.ps2")
        ini.set("MemoryCards", "Multitap2_Slot4_Enable", "false")
        ini.set("MemoryCards", "Multitap2_Slot4_Filename", "Mcd-Multitap2-Slot04.ps2")

        ini.set("Logging", "EnableSystemConsole", "false")
        ini.set("Logging", "EnableFileLogging", "false")
        ini.set("Logging", "EnableTimestamps", "true")
        ini.set("Logging", "EnableVerbose", "false")
        ini.set("Logging", "EnableEEConsole", "false")
        ini.set("Logging", "EnableIOPConsole", "false")
        ini.set("Logging", "EnableInputRecordingLogs", "true")
        ini.set("Logging", "EnableControllerLogs", "false")

        ini.set("InputSources", "Keyboard", "true")
        ini.set("InputSources", "Mouse", "true")
        ini.set("InputSources", "Sensor", "false")
        ini.set("InputSources", "SDL", "true")
        ini.set("InputSources", "SDLControllerEnhancedMode", "false")

        ini.set("Hotkeys", "ToggleFullscreen", "Keyboard/Alt & Keyboard/Return")
        ini.set("Hotkeys", "CycleAspectRatio", "Keyboard/F6")
        ini.set("Hotkeys", "CycleInterlaceMode", "Keyboard/F5")
        ini.set("Hotkeys", "CycleMipmapMode", "Keyboard/Insert")
        ini.set("Hotkeys", "GSDumpMultiFrame", "Keyboard/Control & Keyboard/Shift & Keyboard/F8")
        ini.set("Hotkeys", "Screenshot", "Keyboard/F8")
        ini.set("Hotkeys", "GSDumpSingleFrame", "Keyboard/Shift & Keyboard/F8")
        ini.set("Hotkeys", "ToggleSoftwareRendering", "Keyboard/F9")
        ini.set("Hotkeys", "ZoomIn", "Keyboard/Control & Keyboard/Plus")
        ini.set("Hotkeys", "ZoomOut", "Keyboard/Control & Keyboard/Minus")
        ini.set("Hotkeys", "InputRecToggleMode", "Keyboard/Shift & Keyboard/R")
        ini.set("Hotkeys", "LoadStateFromSlot", "Keyboard/F3")
        ini.set("Hotkeys", "SaveStateToSlot", "Keyboard/F1")
        ini.set("Hotkeys", "NextSaveStateSlot", "Keyboard/F2")
        ini.set("Hotkeys", "PreviousSaveStateSlot", "Keyboard/Shift & Keyboard/F2")
        ini.set("Hotkeys", "OpenPauseMenu", "Keyboard/Escape")
        ini.set("Hotkeys", "ToggleFrameLimit", "Keyboard/F4")
        ini.set("Hotkeys", "TogglePause", "Keyboard/Space")
        ini.set("Hotkeys", "ToggleSlowMotion", "Keyboard/Shift & Keyboard/Backtab")
        ini.set("Hotkeys", "ToggleTurbo", "Keyboard/Tab")
        ini.set("Hotkeys", "HoldTurbo", "Keyboard/Period")

        ini.set("Pad", "MultitapPort1", "false")
        ini.set("Pad", "MultitapPort2", "false")
        ini.set("Pad", "PointerXScale", "8")
        ini.set("Pad", "PointerYScale", "8")

        multitap = 2
        joystick_count = len(controllers)
        multitap_config = system.config.get_str("aethersx2_multitap")
        if multitap_config == "4":
            if joystick_count > 2:
                ini.set("Pad", "MultitapPort1", "true")
                multitap = 4
        elif multitap_config == "8":
            if joystick_count > 4:
                ini.set("Pad", "MultitapPort1", "true")
                ini.set("Pad", "MultitapPort2", "true")
                multitap = 8
            elif joystick_count > 2:
                ini.set("Pad", "MultitapPort1", "true")
                multitap = 4

        ini.set("USB1", "Type", "None")
        ini.set("USB2", "Type", "None")

        configured_pads = set()
        for nplayer, pad in enumerate(controllers, start=1):
            if nplayer > multitap:
                break

            pad_index = nplayer
            if multitap == 4 and pad.index != 0:
                pad_index = nplayer + 1

            section = f"Pad{pad_index}"
            configured_pads.add(pad_index)
            sdl_num = f"SDL-{pad.index}"

            ini.set(section, "Type", "DualShock2")
            ini.set(section, "InvertL", "0")
            ini.set(section, "InvertR", "0")
            ini.set(section, "Deadzone", "0")
            ini.set(section, "AxisScale", "1.33")
            ini.set(section, "TriggerDeadzone", "0.10")
            ini.set(section, "TriggerScale", "1")
            ini.set(section, "LargeMotorScale", "1")
            ini.set(section, "SmallMotorScale", "1")
            ini.set(section, "ButtonDeadzone", "0.10")
            ini.set(section, "PressureModifier", "0.5")
            ini.set(section, "Up", sdl_num + "/DPadUp")
            ini.set(section, "Right", sdl_num + "/DPadRight")
            ini.set(section, "Down", sdl_num + "/DPadDown")
            ini.set(section, "Left", sdl_num + "/DPadLeft")
            ini.set(section, "Triangle", sdl_num + "/Y")
            ini.set(section, "Circle", sdl_num + "/B")
            ini.set(section, "Cross", sdl_num + "/A")
            ini.set(section, "Square", sdl_num + "/X")
            ini.set(section, "Select", sdl_num + "/Back")
            ini.set(section, "Start", sdl_num + "/Start")
            ini.set(section, "L1", sdl_num + "/LeftShoulder")
            ini.set(section, "L2", sdl_num + "/+LeftTrigger")
            ini.set(section, "R1", sdl_num + "/RightShoulder")
            ini.set(section, "R2", sdl_num + "/+RightTrigger")
            ini.set(section, "L3", sdl_num + "/LeftStick")
            ini.set(section, "R3", sdl_num + "/RightStick")
            ini.set(section, "LUp", sdl_num + "/-LeftY")
            ini.set(section, "LRight", sdl_num + "/+LeftX")
            ini.set(section, "LDown", sdl_num + "/+LeftY")
            ini.set(section, "LLeft", sdl_num + "/-LeftX")
            ini.set(section, "RUp", sdl_num + "/-RightY")
            ini.set(section, "RRight", sdl_num + "/+RightX")
            ini.set(section, "RDown", sdl_num + "/+RightY")
            ini.set(section, "RLeft", sdl_num + "/-RightX")
            ini.set(section, "LargeMotor", sdl_num + "/LargeMotor")
            ini.set(section, "SmallMotor", sdl_num + "/SmallMotor")

        for nplayer in range(1, 9):
            if nplayer not in configured_pads:
                ini.set(f"Pad{nplayer}", "Type", "None")

        with ensure_parents_and_open(_AETHERSX2_INI, "w") as f:
            ini.write(f)

        return Command.Command(
            array=[str(_AETHERSX2_BIN), "-batch", "-fullscreen", str(rom)],
            env={
                "XDG_CONFIG_HOME": "/userdata/system/.config",
                "DISABLE_LSFG": "1",
            },
        )


def _get_aethersx2_bios_name() -> str | None:
    from ...utils.ps2Bios import select_ps2_bios_filename

    return select_ps2_bios_filename(BIOS / "ps2")
