#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
import select
import signal
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import TYPE_CHECKING, Final, TypedDict
import errno

import evdev
import pyudev
from evdev import ecodes

if TYPE_CHECKING:
    from collections.abc import Mapping
    from types import FrameType

    class HotkeysContext(TypedDict):
        name: str
        keys: dict[str, list[int] | int | str]


    class JsonHotkeysContext(TypedDict):
        name: str
        keys: dict[str, list[str] | str]


DEVICE_NAME: Final   = "batocera hotkeys"
GDEFAULTCONTEXT_FILE: Final = Path("/etc/hotkeygen/default_context.conf")
GCOMMONCONTEXT_FILE: Final = Path("/etc/hotkeygen/common_context.conf")
GDEFAULTMAPPING_FILE: Final = Path("/etc/hotkeygen/default_mapping.conf")

GCONTEXT_FILE: Final = Path("/var/run/hotkeygen.context")
GPID_FILE: Final     = Path("/var/run/hotkeygen.pid")
GSYSTEM_DIR: Final   = Path("/usr/share/hotkeygen")
GUSER_DIR: Final     = Path("/userdata/system/configs/hotkeygen")

GUSERCOMMONCONTEXT_FILE: Final = GUSER_DIR / Path("common_context.conf")
GUSERDEFAULTMAPPING_FILE: Final = GUSER_DIR / Path("default_mapping.conf")

GBACKGLASS_PARAMS_FILE: Final = Path("/var/run/batocera-backglass.params")
GBACKGLASS_PID_FILES: Final = (
    Path("/var/run/batocera-backglass.pid"),
    Path("/var/run/batocera-lower-screen-kodi.pid"),
    Path("/var/run/batocera-lower-screen-waydroid.pid"),
)

gdebug = False

ECODES_NAMES: Final[dict[int, str]] = {
    # add BTN_ to that joysticks buttons can run hotkeys (but keep generating only KEY_ events)
    key_code: key_name for key_name, key_code in ecodes.ecodes.items() if key_name.startswith("KEY_") or key_name.startswith("BTN_")
}

# default context is for es
def get_default_context() -> HotkeysContext:
    if GDEFAULTCONTEXT_FILE.exists():
        with GDEFAULTCONTEXT_FILE.open() as file:
            data = json.load(file)
            return load_context(data)
    else:
        return {"name": "", "keys": {}}

def get_common_context_keys() -> dict[str, int|str]:
    keys = {}
    userkeys = {}

    if GCOMMONCONTEXT_FILE.exists():
        with GCOMMONCONTEXT_FILE.open() as file:
            data = json.load(file)
            keys = load_context_keys(data)

    if GUSERCOMMONCONTEXT_FILE.exists():
        with GUSERCOMMONCONTEXT_FILE.open() as file:
            data = json.load(file)
            userkeys = load_context_keys(data)

    return keys | userkeys

def get_context() -> HotkeysContext | None:
    if GCONTEXT_FILE.exists():
        try:
            if gdebug:
                print(f"using default context {GCONTEXT_FILE}")
            with GCONTEXT_FILE.open() as file:
                data = json.load(file)
                context = load_context(data)
                return context
        except Exception as e:
            print(f"fail to load context file : {e}")
            return None
    else:
        context = get_default_context()
        context["keys"] |= get_common_context_keys()
        if gdebug:
            print("using default context")
            print_context(context)
        return context

def load_context_keys(keys: dict[str, list[str] | str]) -> dict[str, list[int] | int | str]:
    res = {}
    for action, key_code_names in keys.items():
        if isinstance(key_code_names, list):
            codes: list[int] = []
            res[action] = codes
            for x in key_code_names:
                if x in ecodes.ecodes:
                    codes.append(ecodes.ecodes[x])
                else:
                    raise Exception(f"invalid key {x!r}")
        else:
            # string are key if starting by KEY_ else commands (maybe not the best choice, but simple)
            if key_code_names[:4] == "KEY_":
                if key_code_names in ecodes.ecodes:
                    res[action] = ecodes.ecodes[key_code_names]
                else:
                    raise Exception(f"invalid key {data['keys'][action]!r}")
            else:
                # command
                res[action] = key_code_names
    return res

