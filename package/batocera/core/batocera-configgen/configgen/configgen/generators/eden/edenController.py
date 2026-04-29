from __future__ import annotations

from typing import TYPE_CHECKING

from ...controller import Controller, generate_sdl_game_controller_config

if TYPE_CHECKING:
    from ...controller import Controllers
    from ...input import Input
    from ...utils.configparser import CaseSensitiveRawConfigParser
    from ...Emulator import Emulator

EDEN_BUTTONS_MAPPING: dict[str, str | None] = {
    "button_a": "a",
    "button_b": "b",
    "button_x": "x",
    "button_y": "y",
    "button_lstick": "l3",
    "button_rstick": "r3",
    "button_l": "pageup",
    "button_r": "pagedown",
    "button_zl": "l2",
    "button_zr": "r2",
    "button_plus": "start",
    "button_minus": "select",
    "button_dleft": "left",
    "button_dup": "up",
    "button_dright": "right",
    "button_ddown": "down",
    "button_slleft": "pageup",
    "button_srleft": "pagedown",
    "button_home": "hotkey",
    "button_screenshot": None,
    "button_slright": "pageup",
    "button_srright": "pagedown",
}

EDEN_AXIS_MAPPING: dict[str, str] = {
    "lstick": "joystick1",
    "rstick": "joystick2",
}

_ONE_BASED_SDL_BUTTON_GUIDS = {
    "03000000202000000130000001000000",
}

_MAX_PLAYERS = 10


def set_eden_controllers(
    eden_config: CaseSensitiveRawConfigParser,
    system: Emulator,
    players_controllers: Controllers,
) -> None:
    if not eden_config.has_section("Controls"):
        eden_config.add_section("Controls")

    rumble = system.config.get("eden_rumble", "")

    for player_index in range(_MAX_PLAYERS):
        controller = Controller.find_player_number(players_controllers, player_index + 1)
        player_nb_str = f"player_{player_index}"

        eden_config.set("Controls", f"{player_nb_str}_type\\default", "true")
        eden_config.set("Controls", f"{player_nb_str}_type", "0")
        eden_config.set("Controls", f"{player_nb_str}_profile_name\\default", "true")
        eden_config.set("Controls", f"{player_nb_str}_profile_name", "")
        eden_config.set("Controls", f"{player_nb_str}_connected\\default", "true")
        eden_config.set("Controls", f"{player_nb_str}_connected", "true" if controller else "false")
        eden_config.set("Controls", f"{player_nb_str}_vibration_enabled\\default", "true")
        eden_config.set(
            "Controls",
            f"{player_nb_str}_vibration_enabled",
            "false" if rumble == "false" else "true",
        )
        eden_config.set("Controls", f"{player_nb_str}_vibration_strength\\default", "true")
        eden_config.set("Controls", f"{player_nb_str}_vibration_strength", "100")

        if controller is None:
            continue

        controller = _normalize_controller(controller)
        buttons_mapping = _get_buttons_mapping(controller, system)

        for out_key, src_key in buttons_mapping.items():
            eden_config.set("Controls", f"{player_nb_str}_{out_key}\\default", "false")
            eden_config.set(
                "Controls",
                f"{player_nb_str}_{out_key}",
                _build_button_binding(controller, player_index, src_key),
            )

        for out_key, src_key in EDEN_AXIS_MAPPING.items():
            eden_config.set("Controls", f"{player_nb_str}_{out_key}\\default", "false")
            eden_config.set(
                "Controls",
                f"{player_nb_str}_{out_key}",
                _build_stick_binding(controller, player_index, src_key),
            )

        for motion_key in ("motionleft", "motionright"):
            eden_config.set("Controls", f"{player_nb_str}_{motion_key}\\default", "false")
            eden_config.set("Controls", f"{player_nb_str}_{motion_key}", "[empty]")


def build_eden_sdl_game_controller_config(players_controllers: Controllers) -> str:
    return generate_sdl_game_controller_config(
        [_normalize_controller(controller) for controller in players_controllers]
    )


def _get_buttons_mapping(controller: Controller, system: Emulator) -> dict[str, str | None]:
    buttons_mapping = EDEN_BUTTONS_MAPPING.copy()

    if controller.real_name and "Nintendo" in controller.real_name:
        buttons_mapping["button_a"] = "b"
        buttons_mapping["button_b"] = "a"
        buttons_mapping["button_x"] = "y"
        buttons_mapping["button_y"] = "x"

    if system.config.get_bool("eden_inverse_button", False):
        buttons_mapping["button_a"] = "b"
        buttons_mapping["button_b"] = "a"
        buttons_mapping["button_x"] = "y"
        buttons_mapping["button_y"] = "x"

    return buttons_mapping


def _build_button_binding(controller: Controller, player_index: int, key: str | None) -> str:
    if key is None:
        return "[empty]"

    if key not in controller.inputs:
        return "[empty]"

    input = controller.inputs[key]
    guid = controller.guid
    pad = str(controller.index)
    port = str(player_index)

    if input.type == "button":
        return f'"pad:{pad},button:{input.id},port:{port},guid:{guid},engine:sdl"'
    if input.type == "hat":
        direction = _hat_direction(input.value)
        return f'"engine:sdl,port:{port},guid:{guid},direction:{direction},hat:{input.id}"'
    if input.type == "axis":
        invert = "+" if int(input.value) >= 0 else "-"
        return f'"engine:sdl,invert:{invert},port:{port},guid:{guid},axis:{input.id},threshold:0.500000"'

    return "[empty]"


def _build_stick_binding(controller: Controller, player_index: int, key: str) -> str:
    x_input: Input | None = None
    y_input: Input | None = None

    if key == "joystick1":
        x_input = controller.inputs.get("joystick1left")
        y_input = controller.inputs.get("joystick1up")
    elif key == "joystick2":
        x_input = controller.inputs.get("joystick2left")
        y_input = controller.inputs.get("joystick2up")

    if x_input is None or y_input is None or x_input.type != "axis" or y_input.type != "axis":
        return "[empty]"

    invert_x = "+" if int(x_input.value) < 0 else "-"
    invert_y = "+" if int(y_input.value) < 0 else "-"

    return (
        f'"engine:sdl,port:{player_index},guid:{controller.guid},axis_x:{x_input.id},offset_x:-0.000000,'
        f'axis_y:{y_input.id},offset_y:0.000000,invert_x:{invert_x},invert_y:{invert_y},deadzone:0.150000"'
    )


def _normalize_controller(controller: Controller) -> Controller:
    if not _needs_one_based_button_fix(controller):
        return controller

    normalized = controller.replace()
    normalized.inputs = {
        name: _normalize_input(input)
        for name, input in controller.inputs.items()
    }
    return normalized


def _normalize_input(input: Input) -> Input:
    if input.type != "button":
        return input

    try:
        button_id = int(input.id)
    except ValueError:
        return input

    if button_id <= 0:
        return input

    return input.replace(id=str(button_id - 1))


def _needs_one_based_button_fix(controller: Controller) -> bool:
    if controller.guid not in _ONE_BASED_SDL_BUTTON_GUIDS:
        return False

    button_ids = {
        int(input.id)
        for input in controller.inputs.values()
        if input.type == "button" and input.id.isdigit()
    }

    return 0 not in button_ids and set(range(1, 12)).issubset(button_ids)


def _hat_direction(value: str) -> str:
    if int(value) == 1:
        return "up"
    if int(value) == 4:
        return "down"
    if int(value) == 2:
        return "right"
    if int(value) == 8:
        return "left"
    return "unknown"
