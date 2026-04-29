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
You can use PULSE, RAINBOW and OFF as rgb_color for special effects.

ESCOLOR is the default one set with sliders in EmulationStation

RetroAchievements unlocks are hooked automatically by the package and will blink
the device LEDs when LEDs are enabled in Batocera.

"""
import os
import time
import sys
import glob
import batoled
from threading import Thread

DEBUG = 0
CHECK_INTERVAL  = 1  # seconds between two checks (kept low for responsive ES LED slider updates)
LED_CHANGE_TIME = 120 # seconds to prevent changes while entering the settings menu
CONFIG_FILE='/userdata/system/configs/leds.conf'
BLOCK_FILE='/var/run/led-handheld-block'

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
        # read_color() uses >= threshold matching, so we express "at/under X%" cutoffs by placing
        # the next bucket just above X (ex: 21 for "above 20%").
        # - Charging: amber (100 bucket is used when status == Charging)
        # - <=20%: yellow
        # - <=5%: red (solid)
        # - <=3%: pulse
        return ["100=FFAA00", "21=00FF00", "6=FFFF00", "4=FF0000", "3=PULSE", "0=FF0000"]
    # Legacy behavior: use ES accent colour for normal battery levels.
    return ["100=009900", "15=ESCOLOR", "10=CC3333", "5=FF0000", "3=PULSE"]

def read_battery_state():
    with open(PATH + '/capacity', 'r') as tp, open(PATH + '/status','r') as st:
        bt = tp.readline().strip()
        ch = st.readline().strip()
        return bt, ch

def get_status_colour_for_battery(ledconfig, bt, ch):
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

# Check the current battery level and adjust led color
def led_check(led):
    ledconfig = default_led_config_for(led)
    tmpconfig = load_config(CONFIG_FILE)
    if len(tmpconfig) > 0:
        ledconfig = tmpconfig
    if (DEBUG):
        print(ledconfig)
    prevblock = 0
    prev_enabled = None
    prev_es_color = batoled.batoconf("led.colour")
    prev_es_brightness = batoled.batoconf("led.brightness")
    initialized = False
    while True:
        try:
            enabled = "1" if leds_runtime_enabled() else "0"
            if enabled == "0":
                # User explicitly disabled LEDs: always turn them off immediately,
                # even if we're currently "blocking" color changes for the ES color picker.
                if prev_enabled != "0":
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
                    block = get_status_colour_for_battery(ledconfig, bt, ch)
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
            block = get_status_colour_for_battery(ledconfig, bt, ch)
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
            t = Thread(target=led_check, args=(led,))
            t.start()
        except Exception as e:
            print (f"Could not launch daemon: {e}")
            t.stop()
    elif sys.argv[1] == "stop" or sys.argv[1] == "off":
        led.turn_off()
    elif sys.argv[1] == "retroachievement" or sys.argv[1] == "blink":
        if leds_runtime_enabled() and color_changes_allowed():
            led.blink_effect()
    elif sys.argv[1] == "rainbow":
        if leds_runtime_enabled() and color_changes_allowed():
            led.rainbow_effect()
    elif sys.argv[1] == "pulse":
        if leds_runtime_enabled() and color_changes_allowed():
            led.pulse_effect()
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
