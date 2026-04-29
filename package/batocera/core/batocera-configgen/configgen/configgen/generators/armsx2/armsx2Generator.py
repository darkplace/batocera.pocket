from __future__ import annotations

from pathlib import Path

from ... import Command
from ..aethersx2.aethersx2Generator import AetherSX2Generator


class Armsx2Generator(AetherSX2Generator):

    def getHotkeysContext(self):
        context = super().getHotkeysContext()
        context["name"] = "armsx2"
        return context

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        command = super().generate(system, rom, playersControllers, metadata, guns, wheels, gameResolution)
        command.array = ["/usr/bin/start_armsx2.sh", str(Path(rom))]
        command.env["XDG_DATA_HOME"] = "/userdata/system"
        command.env["XDG_CONFIG_HOME"] = "/userdata/system/.config"
        command.env["XDG_CACHE_HOME"] = "/userdata/system/cache"
        return command