def load_context(data: JsonHotkeysContext) -> HotkeysContext:
    if "name" not in data:
        raise Exception("no name section found")
    if "keys" not in data:
        raise Exception("no keys section found")

    context: HotkeysContext = { "name": data["name"], "keys": {} }
    context["keys"] = load_context_keys(data["keys"])
    if gdebug:
        print_context(context)
    return context

def save_context(context: HotkeysContext, gcontext_file: Path) -> None:
    save: JsonHotkeysContext = { "name": context["name"], "keys": {} }
    for action, key_codes in context["keys"].items():
        if isinstance(key_codes, list):
            save["keys"][action] = [ECODES_NAMES[key] for key in key_codes]
        elif isinstance(key_codes, str):
            save["keys"][action] = key_codes
        else:
            save["keys"][action] = ECODES_NAMES[key_codes]

    with gcontext_file.open("w") as fd:
        json.dump(save, fd, indent=2)

def print_context(context: HotkeysContext) -> None:
    print(f"Context [{context['name']}]:")
    for action, keys in context["keys"].items():
        if isinstance(keys, list):
            print(f"  {action:-<20}-> {[ECODES_NAMES[key] for key in keys]}")
        elif isinstance(keys, str):
            print(f"  {action:-<20}-> command [{keys}]")
        else:
            print(f"  {action:-<20}-> {ECODES_NAMES[keys]}")

def get_device_config_filename(device: evdev.InputDevice) -> str:
    name = re.sub('[^a-zA-Z0-9_]', '', device.name.replace(' ', '_'))
    return f"{name}-{device.info.vendor:02x}-{device.info.product:02x}.mapping"

def get_mapping_full_path(device: evdev.InputDevice) -> Path | None:
    fullpath = None
    fname = get_device_config_filename(device)
    if gdebug:
        print(f"...looking for {GUSER_DIR}/{fname}, {GSYSTEM_DIR}/{fname}")
    if (GUSER_DIR / fname).exists():
        fullpath = GUSER_DIR / fname
    elif (GSYSTEM_DIR / fname).exists():
        fullpath = GSYSTEM_DIR / fname
    return fullpath

def get_mapping(device: evdev.InputDevice) -> dict[int | tuple[int, ...], str]:
    if device is None:
        fullpath = None
    else:
        fullpath = get_mapping_full_path(device)

    if fullpath is not None:
        if gdebug:
            print(f"using mapping {fullpath}")
        with fullpath.open() as fd:
            data = json.load(fd)
        return load_mapping(data)
    else:
        data = {}
        userdata = {}
        if GDEFAULTMAPPING_FILE.exists():
            if gdebug:
                print(f"use default mapping file {GDEFAULTMAPPING_FILE}")
            with GDEFAULTMAPPING_FILE.open() as fd:
                data = json.load(fd)
        if GUSERDEFAULTMAPPING_FILE.exists():
            if gdebug:
                print(f"use user mapping file {GUSERDEFAULTMAPPING_FILE}")
            with GUSERDEFAULTMAPPING_FILE.open() as fd:
                userdata = json.load(fd)

        return load_mapping(data | userdata)

def load_mapping_key(key: str) -> int | tuple[int, ...]:
    if "+" in key:
        codes = []
        for part in key.split("+"):
            part = part.strip()
            if part not in ecodes.ecodes:
                raise Exception(f"invalid key {part!r}")
            codes.append(ecodes.ecodes[part])
        return tuple(sorted(set(codes)))

    if key in ecodes.ecodes:
        return ecodes.ecodes[key]

    raise Exception(f"invalid key {key!r}")

def format_mapping_key(key: int | tuple[int, ...]) -> str:
    if isinstance(key, tuple):
        return "+".join(ECODES_NAMES[x] for x in key)
    return ECODES_NAMES[key]

def load_mapping(data: dict[str, str]) -> dict[int | tuple[int, ...], str]:
    try:
        mapping: dict[int | tuple[int, ...], str] = {}
        for key, action in data.items():
            mapping[load_mapping_key(key)] = action
        return mapping
    except Exception as e:
        print(f"fail to load mapping : {e}")
        return {}

