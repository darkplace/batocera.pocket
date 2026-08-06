#!/usr/bin/env python3
"""
LED Service Daemon for handheld devices
Show battery level and retroachievements through LED controllers
Written for Batocera - @lbrpdx

In order to configure your own color mapping
edit a file /userdata/system/configs/leds.conf with:

Battery in %
Color in RGB syntax
Each line is: battery_threshold=rgb_color
default is:

  3=PULSE
  5=FF0000
  10=CC3333
  15=ESCOLOR
  100=009900

100 is when a charger is plugged in
You can use PULSE, RAINBOW, CHROMA and OFF as rgb_color for special effects.

ESCOLOR is the default one set with sliders in EmulationStation

RetroAchievements unlocks are hooked automatically by the package and will blink
the device LEDs when LEDs are enabled in Batocera.

"""
import os
import time
import sys
import glob
import batoled

DEBUG = 0
CHECK_INTERVAL  = 1  # seconds between two checks (kept low for responsive ES LED slider updates)
ANIMATION_FRAME_INTERVAL = 0.05
LED_CHANGE_TIME = 120 # seconds to prevent changes while entering the settings menu
CONFIG_FILE='/userdata/system/configs/leds.conf'
BLOCK_FILE='/var/run/led-handheld-block'
CHARGE_LIMIT_SETTING='system.battery.charge_limit'
CHARGE_TARGET_REACHED_COLOR='0000FF'
STATUS_LED_ENABLED_SETTING='led.status.enabled'
ANIMATED_LED_MODES = ("rainbow", "chroma", "pulse")
PID_FILE='/var/run/led-handheld.pid'

def check_support():
    model = batoled.batocera_model()
    battery_paths = [
        "/sys/class/power_supply/BAT0",
        "/sys/class/power_supply/BAT1",
        "/sys/class/power_supply/qcom-battery",
        "/sys/class/power_supply/battery",
    ]
    if model in ["pwm", "rgbaddr", "legiongos"]:
        for path in battery_paths:
            if os.path.exists(path):
                return path
    if model in ["rgb"]:
        for path in battery_paths:
            if os.path.exists(path):
                return path
    else:
        print("Device unsupported.")
        return None

def device_compatible_values():
    try:
        with open('/proc/device-tree/compatible', 'rb') as f:
            return [value.decode(errors='ignore') for value in f.read().split(b'\0') if value]
    except Exception:
        return []

def is_odin_sleep_status_device():
    values = device_compatible_values()
    return 'ayn,odin2' in values or 'ayn,odin3' in values

# Read color from the config file
def read_color(tempval, configlist):
    for curconfig in configlist:
        curpair = curconfig.split("=")
        tempcfg = int(curpair[0])
        fancfg = curpair[1]
        if int(tempval) >= tempcfg:
            return fancfg
    return 0

# Load the config file to memory
def load_config(fname):
    newconfig = []
    try:
        with open(fname, "r") as fp:
            for curline in fp:
                if not curline:
                    continue
                tmpline = curline.strip()
                if not tmpline:
                    continue
                if tmpline[0] == "#":
                    continue
                tmppair = tmpline.split("=")
                if len(tmppair) != 2:
                    continue
                tempval = 0
                fanval = 0
                try:
                    tempval = int(tmppair[0])
                    if tempval < 0 or tempval > 100:
                        continue
                except:
                    continue
                try:
                    fanval = tmppair[1]
                except:
                    continue
                newconfig.append(f'{tempval:3.0f}={fanval}')
        if len(newconfig) > 0:
            newconfig.sort(reverse=True)
    except:
        return []
    return newconfig

def is_split_status_led_device(led) -> bool:
    # Odin2-style devices have a separate status LED (power-led) plus accent LEDs.
    try:
        status_paths = getattr(led, "status_paths", None)
        accent_paths = getattr(led, "accent_paths", None)
        if not status_paths or not accent_paths:
            return False
        return set(status_paths) != set(accent_paths)
    except Exception:
        return False

