from __future__ import annotations

from typing import TYPE_CHECKING

from ..sh.shGenerator import ShGenerator

if TYPE_CHECKING:
    from ...types import HotkeysContext


class AppsGenerator(ShGenerator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "apps",
            "keys": {
                "exit": "batocera-es-swissknife --emukill 0.5"
            },
        }
