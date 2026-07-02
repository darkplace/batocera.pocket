from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

from ... import Command
from ...batoceraPaths import BATOCERA_SHARE_DIR
from ...controller import generate_sdl_game_controller_config, write_sdl_controller_db
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


def _is_sm8550() -> bool:
    try:
        return (BATOCERA_SHARE_DIR / "batocera.arch").read_text().strip() in ("sm8550", "sm8750")
    except OSError:
        return False


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

        commandArray = ["/bin/bash", shrom]
        sdl_controller_config = generate_sdl_game_controller_config(playersControllers)
        env = {
            "SDL_GAMECONTROLLERCONFIG": sdl_controller_config
        }

        if system.config.emulator == "heroic":
            env["BATOCERA_HEROIC_EXTRA_ARGS"] = system.config.get_str("heroic_extra_args", "")
            env["BATOCERA_HEROIC_MODE"] = system.config.core
            env["SDL_JOYSTICK_HIDAPI"] = "0"
            env["SDL_JOYSTICK_HIDAPI_XBOX"] = "0"
            env["SDL_JOYSTICK_RAWINPUT"] = "0"
            env["SDL_JOYSTICK_DIRECTINPUT"] = "0"
            env["SDL_DIRECTINPUT_ENABLED"] = "0"
        elif system.config.emulator == "lutris":
            env["BATOCERA_LUTRIS_EXTRA_ARGS"] = system.config.get_str("lutris_extra_args", "")
            env["BATOCERA_LUTRIS_MODE"] = system.config.core
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