def default_led_config_for(led):
    # Default mapping when /userdata/system/configs/leds.conf is missing.
    #
    # For split devices, keep the battery/status LED independent from the ES accent colour.
    # This matches the common "green = ok, red = low, amber = charging" expectation.
    if hasattr(led, "set_status_color") and is_split_status_led_device(led):
        # Status/power LED is battery-owned only (accent LEDs keep ES colour separately).
        # read_color() uses >= threshold matching:
        # - Charging: yellow/amber via the synthetic "100" bucket
        # - Full (100%): handled in get_status_colour_for_battery() as green
        # - <=20%: red
        # - otherwise: OFF (do not mirror accent colour / "healthy green")
        return ["100=FFCC00", "21=OFF", "0=FF0000"]
    if hasattr(led, "status_paths") and hasattr(led, "accent_paths"):
        status_paths = getattr(led, "status_paths", [])
        accent_paths = getattr(led, "accent_paths", [])
        if status_paths and accent_paths and set(status_paths) == set(accent_paths):
            # Accent-only RGB devices, including the current Odin3 DTS, do not expose
            # a separate battery/status LED. Keep the user-selected ES colour while
            # charging instead of turning the rings green.
            return ["100=ESCOLOR", "15=ESCOLOR", "10=CC3333", "5=FF0000", "3=PULSE"]
    # Legacy behavior: use ES accent colour for normal battery levels.
    return ["100=009900", "15=ESCOLOR", "10=CC3333", "5=FF0000", "3=PULSE"]

def read_battery_state():
    with open(PATH + '/capacity', 'r') as tp, open(PATH + '/status','r') as st:
        bt = tp.readline().strip()
        ch = st.readline().strip()
        return bt, ch

def read_int_file(path):
    try:
        with open(path, 'r') as f:
            return int(f.readline().strip())
    except Exception:
        return None

def charge_limit_target():
    limit = batoled.batoconf(CHARGE_LIMIT_SETTING)
    try:
        value = int(limit) if limit is not None else None
    except Exception:
        value = None
    if value is None:
        value = read_int_file(PATH + '/charge_control_end_threshold')
    if value is None:
        return 100
    return max(0, min(100, value))

def charger_online():
    for power_supply in glob.glob('/sys/class/power_supply/*'):
        if os.path.abspath(power_supply) == os.path.abspath(PATH):
            continue
        supply_type = ""
        try:
            with open(power_supply + '/type', 'r') as f:
                supply_type = f.readline().strip()
        except Exception:
            pass
        if supply_type == "Battery":
            continue
        for field in ('online', 'present'):
            value = read_int_file(power_supply + '/' + field)
            if value and value > 0:
                return True
    return False

def charge_target_reached(led, bt, ch):
    if not is_split_status_led_device(led):
        return False
    if ch not in ("Full", "Not charging"):
        return False
    try:
        capacity = int(bt)
    except Exception:
        return False
    target = charge_limit_target()
    return target < 100 and capacity >= target and charger_online()

def get_status_colour_for_battery(led, ledconfig, bt, ch):
    # A split battery/status LED is system-owned.  Third-party accent-LED tools
    # must not be able to disable it by replacing leds.conf with an all-OFF map.
    # Keep a deliberate native escape hatch for users who really do want only
    # the status LED disabled while leaving the accent LEDs enabled.
    if is_split_status_led_device(led) and not status_led_runtime_enabled():
        return "OFF"

    if charge_target_reached(led, bt, ch):
        return CHARGE_TARGET_REACHED_COLOR

    # Charging/Full are treated specially. Buildroot/Batocera commonly expose these statuses.
    if ch == "Full":
        return "00FF00"
    if ch == "Charging":
        return read_color("100", ledconfig)

    # Discharging at 100%: avoid entering the "charger plugged" bucket.
    if ch == "Discharging" and bt == "100":
        bt = "99"
    return read_color(bt, ledconfig)

def leds_runtime_enabled():
    # Keep compatibility with both the old runtime key and the handheld service key.
    enabled = batoled.batoconf("led.enabled")
    service_enabled = batoled.batoconf("system.led-handheld")
    for val in (enabled, service_enabled):
        if val is not None and val.strip() == "0":
            return False
    return True

