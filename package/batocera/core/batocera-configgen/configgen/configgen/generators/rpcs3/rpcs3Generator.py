from __future__ import annotations

import logging
import re
import shutil
from typing import TYPE_CHECKING, Any, cast

from ruamel.yaml import YAML

from ... import Command
from ...batoceraPaths import BIOS, CACHE, CONFIGS, configure_emulator, mkdir_if_not_exists
from ...exceptions import BatoceraException
from ...utils import vulkan
from ...utils.configparser import CaseSensitiveConfigParser
from ..Generator import Generator
from . import rpcs3Controllers
from .rpcs3Paths import RPCS3_BIN, RPCS3_CONFIG, RPCS3_CONFIG_DIR, RPCS3_CURRENT_CONFIG

if TYPE_CHECKING:
    from pathlib import Path

    from ...types import HotkeysContext, Resolution

_logger = logging.getLogger(__name__)

def _cfg_get(system: Emulator, key: str, default: Any, *aliases: str) -> Any:
    missing = system.config.MISSING
    value = system.config.get(key, missing)
    if value is not missing:
        return value
    for alias in aliases:
        value = system.config.get(alias, missing)
        if value is not missing:
            return value
    return default

def _cfg_get_bool(system: Emulator, key: str, default: bool = False, *aliases: str) -> bool:
    missing = system.config.MISSING
    if system.config.get(key, missing) is not missing:
        return system.config.get_bool(key, default)
    for alias in aliases:
        if system.config.get(alias, missing) is not missing:
            return system.config.get_bool(alias, default)
    return default

def _cfg_get_int(system: Emulator, key: str, default: int, *aliases: str) -> int:
    missing = system.config.MISSING
    if system.config.get(key, missing) is not missing:
        return system.config.get_int(key, default)
    for alias in aliases:
        if system.config.get(alias, missing) is not missing:
            return system.config.get_int(alias, default)
    return default

