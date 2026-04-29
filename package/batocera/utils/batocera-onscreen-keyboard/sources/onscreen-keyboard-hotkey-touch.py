#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0
#
# Toggle Batocera on-screen keyboard when HOTKEY is held and the touchscreen
# is tapped. Scoped to known handheld gamepad names.

from __future__ import annotations

import errno
import os
import selectors
import subprocess
import sys
import time
from dataclasses import dataclass

import evdev
from evdev import ecodes


GAMEPAD_NAMES = {
    "AYN Odin2 Gamepad",
    "Steam Deck",
    "ASUS ROG Ally Config",
    "Asus WMI hotkeys",
}
GAMEPAD_PRIORITY = {
    "ASUS ROG Ally Config": 0,
    "Steam Deck": 1,
    "AYN Odin2 Gamepad": 2,
    "Asus WMI hotkeys": 3,
}
HOTKEY_CODES = {
    ecodes.BTN_MODE,  # 316 on Odin2
    ecodes.KEY_F16,
    ecodes.KEY_F17,
    ecodes.KEY_F18,
    ecodes.KEY_PROG1,
}
TOUCH_CODE = ecodes.BTN_TOUCH
TOGGLE_CMD = ["/usr/bin/onscreen-keyboard", "toggle"]
RESCAN_DELAY_SECONDS = 2.0
TOGGLE_COOLDOWN_SECONDS = 0.35


@dataclass
class Devices:
    gamepad: evdev.InputDevice
    touchpads: list[evdev.InputDevice]


def is_touch_device(dev: evdev.InputDevice) -> bool:
    caps = dev.capabilities()
    if ecodes.EV_KEY not in caps:
        return False
    return TOUCH_CODE in caps[ecodes.EV_KEY]


def has_hotkey(dev: evdev.InputDevice) -> bool:
    caps = dev.capabilities()
    if ecodes.EV_KEY not in caps:
        return False
    keys = set(caps[ecodes.EV_KEY])
    return any(code in keys for code in HOTKEY_CODES)


def hotkey_score(dev: evdev.InputDevice) -> int:
    caps = dev.capabilities()
    if ecodes.EV_KEY not in caps:
        return 0
    keys = set(caps[ecodes.EV_KEY])
    return len(keys & HOTKEY_CODES)


def close_devices(devices: list[evdev.InputDevice]) -> None:
    for dev in devices:
        try:
            dev.close()
        except Exception:
            pass


def discover_devices() -> Devices | None:
    gamepad: evdev.InputDevice | None = None
    gamepad_candidates: list[evdev.InputDevice] = []
    touchpads: list[evdev.InputDevice] = []
    opened: list[evdev.InputDevice] = []

    try:
        for node in evdev.list_devices():
            dev = evdev.InputDevice(node)
            opened.append(dev)

            if dev.name in GAMEPAD_NAMES and has_hotkey(dev):
                gamepad_candidates.append(dev)
                continue

            if is_touch_device(dev):
                touchpads.append(dev)
    except Exception:
        close_devices(opened)
        return None

    if gamepad_candidates:
        # Prefer devices that expose more hotkey codes (Ally Config over WMI),
        # then apply an explicit name priority for deterministic selection.
        gamepad = sorted(
            gamepad_candidates,
            key=lambda d: (-hotkey_score(d), GAMEPAD_PRIORITY.get(d.name, 99), d.path),
        )[0]

    if gamepad is None or not touchpads:
        close_devices(opened)
        return None

    keep = {gamepad.path} | {d.path for d in touchpads}
    for dev in opened:
        if dev.path not in keep:
            dev.close()
    return Devices(gamepad=gamepad, touchpads=touchpads)


def toggle_keyboard() -> None:
    env = os.environ.copy()

    # Init scripts often lack Wayland vars; derive them from common Batocera paths.
    if not env.get("XDG_RUNTIME_DIR"):
        for runtime in ("/var/run", "/run/user/0", "/run/user/1000"):
            if os.path.isdir(runtime):
                env["XDG_RUNTIME_DIR"] = runtime
                break

    if not env.get("WAYLAND_DISPLAY"):
        runtime = env.get("XDG_RUNTIME_DIR")
        if runtime:
            for sock in ("wayland-0", "wayland-1"):
                if os.path.exists(os.path.join(runtime, sock)):
                    env["WAYLAND_DISPLAY"] = sock
                    break

    if not env.get("DISPLAY"):
        env["DISPLAY"] = ":0"

    try:
        subprocess.run(TOGGLE_CMD, check=False, timeout=3, env=env)
    except Exception:
        pass


def event_loop(devices: Devices) -> None:
    selector = selectors.DefaultSelector()
    all_devs = [devices.gamepad, *devices.touchpads]
    for dev in all_devs:
        selector.register(dev.fd, selectors.EVENT_READ, dev)

    hotkey_pressed = False
    last_toggle = 0.0

    try:
        while True:
            for key, _ in selector.select(timeout=1):
                dev = key.data
                try:
                    for event in dev.read():
                        if event.type != ecodes.EV_KEY:
                            continue

                        if dev.path == devices.gamepad.path and event.code in HOTKEY_CODES:
                            hotkey_pressed = event.value != 0
                            continue

                        if (
                            event.code == TOUCH_CODE and
                            event.value == 1 and
                            hotkey_pressed
                        ):
                            now = time.monotonic()
                            if now - last_toggle >= TOGGLE_COOLDOWN_SECONDS:
                                toggle_keyboard()
                                last_toggle = now
                except OSError as e:
                    if e.errno == errno.ENODEV:
                        return
                    raise
    finally:
        selector.close()
        close_devices(all_devs)


def main() -> int:
    # Best-effort guard: ignore non-Linux/input-less environments.
    if not os.path.isdir("/dev/input"):
        return 0

    while True:
        devices = discover_devices()
        if devices is None:
            time.sleep(RESCAN_DELAY_SECONDS)
            continue
        event_loop(devices)
        time.sleep(0.5)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        sys.exit(0)