def get_mapping_associations(mapping: Mapping[int | tuple[int, ...], str], caps: evdev._CapabilitiesWithAbsInfo):
    capskeys = set(caps[ecodes.EV_KEY])
    associations = {}
    for key, value in mapping.items():
        if isinstance(key, tuple):
            if all(code in capskeys for code in key):
                associations[key] = value
        elif key in capskeys:
            associations[key] = value
    return associations

def print_mapping(
    mapping: Mapping[int | tuple[int, ...], str],
    associations: Mapping[int | tuple[int, ...], str],
    context: HotkeysContext | None = None
) -> None:
    for k in mapping:
        if k in associations:
            key_name = format_mapping_key(k)
            if context is None:
                print(f"  {key_name:-<31}-> {associations[k]}")
            else:
                if associations[k] in context["keys"]:
                    key_codes = context["keys"][associations[k]]
                    if isinstance(key_codes, list):
                        key_names = [ECODES_NAMES[x] for x in key_codes]
                        print(
                            f"  {key_name:-<31}-> {associations[k]:-<15}-> {key_names}"
                        )
                    elif isinstance(key_codes, str):
                        print(f"  {key_name:-<31}-> {associations[k]:-<15}-> {key_codes}")
                    else:
                        print(f"  {key_name:-<31}-> {associations[k]:-<15}-> {ECODES_NAMES[key_codes]}")
                else:
                    print(f"  {key_name:-<31}-> {associations[k]:15}")


def send_keys(target: evdev.UInput, keys: int | list[int] | str, begin: bool) -> None:
    if begin:
        n = 1
    else:
        n = 0

    if isinstance(keys, list):
        for x in keys:
            if gdebug:
               print(f"sending EV_KEY {x} {n}")
            target.write(ecodes.EV_KEY, x, n)
            target.syn()
    else:
        if gdebug:
            print(f"sending EV_KEY {keys} {n}")
        target.write(ecodes.EV_KEY, keys, n)
        target.syn()

def do_send(key: str, delay: None | int) -> None:
    if gdebug:
        if delay:
            print(f"Sending {key} with delay {delay}")
        else:
            print(f"Sending {key}")

    mapping = get_mapping(None)
    for code in mapping:
        if mapping[code] == key:
            if gdebug:
                print(f"sending {key}")
            if key == "exit" and lower_panel_widget_active():
                exit_emulator_without_focus()
                return
            sender = evdev.UInput(name="virtual keyboard", events={ ecodes.EV_KEY: [code] })
            time.sleep(0.1) # need some time to initialize... (otherwise the first events are ignored the time add is taken)
            send_keys(sender, code, True)
            # time required for emulators (like mame) based on states and not on events
            # (if you go too fast, the event is not seen)
            if delay:
                time.sleep(delay)
            else:
                time.sleep(0.1)
            send_keys(sender, code, False)

def send_reset_signal(target_device: evdev.UInput) -> None:
    target_device.write(ecodes.EV_REL, ecodes.REL_X, -10000)
    target_device.write(ecodes.EV_REL, ecodes.REL_Y, -10000)
    target_device.syn()
    
    time.sleep(0.10)
    
    target_device.write(ecodes.EV_KEY, ecodes.BTN_LEFT, 1)
    target_device.syn()
    target_device.write(ecodes.EV_KEY, ecodes.BTN_LEFT, 0)
    target_device.syn()
    
    time.sleep(0.10)