def status_led_runtime_enabled():
    enabled = batoled.batoconf(STATUS_LED_ENABLED_SETTING)
    return enabled is None or enabled.strip() != "0"

def config_disables_all_status_states(configlist):
    values = []
    for entry in configlist:
        _threshold, separator, value = entry.partition("=")
        if separator:
            values.append(value.strip().upper())
    return bool(values) and all(value == "OFF" for value in values)

def current_led_mode():
    mode = batoled.batoconf("led.mode") or "static"
    return mode.strip().lower()

def is_animated_led_mode():
    return current_led_mode() in ANIMATED_LED_MODES

def animation_sleep_interval(led):
    if not is_animated_led_mode():
        return CHECK_INTERVAL
    # Kernel-backed effects persist without userspace stepping.
    if led.__class__.__name__ == "legiongosled":
        return CHECK_INTERVAL
    return ANIMATION_FRAME_INTERVAL

def animated_led_frame_color(mode, frame):
    step = frame % batoled.EFFECT_STEP
    if mode == "pulse":
        r, g, b = batoled.batoconf_color()
        base = f'{batoled.dec_to_hex(r)}{batoled.dec_to_hex(g)}{batoled.dec_to_hex(b)}'
        return batoled.getPulseRGB(step, batoled.EFFECT_STEP, base)

    # Chroma is a uniform hue cycle on software-driven RGB LEDs.
    return batoled.getRainbowRGB(float(step / batoled.EFFECT_STEP))

def set_rgbled_dec_color(led, paths, rgb):
    r, g, b = batoled.hex_to_dec(rgb[0:2]), batoled.hex_to_dec(rgb[2:4]), batoled.hex_to_dec(rgb[4:6])
    led._set_paths_color(paths, f'{r} {g} {b}')

def apply_animated_led_frame(led, frame):
    mode = current_led_mode()
    if mode not in ANIMATED_LED_MODES:
        return frame

    if led.__class__.__name__ == "legiongosled":
        if mode == "pulse":
            led.set_color("PULSE")
        elif mode == "chroma":
            led.set_color("CHROMA")
        else:
            led.set_color("RAINBOW")
        return frame

    # Thor/Odin-style RGB class LEDs have multiple addressable segments. Use them
    # for rainbow so it is visually distinct from chroma's uniform hue cycle.
    if mode == "rainbow" and hasattr(led, "accent_paths") and hasattr(led, "_set_paths_color"):
        paths = getattr(led, "accent_paths", [])
        if paths:
            count = max(1, len(paths))
            for idx, path in enumerate(paths):
                offset_step = (frame + int((idx * batoled.EFFECT_STEP) / count)) % batoled.EFFECT_STEP
                rgb = batoled.getRainbowRGB(float(offset_step / batoled.EFFECT_STEP))
                set_rgbled_dec_color(led, [path], rgb)
            return (frame + 1) % batoled.EFFECT_STEP

    led.set_color(animated_led_frame_color(mode, frame))
    return (frame + 1) % batoled.EFFECT_STEP

def daemon_running():
    try:
        with open(PID_FILE, 'r') as f:
            pid = int(f.readline().strip())
        if pid == os.getpid():
            return False
        os.kill(pid, 0)
        return True
    except Exception:
        return False

