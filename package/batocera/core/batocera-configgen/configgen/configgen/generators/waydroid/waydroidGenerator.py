from __future__ import annotations

from typing import TYPE_CHECKING

from ... import Command
from ...exceptions import BatoceraException
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


class WaydroidGenerator(Generator):

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        with rom.open() as f:
            app_id = str.strip(f.read())

        if not app_id:
            raise BatoceraException(f"Empty Waydroid app entry: {rom}")

        return Command.Command(
            array=["/usr/bin/batocera-waydroid-app-session", app_id],
            env={
                "BATOCERA_WAYDROID_DISABLE_MOUSE_CURSOR": system.config.get_bool(
                    "waydroid_disable_mouse_cursor", False, return_values=("1", "0")
                ),
                "BATOCERA_WAYDROID_DISABLE_GAMEPAD": system.config.get_bool(
                    "waydroid_disable_gamepad", False, return_values=("1", "0")
                ),
            },
        )

    def getMouseMode(self, config, rom):
        return not config.get_bool("waydroid_disable_mouse_cursor")

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "waydroid",
            "keys": {"exit": "waydroid session stop"},
        }
