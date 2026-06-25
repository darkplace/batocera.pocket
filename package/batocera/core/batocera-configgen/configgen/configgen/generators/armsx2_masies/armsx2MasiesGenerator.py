from __future__ import annotations

from pathlib import Path

from ..armsx2.armsx2Generator import Armsx2Generator


class Armsx2MasiesGenerator(Armsx2Generator):

    def getHotkeysContext(self):
        context = super().getHotkeysContext()
        context["name"] = "armsx2-masies"
        return context

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        command = super().generate(system, rom, playersControllers, metadata, guns, wheels, gameResolution)
        command.array = ["/usr/bin/start_armsx2_masies.sh", str(Path(rom))]
        return command