class Rpcs3Generator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "rpcs3",
            "keys": { "exit": ["KEY_LEFTALT", "KEY_F4"] }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):

        rpcs3Controllers.generateControllerConfig(system, playersControllers, rom)

        # Taking care of the CurrentSettings.ini file
        mkdir_if_not_exists(RPCS3_CURRENT_CONFIG.parent)

        # Generates CurrentSettings.ini with values to disable prompts on first run

        rpcsCurrentSettings = CaseSensitiveConfigParser(interpolation=None)
        if RPCS3_CURRENT_CONFIG.exists():
            rpcsCurrentSettings.read(RPCS3_CURRENT_CONFIG)

        # Sets Gui Settings to close completely and disables some popups
        if not rpcsCurrentSettings.has_section("main_window"):
            rpcsCurrentSettings.add_section("main_window")

        rpcsCurrentSettings.set("main_window", "confirmationBoxExitGame", "false")
        rpcsCurrentSettings.set("main_window", "infoBoxEnabledInstallPUP","false")
        rpcsCurrentSettings.set("main_window", "infoBoxEnabledWelcome","false")
        rpcsCurrentSettings.set("main_window", "confirmationBoxBootGame", "false")
        rpcsCurrentSettings.set("main_window", "infoBoxEnabledInstallPKG", "false")

        if not rpcsCurrentSettings.has_section("Meta"):
            rpcsCurrentSettings.add_section("Meta")
        rpcsCurrentSettings.set("Meta", "checkUpdateStart", "false")
        rpcsCurrentSettings.set("Meta", "useRichPresence", "true" if system.config.get_bool("discord") else "false")

        if not rpcsCurrentSettings.has_section("GSFrame"):
            rpcsCurrentSettings.add_section("GSFrame")
        rpcsCurrentSettings.set("GSFrame", "disableMouse", "true")

        with RPCS3_CURRENT_CONFIG.open("w") as configfile:
            rpcsCurrentSettings.write(configfile)

        mkdir_if_not_exists(RPCS3_CONFIG.parent)

        # Generate a default config if it doesn't exist otherwise just open the existing
        rpcs3ymlconfig: dict[str, dict[str, Any]] = {}
        if RPCS3_CONFIG.is_file():
            with RPCS3_CONFIG.open("r") as stream:
                yaml = YAML(typ='safe', pure=True)
                rpcs3ymlconfig = cast('dict[str, dict[str, Any]]', yaml.load(stream) or {})

        # Add Nodes if not in the file
        if "Core" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Core"] = {}
        if "VFS" not in rpcs3ymlconfig:
            rpcs3ymlconfig["VFS"] = {}
        if "Video" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Video"] = {}
        if "Audio" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Audio"] = {}
        if "Input/Output" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Input/Output"] = {}
        if "System" not in rpcs3ymlconfig:
            rpcs3ymlconfig["System"] = {}
        if "Net" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Net"] = {}
        if "Savestate" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Savestate"] = {}
        if "Miscellaneous" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Miscellaneous"] = {}
        if "Log" not in rpcs3ymlconfig:
            rpcs3ymlconfig["Log"] = {}

        # -= [Core] =-
        # Set the PPU Decoder based on config
        rpcs3ymlconfig["Core"]["PPU Decoder"] = _cfg_get(system, "rpcs3_ppudecoder", "Recompiler (LLVM)", "ppudecoder")
        # Set the SPU Decoder based on config
        rpcs3ymlconfig["Core"]["SPU Decoder"] = _cfg_get(system, "rpcs3_spudecoder", "Recompiler (LLVM)", "spudecoder")
        # Set the SPU XFloat Accuracy based on config
        rpcs3ymlconfig["Core"]["XFloat Accuracy"] = _cfg_get(system, "rpcs3_spuxfloataccuracy", "Approximate", "rpcs3_xfloat", "xfloat")
        # Set the Default Core Values we need
        # Force to True for now to account for updates where exiting config file present.
        rpcs3ymlconfig["Core"]["SPU Cache"] = True
        # Preferred SPU Threads
        rpcs3ymlconfig["Core"]["Preferred SPU Threads"] = _cfg_get_int(system, "rpcs3_sputhreads", 0, "sputhreads")
        # SPU Loop Detection
        rpcs3ymlconfig["Core"]["SPU loop detection"] = _cfg_get_bool(system, "rpcs3_spuloopdetection", False, "spuloopdetect")
        # SPU Block Size
        rpcs3ymlconfig["Core"]["SPU Block Size"] = _cfg_get(system, "rpcs3_spublocksize", "Safe", "spublocksize")
        # Max Power Saving CPU-Preemptions
        rpcs3ymlconfig["Core"]["Max CPU Preempt Count"] = system.config.get_int("rpcs3_maxcpu_preemptcount", 0)
        # Sleep Timers Accuracy
        rpcs3ymlconfig["Core"]["Sleep Timers Accuracy"] = _cfg_get(system, "rpcs3_sleep_timers_accuracy", "As Host", "sleep_timers_accuracy")
        # RSX FIFO Accuracy
        rpcs3ymlconfig["Core"]["RSX FIFO Accuracy"] = _cfg_get(system, "rpcs3_rsxfifoaccuracy", "Fast", "rsxfifoaccuracy")

        # -= [Video] =-
        # gfx backend - default to Vulkan
        if vulkan.is_available():
            _logger.debug("Vulkan driver is available on the system.")
            if _cfg_get(system, "rpcs3_gfxbackend", "", "gfxbackend") == "OpenGL":
                _logger.debug("User selected OpenGL")
                rpcs3ymlconfig["Video"]["Renderer"] = "OpenGL"
            else:
                rpcs3ymlconfig["Video"]["Renderer"] = "Vulkan"

            if vulkan.has_discrete_gpu():
                _logger.debug("A discrete GPU is available on the system.")
                discrete_name = vulkan.get_discrete_gpu_name()
                if discrete_name:
                    _logger.debug("Using Discrete GPU Name: %s for RPCS3", discrete_name)
                    if "Vulkan" not in rpcs3ymlconfig["Video"]:
                        rpcs3ymlconfig["Video"]["Vulkan"] = {}
                    rpcs3ymlconfig["Video"]["Vulkan"]["Adapter"] = discrete_name
        else:
            _logger.debug("Vulkan driver is not available. Falling back to OpenGL")
            rpcs3ymlconfig["Video"]["Renderer"] = "OpenGL"

        # System aspect ratio
        rpcs3ymlconfig["Video"]["Aspect ratio"] = system.config.get("rpcs3_ratio") or Rpcs3Generator.getClosestRatio(gameResolution)
        
        # Shader compilation mode
        rpcs3ymlconfig["Video"]["Shader Mode"] = _cfg_get(system, "rpcs3_shadermode", "Async Shader Recompiler", "shadermode")
        
        # Shader quality
        rpcs3ymlconfig["Video"]["Shader Precision"] = _cfg_get(system, "rpcs3_shader", "High", "shader_quality")
        
        # Vsync
        rpcs3ymlconfig["Video"]["VSync"] = _cfg_get_bool(system, "rpcs3_vsync", False, "vsync")
        
        # Stretch to display area
        rpcs3ymlconfig["Video"]["Stretch To Display Area"] = _cfg_get_bool(system, "rpcs3_stretchdisplay", False, "stretchtodisplay")
        
        # Frame Limit
        match _cfg_get(system, "rpcs3_framelimit", system.config.MISSING, "framelimit"):
            case system.config.MISSING:
                rpcs3ymlconfig["Video"]["Frame limit"] = "Auto"
                rpcs3ymlconfig["Video"]["Second Frame Limit"] = 0
            case "Off" | "30" | "50" | "59.94" | "60" as framelimit:
                rpcs3ymlconfig["Video"]["Frame limit"] = framelimit
                rpcs3ymlconfig["Video"]["Second Frame Limit"] = 0
            case _ as framelimit:
                rpcs3ymlconfig["Video"]["Second Frame Limit"] = framelimit
                rpcs3ymlconfig["Video"]["Frame limit"] = "Off"
        
        # Write Color Buffers
        rpcs3ymlconfig["Video"]["Write Color Buffers"] = _cfg_get_bool(system, "rpcs3_colorbuffers", False, "writecolorbuffers")
        
        # Write Depth Buffers
        rpcs3ymlconfig["Video"]["Write Depth Buffer"] = _cfg_get_bool(system, "rpcs3_write_depth_buffers", False, "writedepthbuffers")
        
        # Read Color Buffers
        rpcs3ymlconfig["Video"]["Read Color Buffers"] = _cfg_get_bool(system, "rpcs3_read_color_buffers", False, "readcolorbuffers")
        
        # Read Depth Buffers
        rpcs3ymlconfig["Video"]["Read Depth Buffer"] = _cfg_get_bool(system, "rpcs3_read_depth_buffers", False, "readdepthbuffers")
        
        # Disable Vertex Cache
        rpcs3ymlconfig["Video"]["Disable Vertex Cache"] = _cfg_get_bool(system, "rpcs3_vertexcache", False, "disablevertex")
        
        # Strict rendering mode
        rpcs3ymlconfig["Video"]["Strict Rendering Mode"] = _cfg_get_bool(system, "rpcs3_strict", False, "strict_rendering")
        
        # Anisotropic Filtering
        rpcs3ymlconfig["Video"]["Anisotropic Filter Override"] = _cfg_get_int(system, "rpcs3_anisotropic", 0, "anisotropicfilter")
        
        # MSAA
        rpcs3ymlconfig["Video"]["MSAA"] = system.config.get("rpcs3_aa", "Auto")
        
        # ZCULL Accuracy
        match _cfg_get(system, "rpcs3_zcull", "", "zcull_accuracy"):
            case "Approximate":
                rpcs3ymlconfig["Video"]["Accurate ZCULL stats"] = False
                rpcs3ymlconfig["Video"]["Relaxed ZCULL Sync"] = False
            case "Relaxed":
                rpcs3ymlconfig["Video"]["Accurate ZCULL stats"] = False
                rpcs3ymlconfig["Video"]["Relaxed ZCULL Sync"] = True
            case _:
                rpcs3ymlconfig["Video"]["Accurate ZCULL stats"] = True
                rpcs3ymlconfig["Video"]["Relaxed ZCULL Sync"] = False

        # Internal resolution
        rpcs3ymlconfig["Video"]["Resolution"] = "1280x720"
        
        # Resolution scaling
        rpcs3ymlconfig["Video"]["Resolution Scale"] = _cfg_get_int(system, "rpcs3_resolution_scale", 100, "rpcs3_internal_resolution")
        
        # Output Scaling filter
        rpcs3ymlconfig["Video"]["Output Scaling Mode"] = _cfg_get(system, "rpcs3_scaling", "Bilinear", "rpcs3_scaling_filter")
        
        # Number of Shader Compilers
        rpcs3ymlconfig["Video"]["Shader Compiler Threads"] = system.config.get_int("rpcs3_num_compilers", 0)
        
        # Multithreaded RSX
        rpcs3ymlconfig["Video"]["Multithreaded RSX"] = _cfg_get_bool(system, "rpcs3_rsx", False, "multithreadedrsx")
        
        # Async Texture Streaming
        rpcs3ymlconfig["Video"]["Asynchronous Texture Streaming 2"] = _cfg_get_bool(system, "rpcs3_async_texture", False, "asynctexturestream")
        
        # Force CPU Blit Emulation
        rpcs3ymlconfig["Video"]["Force CPU Blit"] = _cfg_get_bool(system, "rpcs3_cpu_blit", False, "cpu_blit")
        
        # Disable ZCULL Occlusion Queries
        rpcs3ymlconfig["Video"]["Disable ZCull Occlusion Queries"] = _cfg_get_bool(system, "rpcs3_disable_zcull_queries", False, "disable_zcull_queries")
        
        # Driver Wake-up Delay
        rpcs3ymlconfig["Video"]["Driver Wake-Up Delay"] = _cfg_get_int(system, "rpcs3_driver_wake", 1, "driver_wake")
        
        # 3D mode
        rpcs3ymlconfig["Video"]["3D Display Mode"] = _cfg_get(system, "rpcs3_3d", "Disabled", "enable3d")
        
        # Fullscreen mode (exclusive vs borderless)
        fullscreen_mode = _cfg_get(system, "rpcs3_fullscreen_mode", "Automatic")
        if system.config.get_bool("exclusivefs"):
            fullscreen_mode = "Enable"
        rpcs3ymlconfig["Video"]["Exclusive Fullscreen Mode"] = fullscreen_mode

        # -= [Audio] =-
        rpcs3ymlconfig["Audio"]["Renderer"] = "Cubeb"
        rpcs3ymlconfig["Audio"]["Master Volume"] = 100
        
        # Audio format/channels
        rpcs3ymlconfig["Audio"]["Audio Format"] = _cfg_get(system, "rpcs3_audio_format", "Stereo", "audiochannels")
        
        # Convert to 16 bit
        rpcs3ymlconfig["Audio"]["Convert to 16 bit"] = system.config.get_bool("rpcs3_audio_16bit")
        
        # Audio buffering
        rpcs3ymlconfig["Audio"]["Enable Buffering"] = _cfg_get_bool(system, "rpcs3_audiobuffer", True, "audio_buffering")
        
        # Audio buffer duration
        rpcs3ymlconfig["Audio"]["Desired Audio Buffer Duration"] = system.config.get_int("rpcs3_audiobuffer_duration", 100)
        
        # Time stretching
        time_stretch_mode = _cfg_get(system, "time_stretching", "")
        if system.config.get_bool("rpcs3_timestretch"):
            rpcs3ymlconfig["Audio"]["Enable Time Stretching"] = True
            rpcs3ymlconfig["Audio"]["Enable Buffering"] = True
        elif time_stretch_mode in ("low", "medium", "high"):
            rpcs3ymlconfig["Audio"]["Enable Time Stretching"] = True
            rpcs3ymlconfig["Audio"]["Enable Buffering"] = True
        else:
            rpcs3ymlconfig["Audio"]["Enable Time Stretching"] = False
        
        # Time stretching threshold
        if time_stretch_mode == "low":
            rpcs3ymlconfig["Audio"]["Time Stretching Threshold"] = 25
        elif time_stretch_mode == "medium":
            rpcs3ymlconfig["Audio"]["Time Stretching Threshold"] = 50
        elif time_stretch_mode == "high":
            rpcs3ymlconfig["Audio"]["Time Stretching Threshold"] = 75
        else:
            rpcs3ymlconfig["Audio"]["Time Stretching Threshold"] = system.config.get_int("rpcs3_timestretch_threshold", 75)

        # -= [System] =-
        # System region
        rpcs3ymlconfig["System"]["License Area"] = _cfg_get(system, "rpcs3_region", "SCEA", "ps3_region")
        
        # System language
        rpcs3ymlconfig["System"]["Language"] = _cfg_get(system, "rpcs3_language", "English (US)", "ps3_language")

        # -= [Input/Output] =-
        # Gun stuff
        if system.config.use_guns and guns:
            rpcs3ymlconfig["Input/Output"]["Move"] = "Gun"
            rpcs3ymlconfig["Input/Output"]["Camera"] = "Fake"
            rpcs3ymlconfig["Input/Output"]["Camera type"] = "PS Eye"
        
        # Gun crosshairs
        rpcs3ymlconfig["Input/Output"]["Show move cursor"] = system.config.get_bool("rpcs3_crosshairs")
        
        # Keyboard handler
        rpcs3ymlconfig["Input/Output"]["Keyboard"] = _cfg_get(system, "rpcs3_keyboard", "Null", "keyboard")
        
        # Mouse handler
        rpcs3ymlconfig["Input/Output"]["Mouse"] = _cfg_get(system, "rpcs3_mouse", "Null", "mouse")
        
        # PS Move handler
        move_value = _cfg_get(system, "rpcs3_move", "", "move")
        if move_value:
            rpcs3ymlconfig["Input/Output"]["Move"] = move_value
        
        # Camera input
        camera_value = _cfg_get(system, "rpcs3_camera", "", "camera")
        if camera_value:
            rpcs3ymlconfig["Input/Output"]["Camera"] = camera_value
        
        # Camera type
        camera_type = _cfg_get(system, "rpcs3_cameraType", "", "cameraType")
        if camera_type:
            rpcs3ymlconfig["Input/Output"]["Camera type"] = camera_type
        
        # Gun configuration
        gun_mode = system.config.get("rpcs3_guns", "none")
        if gun_mode == "raw":
            rpcs3ymlconfig["Input/Output"]["Move"] = "Raw Mouse"
        elif gun_mode == "pseye":
            rpcs3ymlconfig["Input/Output"]["Move"] = "Gun"
            rpcs3ymlconfig["Input/Output"]["Camera"] = "Fake"

        # -= [Miscellaneous] =-
        rpcs3ymlconfig["Miscellaneous"]["Exit RPCS3 when process finishes"] = True
        rpcs3ymlconfig["Miscellaneous"]["Start games in fullscreen mode"] = True
        rpcs3ymlconfig["Miscellaneous"]["Automatically start games after boot"] = True
        rpcs3ymlconfig["Miscellaneous"]["Pause emulation on RPCS3 focus loss"] = True
        rpcs3ymlconfig["Miscellaneous"]["Prevent display sleep while running games"] = True
        
        # Show shader compilation hint
        hide_hints = _cfg_get_bool(system, "rpcs3_hidehints", False, "hidehints")
        rpcs3ymlconfig["Miscellaneous"]["Show shader compilation hint"] = not hide_hints
        rpcs3ymlconfig["Miscellaneous"]["Show PPU compilation hint"] = not hide_hints
        
        # Show trophy popups
        rpcs3ymlconfig["Miscellaneous"]["Show trophy popups"] = _cfg_get_bool(system, "rpcs3_show_trophy", False, "show_trophy")

        with RPCS3_CONFIG.open("w") as file:
            yaml = YAML(pure=True)
            yaml.default_flow_style = False
            yaml.dump(rpcs3ymlconfig, file)

        # copy icon files to config
        icon_target = RPCS3_CONFIG_DIR / 'Icons'
        mkdir_if_not_exists(icon_target)
        shutil.copytree('/usr/share/rpcs3/Icons/', icon_target, dirs_exist_ok=True, copy_function=shutil.copy2)

        # determine the rom name
        if rom.suffix == ".psn":
            romName: Path | None = None

            with rom.open() as fp:
                for line in fp:
                    if len(line) >= 9:
                        romName = RPCS3_CONFIG_DIR / "dev_hdd0" / "game" / line.strip().upper() / "USRDIR" / "EBOOT.BIN"

            if romName is None:
                raise BatoceraException(f'No game ID found in {rom}')
        elif configure_emulator(rom):
            romName: Path | None = None
        else:
            romName = rom / "PS3_GAME" / "USRDIR" / "EBOOT.BIN"

        if romName:
            commandArray: list[Path | str] = [RPCS3_BIN, romName]
        else:
            commandArray: list[Path | str] = [RPCS3_BIN]

        if not system.config.get_bool("rpcs3_gui") and romName:
            commandArray.append("--no-gui")

        # firmware not installed and available : instead of starting the game, install it
        if Rpcs3Generator.getFirmwareVersion() is None and (BIOS / "PS3UPDAT.PUP").exists():
            commandArray = [RPCS3_BIN, "--installfw", BIOS / "PS3UPDAT.PUP"]

        return Command.Command(
            array=commandArray,
            env={
                "XDG_CONFIG_HOME": CONFIGS,
                "XDG_CACHE_HOME": CACHE
            }
        )

    @staticmethod
    def getClosestRatio(gameResolution: Resolution) -> str:
        screenRatio = gameResolution["width"] / gameResolution["height"]
        if screenRatio < 1.6:
            return "4:3"
        return "16:9"

    def getInGameRatio(self, config, gameResolution, rom):
        return 16/9

    @staticmethod
    def getFirmwareVersion() -> str | None:
        try:
            with (RPCS3_CONFIG_DIR / "dev_flash" / "vsh" / "etc" / "version.txt").open("r") as stream:
                lines = stream.readlines()
            for line in lines:
                matches = re.match("^release:(.*):", line)
                if matches:
                    return matches[1]
        except Exception:
            return None
        return None
