from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from ...controller import Controllers
    from ...input import InputMapping
    from ...utils.configparser import CaseSensitiveRawConfigParser
    from ...Emulator import Emulator

YUZU_BUTTONS_MAPPING: dict[str, str] = {
    "button_a": "a",
    "button_b": "b",
    "button_x": "x",
    "button_y": "y",
    "button_dup": "up",
    "button_ddown": "down",
    "button_dleft": "left",
    "button_dright": "right",
    "button_l": "pageup",
    "button_r": "pagedown",
    "button_plus": "start",
    "button_minus": "select",
    "button_slleft": "pageup",
    "button_srleft": "pagedown",
    "button_slright": "pageup",
    "button_srright": "pagedown",
    "button_zl": "l2",
    "button_zr": "r2",
    "button_lstick": "l3",
    "button_rstick": "r3",
    "button_home": "hotkey",
}

YUZU_AXIS_MAPPING: dict[str, str] = {
    "lstick": "joystick1",
    "rstick": "joystick2",
}


def set_yuzu_controllers(
    yuzu_config: CaseSensitiveRawConfigParser,
    system: Emulator,
    players_controllers: Controllers,
) -> None:
    _set_switch_style_controllers(
        parser=yuzu_config,
        system=system,
        players_controllers=players_controllers,
        inverse_button_opt="yuzu_inverse_button",
        rumble_opt="yuzu_rumble",
    )


def _set_switch_style_controllers(
    parser: CaseSensitiveRawConfigParser,
    system: Emulator,
    players_controllers: Controllers,
    inverse_button_opt: str,
    rumble_opt: str,
) -> None:
    if not parser.has_section("Controls"):
        parser.add_section("Controls")

    guid_port: dict[str, int] = {}
    max_players = 10

    for nplayer, pad in enumerate(players_controllers[:max_players], start=0):
        player_nb_str = f"player_{nplayer}"

        port = guid_port.get(pad.guid, -1) + 1
        guid_port[pad.guid] = port

        buttons_mapping = YUZU_BUTTONS_MAPPING.copy()
        if pad.real_name and "Nintendo" in pad.real_name:
            buttons_mapping["button_a"] = "b"
            buttons_mapping["button_b"] = "a"
            buttons_mapping["button_x"] = "y"
            buttons_mapping["button_y"] = "x"

        if system.config.get_bool(inverse_button_opt, False):
            buttons_mapping["button_a"] = "b"
            buttons_mapping["button_b"] = "a"
            buttons_mapping["button_x"] = "y"
            buttons_mapping["button_y"] = "x"

        parser.set("Controls", f"{player_nb_str}_type\\default", "false")
        parser.set("Controls", f"{player_nb_str}_type", system.config.get(f"p{nplayer}_pad", "0"))

        for out_key, src_key in buttons_mapping.items():
            parser.set("Controls", f"{player_nb_str}_{out_key}\\default", "false")
            parser.set(
                "Controls",
                f"{player_nb_str}_{out_key}",
                f'"{_set_button(src_key, pad.guid, pad.inputs, port)}"',
            )

        for out_key, src_key in YUZU_AXIS_MAPPING.items():
            parser.set("Controls", f"{player_nb_str}_{out_key}\\default", "false")
            parser.set(
                "Controls",
                f"{player_nb_str}_{out_key}",
                f'"{_set_axis(src_key, pad.guid, pad.inputs, port)}"',
            )

        parser.set("Controls", f"{player_nb_str}_button_screenshot\\default", "false")
        parser.set("Controls", f"{player_nb_str}_button_screenshot", "[empty]")
        parser.set("Controls", f"{player_nb_str}_motionleft\\default", "false")
        parser.set("Controls", f"{player_nb_str}_motionleft", "[empty]")
        parser.set("Controls", f"{player_nb_str}_motionright\\default", "false")
        parser.set("Controls", f"{player_nb_str}_motionright", "[empty]")
        parser.set("Controls", f"{player_nb_str}_connected\\default", "false")
        parser.set("Controls", f"{player_nb_str}_connected", "true")

        if system.isOptSet(rumble_opt):
            rumble_enabled = "true" if system.config.get_bool(rumble_opt, True) else "false"
        else:
            rumble_enabled = "true"
        parser.set("Controls", f"{player_nb_str}_vibration_enabled\\default", "false")
        parser.set("Controls", f"{player_nb_str}_vibration_enabled", rumble_enabled)

    for nplayer in range(len(players_controllers), max_players):
        player_nb_str = f"player_{nplayer}"
        parser.set("Controls", f"{player_nb_str}_connected\\default", "false")
        parser.set("Controls", f"{player_nb_str}_connected", "false")


def _set_button(key: str, pad_guid: str, pad_inputs: InputMapping, port: int) -> str:
    if key not in pad_inputs:
        return ""

    input_obj = pad_inputs[key]

    if input_obj.type == "button":
        return f"button:{input_obj.id},guid:{pad_guid},port:{port},engine:sdl"

    if input_obj.type == "hat":
        return (
            f"hat:{input_obj.id},direction:{_hat_direction(input_obj.value)},"
            f"guid:{pad_guid},port:{port},engine:sdl"
        )

    if input_obj.type == "axis":
        return f"threshold:0.5,axis:{input_obj.id},guid:{pad_guid},port:{port},engine:sdl"

    return ""


def _set_axis(key: str, pad_guid: str, pad_inputs: InputMapping, port: int) -> str:
    inputx = "0"
    inputy = "0"

    if key == "joystick1" and "joystick1left" in pad_inputs:
        inputx = pad_inputs["joystick1left"].id
    elif key == "joystick2" and "joystick2left" in pad_inputs:
        inputx = pad_inputs["joystick2left"].id

    if key == "joystick1" and "joystick1up" in pad_inputs:
        inputy = pad_inputs["joystick1up"].id
    elif key == "joystick2" and "joystick2up" in pad_inputs:
        inputy = pad_inputs["joystick2up"].id

    return (
        "range:1.000000,deadzone:0.100000,invert_y:+,invert_x:+,"
        f"offset_y:-0.000000,axis_y:{inputy},offset_x:-0.000000,axis_x:{inputx},"
        f"guid:{pad_guid},port:{port},engine:sdl"
    )


def _hat_direction(value: str) -> str:
    direction = {
        1: "up",
        2: "right",
        4: "down",
        8: "left",
    }
    try:
        return direction.get(int(value), "unknown")
    except ValueError:
        return "unknown"
