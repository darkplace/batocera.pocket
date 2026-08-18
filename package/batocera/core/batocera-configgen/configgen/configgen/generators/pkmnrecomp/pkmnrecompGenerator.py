from __future__ import annotations

from typing import TYPE_CHECKING

from ... import Command
from ...controller import generate_sdl_game_controller_config
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


# LÖVE 11.5 ships SDL 2.30. That build:
#   * puts a name-CRC in GUID bytes 2-3 (ES still reports zeros there)
#   * numbers Linux buttons as (codes >= BTN_JOYSTICK) then leftover codes
# Odin 3 exposes BTN_BACK (278) before the gamepad keys in evdev, so ES ids
# are +1 versus SDL (ES dpup=b12, SDL dpup=b11). Copying the ES mapping onto
# the CRC GUID made physical DOWN fire dpup, LEFT fire dpdown, etc.
# Use SDL's own numbering for the CRC GUID (probed against libSDL2 2.30).
_ODIN3_SDL230_GUID = "0300bb95202000000130000001000000"
_ODIN3_SDL230_MAPPING = (
    "0300bb95202000000130000001000000,AYN Odin3 Gamepad,"
    "a:b0,b:b1,x:b2,y:b3,back:b6,guide:b8,start:b7,"
    "leftstick:b9,rightstick:b10,leftshoulder:b4,rightshoulder:b5,"
    "dpup:b11,dpdown:b12,dpleft:b13,dpright:b14,"
    "leftx:a0,lefty:a1,rightx:a3,righty:a4,lefttrigger:a2,righttrigger:a5,"
    "paddle1:b15,paddle2:b16,platform:Linux,"
)


def _with_sdl230_crc_guids(mapping: str) -> str:
    lines = [line for line in mapping.splitlines() if line.strip()]
    if not any("AYN Odin3 Gamepad" in line for line in lines):
        return mapping
    lines = [line for line in lines if not line.startswith(f"{_ODIN3_SDL230_GUID},")]
    return "\n".join(lines + [_ODIN3_SDL230_MAPPING])


class PkmnrecompGenerator(Generator):

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        core = (system.config.core or "gen1recomp").strip()
        if core not in {"gen1recomp", "gen2recomp"}:
            core = "gen1recomp"

        app_id = "pkmnrecomp-gen2" if core == "gen2recomp" else "pkmnrecomp-gen1"
        home = f"/userdata/saves/apps/{app_id}"

        commandArray = ["pkmnrecomp", "--core", core, rom]
        return Command.Command(
            array=commandArray,
            env={
                "HOME": home,
                "XDG_CONFIG_HOME": f"{home}/.config",
                "XDG_DATA_HOME": f"{home}/.local/share",
                "XDG_CACHE_HOME": f"{home}/.cache",
                "SDL_GAMECONTROLLERCONFIG": _with_sdl230_crc_guids(
                    generate_sdl_game_controller_config(playersControllers)
                ),
                "SDL_JOYSTICK_HIDAPI": "0",
                "SDL_ACCELEROMETER_AS_JOYSTICK": "0",
                "POKEPORT_TOUCH": "0",
                "POKEPORT_FORCE_MOBILE": "1",
                "BATOCERA_PKMNRECOMP_HOTKEYS": "1",
                "APPIMAGE_ALLOW_ROOT": "1",
                "APPIMAGE_EXTRACT_AND_RUN": "1",
            },
        )

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "pkmnrecomp",
            "keys": {
                "exit": ["KEY_LEFTALT", "KEY_F4"],
                "save_state": "KEY_F1",
                "restore_state": "KEY_F2",
            },
        }

    def getInGameRatio(self, config, gameResolution, rom):
        return 16 / 9