def run_quiet(args: list[str], timeout: float = 0.5) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(
            args,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None

def read_runtime_setting(key: str) -> str:
    result = run_quiet(["batocera-settings-get-master", key])
    if result is None or result.returncode != 0:
        return ""
    return result.stdout.strip()

def process_exists_from_pidfile(pidfile: Path) -> bool:
    try:
        pid = int(re.sub(r"\D", "", pidfile.read_text()))
    except (FileNotFoundError, ValueError):
        return False
    return Path(f"/proc/{pid}").exists()

def lower_panel_widget_active() -> bool:
    if any(process_exists_from_pidfile(pidfile) for pidfile in GBACKGLASS_PID_FILES):
        return True

    try:
        parts = GBACKGLASS_PARAMS_FILE.read_text().split(maxsplit=4)
    except FileNotFoundError:
        return False

    return len(parts) == 5 and parts[4] not in ("", "none")

def exit_emulator_without_focus() -> None:
    result = run_quiet(["pgrep", "-f", "-n", "emulatorlauncher"], timeout=0.5)
    if result is None or result.returncode != 0:
        return

    emulatorlauncher_pid = result.stdout.strip()
    if not emulatorlauncher_pid.isdigit():
        return

    # Lower-panel widgets share the compositor, so never inject a global exit key
    # when one is active. Terminate only the emulatorlauncher child tree instead.
    script = r'''
rc_pid="$1"
pids=""

collect_children() {
    local parent="$1"
    local child
    for child in $(pgrep -P "${parent}" 2>/dev/null); do
        pids="${pids} ${child}"
        collect_children "${child}"
    done
}

should_skip_pid() {
    local pid="$1"
    local cmdline
    cmdline="$(tr '\0' ' ' <"/proc/${pid}/cmdline" 2>/dev/null || true)"
    case "${cmdline}" in
        *waydroid*|*batocera-backglass*|*hotkeygen*)
            return 0
            ;;
    esac
    return 1
}

collect_children "${rc_pid}"

sent=0
for pid in ${pids}; do
    if should_skip_pid "${pid}"; then
        continue
    fi
    kill -TERM "${pid}" 2>/dev/null && sent=1
done

if [ "${sent}" = "0" ]; then
    kill -TERM "${rc_pid}" 2>/dev/null || true
fi

(
    for _ in $(seq 1 25); do
        kill -0 "${rc_pid}" 2>/dev/null || exit 0
        sleep 0.2
    done

    for pid in ${pids}; do
        if should_skip_pid "${pid}"; then
            continue
        fi
        kill -KILL "${pid}" 2>/dev/null || true
    done
) >/dev/null 2>&1 &
'''
    subprocess.Popen(
        ["/bin/bash", "-c", script, "batocera-hotkey-exit", emulatorlauncher_pid],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )

def setup_sway_environment() -> None:
    os.environ.setdefault("XDG_RUNTIME_DIR", "/var/run/0-runtime-dir")
    os.environ.setdefault("WAYLAND_DISPLAY", "wayland-1")

    if "SWAYSOCK" not in os.environ:
        runtime_dir = Path(os.environ["XDG_RUNTIME_DIR"])
        for candidate in runtime_dir.glob("sway-ipc.*.sock"):
            os.environ["SWAYSOCK"] = str(candidate)
            break

def walk_sway_nodes(node: dict) -> Iterator[dict]:
    yield node
    for child in node.get("nodes", []):
        yield from walk_sway_nodes(child)
    for child in node.get("floating_nodes", []):
        yield from walk_sway_nodes(child)

def sway_node_text(node: dict) -> str:
    props = node.get("window_properties") or {}
    values = (
        node.get("app_id"),
        node.get("name"),
        props.get("class"),
        props.get("title"),
    )
    return " ".join(str(value).lower() for value in values if value)

def find_sway_workspace(root: dict, workspace: str) -> dict | None:
    for node in walk_sway_nodes(root):
        if node.get("type") == "workspace" and node.get("name") == workspace:
            return node
    return None

def focus_top_panel_window(workspace: str) -> bool:
    result = run_quiet(["swaymsg", "-t", "get_tree"], timeout=0.8)
    if result is None or result.returncode != 0:
        return False

    try:
        root = json.loads(result.stdout)
    except json.JSONDecodeError:
        return False

    workspace_node = find_sway_workspace(root, workspace)
    if workspace_node is None:
        return False

    ignored_names = ("waydroid", "backglass", "kodi", "controlcenter")
    candidates = []
    for node in walk_sway_nodes(workspace_node):
        if node.get("id") is None:
            continue
        if node.get("type") not in ("con", "floating_con"):
            continue
        if node.get("pid") is None and not node.get("app_id") and not node.get("window"):
            continue
        if any(name in sway_node_text(node) for name in ignored_names):
            continue
        candidates.append(node)

    if not candidates:
        return False

    candidates.sort(key=lambda node: (
        0 if node.get("focused") else 1,
        0 if node.get("fullscreen_mode", 0) else 1,
        0 if node.get("pid") else 1,
    ))
    node_id = candidates[0].get("id")
    if node_id is None:
        return False

    result = run_quiet(["swaymsg", f"[con_id={node_id}] focus"], timeout=0.8)
    return result is not None and result.returncode == 0

def focus_top_panel_workspace_for_lower_widget() -> None:
    if not lower_panel_widget_active():
        return

    if read_runtime_setting("display.position") != "top-bottom":
        return
    if not read_runtime_setting("global.videooutput2"):
        return

    setup_sway_environment()
    result = run_quiet(["swaymsg", "-t", "get_outputs"], timeout=0.8)
    if result is None or result.returncode != 0:
        return

    try:
        outputs = json.loads(result.stdout)
    except json.JSONDecodeError:
        return

    active_outputs = [
        output for output in outputs
        if output.get("active") and output.get("current_workspace")
    ]
    if len(active_outputs) < 2:
        return

    active_outputs.sort(key=lambda output: (
        output.get("rect", {}).get("y", 0),
        output.get("rect", {}).get("x", 0),
    ))
    workspace = active_outputs[0].get("current_workspace")
    if workspace:
        run_quiet(["swaymsg", "workspace", str(workspace)], timeout=0.8)
        focus_top_panel_window(str(workspace))

def do_reset_mouse() -> None:
    # Create temporary device
    sender = evdev.UInput(
        name="batocera-mouse-reset", 
        events={
            ecodes.EV_REL: [ecodes.REL_X, ecodes.REL_Y],
            ecodes.EV_KEY: [ecodes.BTN_LEFT]
        }
    )
    time.sleep(0.2)

    send_reset_signal(sender)
    
    sender.close()

def read_pid() -> str:
    with GPID_FILE.open() as fd:
        return fd.read().replace('\n', '')

def signal_hotkeygen() -> None:
    try:
        pid = int(read_pid())
        os.kill(pid, signal.SIGHUP)
    except (FileNotFoundError, ProcessLookupError, ValueError):
        # Hotkey daemon may be stopped/restarted while contexts are updated.
        return

def do_new_context(context_name: str | None = None, context_json: str | None = None, include_common:bool = True) -> None:
    if context_name is not None and context_json is not None:
        context = load_context({
            'name': context_name,
            'keys': json.loads(context_json)
        })
        if include_common:
            context["keys"] |= get_common_context_keys()

        # update the config file
        save_context(context, GCONTEXT_FILE)
    else:
        if GCONTEXT_FILE.exists():
            GCONTEXT_FILE.unlink()

    # inform the process
    signal_hotkeygen()

def do_reload_devices_config():
    # inform the process
    signal_hotkeygen()

def do_list() -> None:
    context = get_context()

    udev_context = pyudev.Context()

    if context is not None:
        print_context(context)

    for device in udev_context.list_devices(subsystem='input'):
        if device.device_node is not None and device.device_node.startswith("/dev/input/event"):
            dev = evdev.InputDevice(device.device_node)
            if dev.name != DEVICE_NAME:
                caps = dev.capabilities()
                if ecodes.EV_KEY in caps:
                    mapping = get_mapping(dev)
                    associations = get_mapping_associations(mapping, caps)

                    fullpath = get_mapping_full_path(dev)
                    if fullpath:
                        print(f"# device {device.device_node} [{dev.name}] ({fullpath})")
                    else:
                        fname = get_device_config_filename(dev)
                        print(f"# device {device.device_node} [{dev.name}] (no {fname} file found)")
                    if associations:
                        print_mapping(mapping, associations, context)

@dataclass(slots=True)
class Daemon:
    permanent: bool = field(kw_only=True)

    context: HotkeysContext | None = field(init=False, default=None)
    running: bool = field(init=False, default=False)
    input_devices: dict[str, evdev.InputDevice] = field(init=False, default_factory=dict)
    input_devices_by_fd: dict[int, evdev.InputDevice] = field(init=False, default_factory=dict)
    mappings_by_fd: dict[int, dict[int | tuple[int, ...], str]] = field(init=False, default_factory=dict)
    udev_context: pyudev.Context = field(init=False)
    monitor: pyudev.Monitor = field(init=False)
    poll: select.poll = field(init=False)
    target: evdev.UInput = field(init=False)
    require_reconfig: bool = field(init=False, default=False)
    pressed_by_fd: dict[int, set[int]] = field(init=False, default_factory=dict)
    active_chords_by_fd: dict[int, set[tuple[int, ...]]] = field(init=False, default_factory=dict)

    def __post_init__(self) -> None:
        self.udev_context = pyudev.Context()
        self.monitor = pyudev.Monitor.from_netlink(self.udev_context)
        self.monitor.filter_by(subsystem='input')

        self.poll = select.poll()

        keys_list = [x for x in range(ecodes.KEY_MAX) if x in ECODES_NAMES and ECODES_NAMES[x][:4] == "KEY_"]
        keys_list.append(ecodes.BTN_LEFT)

        # target virtual keyboard & mouse
        self.target = evdev.UInput(
            name=DEVICE_NAME, events={
                ecodes.EV_KEY: keys_list,
                ecodes.EV_REL: [ecodes.REL_X, ecodes.REL_Y]
            }
        )

    def __handle_actions(self, action: str, device: pyudev.Device) -> None:
        if device.device_node is not None and device.device_node.startswith("/dev/input/event"):
            if action == "add":
                input_device = evdev.InputDevice(device.device_node)

                if input_device.name != DEVICE_NAME:
                    capabilities = input_device.capabilities()

                    if ecodes.EV_KEY in capabilities:
                        mapping = get_mapping(input_device)
                        associations = get_mapping_associations(mapping, capabilities)

                        if associations:
                            if gdebug:
                                print(f"Adding device {device.device_node}: {input_device.name}")
                                print_mapping(mapping, associations)
                            self.input_devices[device.device_node] = input_device
                            self.input_devices_by_fd[input_device.fileno()] = input_device
                            self.mappings_by_fd[input_device.fileno()] = mapping
                            self.pressed_by_fd[input_device.fileno()] = set()
                            self.active_chords_by_fd[input_device.fileno()] = set()
                            self.poll.register(input_device, select.POLLIN)
            elif action == "remove":
                input_device = self.input_devices.get(device.device_node)

                if input_device is not None:
                    if gdebug:
                        print(f"Removing device {device.device_node}: {input_device.name}")

                    self.poll.unregister(input_device)
                    del self.mappings_by_fd[input_device.fileno()]
                    del self.pressed_by_fd[input_device.fileno()]
                    del self.active_chords_by_fd[input_device.fileno()]
                    del self.input_devices_by_fd[input_device.fileno()]
                    del self.input_devices[device.device_node]

    def __handle_event(self, event: evdev.InputEvent, action: str, begin: bool) -> None:
        if self.context is not None and action in self.context["keys"]:
            keys = self.context["keys"][action]

            if action == "exit" and lower_panel_widget_active():
                if (isinstance(keys, str) and not begin) or (not isinstance(keys, str) and begin):
                    exit_emulator_without_focus()
                return

            if action == "exit" and ((isinstance(keys, str) and not begin) or (not isinstance(keys, str) and begin)):
                focus_top_panel_workspace_for_lower_widget()
                send_reset_signal(self.target)

            if gdebug:
                print(f"code:{event.code}, value:{event.value}, action:{action}")
            if begin:
                if isinstance(keys, str):
                    pass # nothing on keydown
                else:
                    if action != "exit":
                        focus_top_panel_workspace_for_lower_widget()
                    send_keys(self.target, keys, True)
            else:
                if isinstance(keys, str):
                    os.system(keys)
                else:
                    send_keys(self.target, keys, False)

    def __write_pid(self) -> None:
        with GPID_FILE.open("w") as fd:
            fd.write(str(os.getpid()))

    def __handle_sighup(self, signum: int, frame: FrameType | None) -> None:
        self.context = get_context()
        self.require_reconfig = True # done outside of the event cause, to make it safely

    def __reload_devices_configs(self) -> None:
        # reload config files for devices
        for fd in self.input_devices_by_fd:
            input_device = self.input_devices_by_fd[fd]
            mapping = get_mapping(input_device)
            self.mappings_by_fd[fd] = mapping

        # try to load a device that had not configuration file before
        for device in self.udev_context.list_devices(subsystem='input'):
            if device.device_node not in self.input_devices:
                self.__handle_actions('add', device)

    def run(self) -> None:
        if self.running:
            raise Exception("already running!")

        self.running = True
        self.context = get_context()

        # permanent : write a pid so that new configuration can apply
        if self.permanent:
            self.__write_pid()

        # monitor all udev devices
        self.monitor.start()
        self.poll.register(self.monitor, select.POLLIN)

        # adding existing devices in the poll
        for device in self.udev_context.list_devices(subsystem='input'):
            self.__handle_actions('add', device)

        # to read new contexts
        signal.signal(signal.SIGHUP, self.__handle_sighup)

        # read all devices
        while True:
            if self.require_reconfig:
                self.require_reconfig = False
                self.__reload_devices_configs()

            for fd, _ in self.poll.poll(1000):
                try:
                    if fd == self.monitor.fileno():
                        (action, device) = self.monitor.receive_device()
                        self.__handle_actions(action, device)
                    else:
                        event = self.input_devices_by_fd[fd].read_one()
                        if (
                            event is not None and
                            event.type == ecodes.EV_KEY and
                            event.value in (0, 1)
                        ):
                            mappings = self.mappings_by_fd[fd]
                            pressed = self.pressed_by_fd[fd]
                            active_chords = self.active_chords_by_fd[fd]

                            if event.value == 1:
                                pressed.add(event.code)
                            else:
                                pressed.discard(event.code)

                            if event.code in mappings:
                                self.__handle_event(event, mappings[event.code], event.value == 1)

                            for mapping_key, action in mappings.items():
                                if not isinstance(mapping_key, tuple):
                                    continue

                                if all(code in pressed for code in mapping_key):
                                    if mapping_key not in active_chords:
                                        active_chords.add(mapping_key)
                                        if self.context is not None and isinstance(self.context["keys"].get(action), str):
                                            self.__handle_event(event, action, False)
                                        else:
                                            self.__handle_event(event, action, True)
                                elif mapping_key in active_chords:
                                    active_chords.remove(mapping_key)
                                    if self.context is not None and not isinstance(self.context["keys"].get(action), str):
                                        self.__handle_event(event, action, False)
                #except (OSError, KeyError, FileNotFoundError) as e:
                except (Exception) as e:
                    if fd == self.monitor.fileno():
                        print("Exception happened on the monitor fd")
                        print(e)
                        #raise
                    else:
                        # error on a single device
                        if fd in self.input_devices_by_fd:
                            input_device = self.input_devices_by_fd[fd]
                            if not (isinstance(e, OSError) and e.errno == errno.ENODEV):
                                print(e)
                                print(f"error on device {input_device.name} ({input_device.path}), closing.")
                            del self.mappings_by_fd[fd]
                            del self.pressed_by_fd[fd]
                            del self.active_chords_by_fd[fd]
                            del self.input_devices_by_fd[fd]
                            del self.input_devices[input_device.path]
                            try:
                                self.poll.unregister(input_device)
                                input_device.close()
                            except:
                                pass
        # never happening, but should be done to quit
        self.target.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="hotkeygen")
    parser.add_argument("--debug", action="store_true")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--send")
    parser.add_argument("--send-delay", type=int)
    parser.add_argument("--default-context", action="store_true")
    parser.add_argument("--new-context", nargs=2, metavar=("new-context-name", "new-context-json"))
    parser.add_argument("--disable-common", action="store_true")
    parser.add_argument("--reload", action="store_true")
    parser.add_argument("--permanent", action="store_true")
    parser.add_argument("--reset-mouse", action="store_true")
    args = parser.parse_args()
    if args.debug:
        gdebug = True

    if args.list:
        do_list()
    elif args.reset_mouse:
        do_reset_mouse()
    elif args.send is not None:
        do_send(args.send, args.send_delay)
    elif args.new_context is not None:
        new_context_name, new_context_json = args.new_context
        do_new_context(new_context_name, new_context_json, not args.disable_common)
    elif args.reload:
        do_reload_devices_config()
    elif args.default_context:
        do_new_context()
    else:
        Daemon(permanent=args.permanent).run()
#####