# Check the current battery level and adjust led color
def led_check(led):
    ledconfig = default_led_config_for(led)
    tmpconfig = load_config(CONFIG_FILE)
    if len(tmpconfig) > 0:
        # leds.conf remains fully customizable, including OFF for individual
        # battery ranges.  On devices with a separate system status LED, an
        # all-OFF file is ignored unless led.status.enabled=0 was explicitly
        # selected.  This prevents joystick/accent utilities from silently
        # taking ownership of the battery indicator.
        if (is_split_status_led_device(led)
                and config_disables_all_status_states(tmpconfig)
                and status_led_runtime_enabled()):
            print(f"Ignoring all-OFF {CONFIG_FILE} for the system status LED")
        else:
            ledconfig = tmpconfig
    if (DEBUG):
        print(ledconfig)
    prevblock = 0
    prev_enabled = None
    prev_es_color = batoled.batoconf("led.colour")
    prev_es_brightness = batoled.batoconf("led.brightness")
    prev_led_mode = current_led_mode()
    animation_frame = 0
    initialized = False
    while True:
        try:
            enabled = "1" if leds_runtime_enabled() else "0"
            if enabled == "0":
                # User explicitly disabled LEDs: always turn them off immediately,
                # even if we're currently "blocking" color changes for the ES color picker.
                led.turn_off()
                prev_enabled = "0"
                initialized = False
                time.sleep(CHECK_INTERVAL)
                continue

            # Ensure LEDs are applied at boot and after re-enabling so the user
            # doesn't need to "nudge" a slider in EmulationStation.
            # (Re)enable should apply immediately; don't honor the color-picker block here.
            if (prev_enabled == "0" or not initialized):
                try:
                    led.set_brightness_conf()
                except Exception:
                    pass
                try:
                    led.set_color("ESCOLOR")
                except Exception:
                    pass
                # Also restore the status/battery LED immediately (it may have brightness=0 after disable).
                try:
                    bt, ch = read_battery_state()
                    block = get_status_colour_for_battery(led, ledconfig, bt, ch)
                    if hasattr(led, "set_status_color"):
                        led.set_status_color(block)
                    else:
                        led.set_color(block)
                except Exception:
                    pass
                initialized = True
            prev_enabled = enabled

            # ES sliders update batocera.conf live; force one refresh pass when they change.
            # On discharging devices this reapplies ESCOLOR, on charging it keeps status color policy.
            cur_es_color = batoled.batoconf("led.colour")
            cur_es_brightness = batoled.batoconf("led.brightness")
            cur_led_mode = current_led_mode()
            if cur_led_mode != prev_led_mode:
                animation_frame = 0
                prev_led_mode = cur_led_mode
            if cur_es_color != prev_es_color or cur_es_brightness != prev_es_brightness:
                try:
                    led.set_brightness_conf()
                except Exception:
                    pass
                try:
                    # Apply user-selected ES color immediately.
                    # This must not be gated by color_changes_allowed(), which is only for
                    # preventing daemon battery/status overrides during color picker activity.
                    led.set_color("ESCOLOR")
                except Exception:
                    pass
                prev_es_color = cur_es_color
                prev_es_brightness = cur_es_brightness
                prevblock = ""
        except Exception:
            pass

        try:
            bt, ch = read_battery_state()
            block = get_status_colour_for_battery(led, ledconfig, bt, ch)
            if hasattr(led, "set_status_color"):
                try:
                    led.set_status_color(block)
                    prevblock = block
                except Exception as e:
                    print(f"Error: {e}")
                if not color_changes_allowed():
                    time.sleep(animation_sleep_interval(led))
                    continue
                try:
                    if is_animated_led_mode():
                        animation_frame = apply_animated_led_frame(led, animation_frame)
                    else:
                        led.set_color("ESCOLOR")
                except Exception as e:
                    print(f"Error: {e}")
                time.sleep(animation_sleep_interval(led))
                continue

            if not color_changes_allowed():
                time.sleep(animation_sleep_interval(led))
                continue

            if is_animated_led_mode():
                try:
                    animation_frame = apply_animated_led_frame(led, animation_frame)
                    prevblock = ""
                except Exception as e:
                    print(f"Error: {e}")
                time.sleep(animation_sleep_interval(led))
                continue

            # Keep ESCOLOR in sync continuously for non-split devices so the
            # visible ring always follows ES sliders even if a prior update was missed.
            if block == "ESCOLOR":
                try:
                    if color_changes_allowed():
                        led.set_color("ESCOLOR")
                        prevblock = block
                except Exception as e:
                    print(f"Error: {e}")
            elif prevblock != block:
                try:
                    if DEBUG:
                        print(f"Set color to {block} for {bt}% ({ch})")
                    if color_changes_allowed():
                        if hasattr(led, "set_status_color"):
                            led.set_status_color(block)
                        else:
                            led.set_color(block)
                        prevblock = block
                except Exception as e:
                    print(f"Error: {e}")
            time.sleep(CHECK_INTERVAL)
        except Exception as e:
            print(f"Error reading battery status: {e}")
            time.sleep(CHECK_INTERVAL)

