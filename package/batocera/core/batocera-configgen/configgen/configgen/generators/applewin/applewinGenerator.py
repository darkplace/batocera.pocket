from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING, Final

from ... import Command
from ...batoceraPaths import CONFIGS, mkdir_if_not_exists
from ...controller import generate_sdl_game_controller_config
from ...settings.unixSettings import UnixSettings
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext

_CONFIG_DIR: Final = CONFIGS / 'applewin'
_CONFIG_FILE: Final = _CONFIG_DIR / 'config.txt'
_HARD_DISK_EXTENSIONS: Final = {'.hdv', '.2mg'}
_SOUND_CARD_REGISTRY: Final[dict[str, tuple[int, int]]] = {
    'off': (0, 0),
    'mockingboard_slot4': (3, 0),
    'mockingboard_slot5': (0, 3),
    'mockingboard_dual': (3, 3),
    'phasor_slot4': (9, 0),
    'phasor_slot5': (0, 9),
}


def _playlist_entries(playlist: Path) -> list[Path]:
    entries: list[Path] = []
    with playlist.open(encoding='utf-8', errors='ignore') as playlist_file:
        for line in playlist_file:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            entry = Path(line)
            if not entry.is_absolute():
                entry = playlist.parent / entry
            entries.append(entry)
    return entries


def _is_hard_disk(image: Path) -> bool:
    return image.suffix.lower() in _HARD_DISK_EXTENSIONS


def _slot_card_registry(slot: int, card_type: int) -> str:
    return f'Configuration\\Slot_{slot}.Card_type={card_type}'


class AppleWinGenerator(Generator):
    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        mkdir_if_not_exists(_CONFIG_DIR)

        config = UnixSettings(_CONFIG_FILE, separator=' ')

        config.write()
        commandArray: list[str | Path] = ["applewin", "--conf", _CONFIG_FILE]

        media = system.config.get('applewin_media', 'auto')
        disk_images = _playlist_entries(rom) if rom.suffix.lower() == '.m3u' else [rom]

        if disk_images:
            if media == 'd2':
                commandArray += ["--d2", disk_images[0]]
            elif media == 'h1':
                commandArray += ["--h1", disk_images[0]]
            elif media == 'h2':
                commandArray += ["--h2", disk_images[0]]
            elif _is_hard_disk(disk_images[0]):
                commandArray += ["--h1", disk_images[0]]
            else:
                commandArray += ["--d1", disk_images[0]]

            if media not in {'d2', 'h1', 'h2'} and len(disk_images) > 1:
                if _is_hard_disk(disk_images[1]):
                    commandArray += ["--h2", disk_images[1]]
                else:
                    commandArray += ["--d2", disk_images[1]]

        if disk2 := system.config.get('applewin_disk2', ''):
            commandArray += ["--d2", Path(disk2)]

        if hard2 := system.config.get('applewin_hard2', ''):
            commandArray += ["--h2", Path(hard2)]

        if system.config.get_bool('applewin_no_imgui'):
            commandArray += ["--no-imgui"]

        if system.config.get_bool('applewin_aspect'):
            commandArray += ["--aspect-ratio"]

        if system.config.get_bool('applewin_fixedspeed'):
            commandArray += ["--fixed-speed"]

        if system.config.get_bool('applewin_timer'):
            commandArray += ["--timer"]

        if system.config.get_bool('applewin_no_squaring'):
            commandArray += ["--no-squaring"]

        if (gl_swap := system.config.get('applewin_gl_swap', 'auto')) != 'auto':
            commandArray += ["--gl-swap", gl_swap]

        if (audio_buffer := system.config.get('applewin_audio_buffer', 'auto')) != 'auto':
            commandArray += ["--audio-buffer", audio_buffer]

        if system.config.get_bool('applewin_fullscreen', True):
            commandArray += ["--fullscreen"]

        if sound_card := _SOUND_CARD_REGISTRY.get(system.config.get('applewin_mockingboard', 'auto')):
            for slot, card_type in enumerate(sound_card, start=4):
                commandArray += ["--registry", _slot_card_registry(slot, card_type)]

        return Command.Command(
            array=commandArray,
            env={
                'SDL_GAMECONTROLLERCONFIG': generate_sdl_game_controller_config(playersControllers)
            })

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "applewin",
            "keys": {
                "exit": ["KEY_LEFTALT", "KEY_F4"],
                "menu": "KEY_F3",
                "save_state": "KEY_F11",
                "restore_state": "KEY_F12",
                "swap_disk": "KEY_F5",
            },
        }