# Prevent color changes when entering color selection
def block_color_changes(block):
    with open(BLOCK_FILE, "w+") as fp:
        if block:
            fp.write(str(time.time()))
        else:
            fp.write("0")

def color_changes_allowed():
    try:
        with open(BLOCK_FILE, "r") as fp:
            line = fp.read().strip()
            diff = time.time() - float(line)
            if diff < LED_CHANGE_TIME:
                return (False)
        with open(BLOCK_FILE, "w+") as fp:
            fp.write("0")
        return (True)
    except:
        return (True)

# argument: start, stop, or no argument = show battery %
PATH = check_support()
if PATH == None:
    exit()
if len(sys.argv)>1:
    led = batoled.led()

    if sys.argv[1] == "start":
        try:
            led.set_brightness_conf()
            led_check(led)
        except Exception as e:
            print (f"Could not launch daemon: {e}")
    elif sys.argv[1] == "stop" or sys.argv[1] == "off":
        if hasattr(led, "turn_off_all"):
            led.turn_off_all()
        else:
            led.turn_off()
    elif sys.argv[1] == "retroachievement" or sys.argv[1] == "blink" or sys.argv[1] == "flash":
        if leds_runtime_enabled() and color_changes_allowed():
            block_color_changes(True)
            try:
                led.rainbow_effect()
            finally:
                block_color_changes(False)
    elif sys.argv[1] == "suspend_status":
        # Keep the status/power LED off during suspend. Battery indication resumes
        # on wake via the daemon; do not show a permanent amber "sleep" colour.
        if is_odin_sleep_status_device() and hasattr(led, "set_status_color"):
            led.set_status_color("OFF")
        elif is_odin_sleep_status_device() and hasattr(led, "set_status_sleep_amber"):
            led.set_status_sleep_amber(pulse=False)
    elif sys.argv[1] == "rainbow":
        os.system("batocera-settings-set led.mode rainbow >/dev/null 2>&1")
    elif sys.argv[1] == "chroma":
        os.system("batocera-settings-set led.mode chroma >/dev/null 2>&1")
    elif sys.argv[1] == "pulse":
        os.system("batocera-settings-set led.mode pulse >/dev/null 2>&1")
    elif sys.argv[1] == "set_color" and sys.argv[2] != None:
        # Explicit color requests (ES sliders/tests) should apply immediately.
        # The block window is only meant to prevent daemon-driven battery/status overrides.
        led.set_color(sys.argv[2])
    elif sys.argv[1] == "get_color":
        print(led.get_color())
    elif sys.argv[1] == "set_color_dec" and sys.argv[2] != None:
        # Explicit decimal RGB requests should bypass the temporary block, same as set_color_force_dec.
        rgb = ""
        for p in (sys.argv[2:]):
            rgb += str(p) + ' '
        led.set_color_dec(rgb)
    elif sys.argv[1] == "set_color_force_dec" and sys.argv[2] != None:
        rgb = ""
        for p in (sys.argv[2:]):
            rgb += str(p) + ' '
        led.set_color_dec(rgb)
    elif sys.argv[1] == "get_color_dec":
        print(led.get_color_dec())
    elif sys.argv[1] == "block_color_changes":
        block_color_changes(True)
    elif sys.argv[1] == "unblock_color_changes":
        block_color_changes(False)
    elif sys.argv[1] == "set_brightness" and sys.argv[2] != None:
        led.set_brightness(sys.argv[2])
    elif sys.argv[1] == "get_brightness":
        (b, m) = led.get_brightness()
        print(f'{b} {m}')
else:
    with open(PATH + '/capacity', 'r') as tp, \
            open(PATH + '/status','r') as st:
        bt = tp.readline().strip()
        ch = st.readline().strip()
        print (f"Battery: {bt}% ({ch})")
