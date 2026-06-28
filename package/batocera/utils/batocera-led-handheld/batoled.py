#!/usr/bin/env python3
"""
PWM + RGB unified LED driver 
Written for Batocera - @lbrpdx
Updated for kernel module updates - @dmanlfc
Updated for LED mode handling and Chroma - @dmanlfc
"""
import os
import time
import glob

DEBUG = 0            # set to 1 for debugging
EFFECT_STEP = 60     # how many colors in the effect
EFFECT_DURATION = 2  # how many seconds
PULSE_DURATION  = 1  # how many seconds
BLINK_COUNT = 2
BLINK_ON_DURATION = 0.12
BLINK_OFF_DURATION = 0.12
BATOCONFFILE = '/userdata/system/batocera.conf'
DEFAULT_ES_COLOR = '255 0 0'

def multicolor_led_paths():
    return sorted({
        os.path.dirname(path) + '/'
        for path in glob.glob('/sys/class/leds/*/multi_intensity')
    })

####################
# Is your handheld supported by this library?
def batocera_model():
    # Generic check for modern joystick ring LEDs from ayaneo-platform/ayn-platform
    if glob.glob('/sys/class/leds/*:rgb:joystick_rings/multi_intensity'):
        return "rgb"
    # Legion Go S check
    l = '/sys/class/leds/go_s:rgb:joystick_rings/effect'
    if os.path.exists(l):
        return("legiongos")
    # Standard RGB check
    l = '/sys/class/leds/multicolor:chassis/multi_intensity'
    if os.path.exists(l):
        return("rgb")
    # Thor/Odin3-style addressable rings can expose per-channel l:/r: LEDs
    # or grouped multicolor class LEDs such as rgb:l1/rgb:r1.
    has_multicolor_groups = bool(multicolor_led_paths())
    if glob.glob('/sys/class/leds/l:b?') and not has_multicolor_groups:
        return("rgbaddr")
    # Odin2/SM8550 power indicator LED or grouped multicolor accent LEDs.
    if has_multicolor_groups:
        return("rgb")
    # PWM check
    c = glob.glob('/sys/class/pwm/pwmchip*/device/name')
    for t in c:
        with open (t) as f:
            m = f.readline().strip()
            if m == 'htr3212-pwm':
                return("pwm")
    return("Unsupported")


####################
# Get a value from batocera.conf
def batoconf(key):
    try:
        with open(BATOCONFFILE) as f:
            for line in f:
                if not line.startswith(key+"="):
                    continue
                rest = line.split("=", 1)[1]
                nocomment = rest.split("#", 1)[0].strip()
                return(nocomment) # First one is enough
    except Exception:
        return None
    return None

def batoconf_color():
    rgb = batoconf("led.colour")
    if rgb == None:
        rgb = DEFAULT_ES_COLOR
    try:
        [ r, g, b ] = rgb.split(" ")
    except:
        if len (rgb) == 6:
            r, g, b = hex_to_dec(rgb[0:2]), hex_to_dec(rgb[2:4]), hex_to_dec(rgb[4:6])
        else:
            [ r, g, b ] = DEFAULT_ES_COLOR.split(" ")
    if DEBUG:
        print (f"batocera.conf said led.colour = {r} {g} {b}")
    return [ r, g, b ]


####################
# Handhelds that use the Lenovo Legion Go S interface
class legiongosled(object):
    def __init__(self):
        self.bpath           = '/sys/class/leds/go_s:rgb:joystick_rings/'
        self.effect_file     = self.bpath + 'effect'
        self.mode_file       = self.bpath + 'mode'
        self.speed_file      = self.bpath + 'speed'
        # NOTE: The following are standard kernel LED class files, assumed to exist
        self.color_file      = self.bpath + 'multi_intensity'
        self.brightness_file = self.bpath + 'brightness'
        self.max_brightness  = self.bpath + 'max_brightness'

        # Per documentation, mode must be 'custom' for Linux control
        try:
            with open(self.mode_file, 'w') as f:
                f.write('custom')
            if DEBUG:
                print("Set Legion Go S LED mode to 'custom'")
        except Exception as e:
            if DEBUG:
                print(f"Could not set Legion Go S mode: {e}")

    def set_color (self, rgb):
        if len(rgb) != 6 and rgb not in [ "PULSE", "RAINBOW", "CHROMA", "OFF", "ESCOLOR" ]:
            print (f'Error Color {rgb} is invalid')
            return

        # Always ensure the LEDs are on, unless explicitly turned off
        self.set_brightness_conf()

        try:
            if rgb == "PULSE":
                if DEBUG: print('Set effect to: breathe')
                with open (self.effect_file, 'w') as p: p.write('breathe')
                return
            elif rgb == "RAINBOW":
                if DEBUG: print('Set effect to: rainbow')
                with open (self.effect_file, 'w') as p: p.write('rainbow')
                return
            elif rgb == "CHROMA":
                if DEBUG: print('Set effect to: chroma')
                with open (self.effect_file, 'w') as p: p.write('chroma')
                return
            elif rgb == "OFF":
                self.turn_off()
                return

            # For static colors, set effect to monocolor first
            if DEBUG: print('Set effect to: monocolor')
            with open (self.effect_file, 'w') as p: p.write('monocolor')

            if rgb == "ESCOLOR":
                r, g, b = batoconf_color()
                out = f'{r} {g} {b}'
            else:
                r, g, b = rgb[0:2], rgb[2:4], rgb[4:6]
                out = f'{hex_to_dec(r)} {hex_to_dec(g)} {hex_to_dec(b)}'

            if DEBUG: print (f'Set color to: {out}')
            with open (self.color_file, 'w') as p:
                p.write(out)

        except Exception as e:
            if DEBUG:
                print(f'Error setting Legion Go S color: {e}')

    def get_color (self) -> str:
        try:
            with open (self.color_file, 'r') as p:
                rgb = p.readline().strip()
                [ r, g, b ] = rgb.split(" ")
                out = f'{dec_to_hex(r)}{dec_to_hex(g)}{dec_to_hex(b)}'
                return (out)
        except:
            return "000000"

    def set_color_dec (self, rgb):
        try:
            if DEBUG: print('Set effect to: monocolor')
            with open (self.effect_file, 'w') as p: p.write('monocolor')
            if DEBUG: print (f'Set color to: {rgb}')
            with open (self.color_file, 'w') as p:
                p.write(rgb)
        except Exception as e:
            if DEBUG: print(f"Error setting dec color: {e}")


    def get_color_dec (self) -> str:
        try:
            with open (self.color_file, 'r') as p:
                return p.readline().strip()
        except:
            return "0 0 0"

    def rainbow_effect(self):
        self.set_color("RAINBOW")

    def chroma_effect(self):
        self.set_color("CHROMA")

    def pulse_effect(self):
        self.set_color("PULSE")

    def blink_effect(self):
        prev = self.get_color()
        self.set_brightness_conf()
        for _ in range(BLINK_COUNT):
            self.set_color(prev)
            time.sleep(BLINK_ON_DURATION)
            self.turn_off()
            time.sleep(BLINK_OFF_DURATION)
        self.set_brightness_conf()
        self.set_color(prev)

    def turn_off(self):
        if DEBUG: print('Turning off LED')
        self.set_brightness(0)

    def set_brightness (self, b):
        try:
            with open (self.brightness_file, 'w') as p:
                p.write(str(b))
        except Exception as e:
            if DEBUG: print(f"Could not set brightness: {e}")

    def set_brightness_conf (self):
        conf = batoconf("led.brightness")
        if conf is None:
            conf = 100 
        try:
            with open(self.max_brightness, 'r') as m:
                max_v = int(m.readline().strip())
            
            percentage = max(0, min(100, float(conf)))
            scaled_value = int((percentage / 100.0) * max_v)
            self.set_brightness(scaled_value)
        except:
            self.set_brightness(255)

    def get_brightness (self):
        try:
            with open (self.brightness_file, 'r') as p:
                b = p.readline().strip()
            with open (self.max_brightness, 'r') as m:
                x = m.readline().strip()
            return (b, x)
        except:
            return ("-1", "-1")

####################
# Handhelds that use a direct RGB interface (easy peasy)
class rgbled(object):
    def __init__(self):
        self.bpath = None
        self.paths = []
        self.status_paths = []
        self.accent_paths = []
        
        # Use glob to find newer joystick ring LEDs dynamically
        found_paths = glob.glob('/sys/class/leds/*:rgb:joystick_rings/')
        if found_paths:
            self.paths = sorted(found_paths)
        else:
            # Odin2/SM8550 and Odin3/SM8750: multiple multicolor class LEDs.
            # Names vary by device: power-led, left-side, rgb:l1, rgb:r1, etc.
            self.paths = multicolor_led_paths()

        if self.bpath is None:
            if not self.paths:
                raise RuntimeError("Could not find a valid RGB LED sysfs path.")

        # Odin2-style split:
        # - status_paths: battery/indicator LED ("power-led")
        # - accent_paths: side/joystick RGB zones, whatever the kernel named them.
        for p in self.paths:
            if p.endswith('/power-led/'):
                self.status_paths.append(p)
            else:
                self.accent_paths.append(p)

        # Non-Odin layouts: keep legacy behavior by mirroring all paths.
        if not self.status_paths:
            self.status_paths = list(self.paths)
        if not self.accent_paths:
            self.accent_paths = list(self.paths)

        preferred_paths = self.accent_paths or self.status_paths or self.paths
        self.bpath = preferred_paths[0]
        self.base            = self.bpath + 'multi_intensity'
        self.brightness      = self.bpath + 'brightness'
        self.max_brightness  = self.bpath + 'max_brightness'

    def _set_paths_color(self, targets, out):
        for p in targets:
            # Some handheld LEDs (for example ROG Ally rings) expose more than
            # 3 channels and require full-length writes to multi_intensity.
            expanded = self._expand_color_for_path(p, out)
            brightness = self._path_max_brightness(p) if self._color_has_output(expanded) else 0
            self._set_paths_brightness([p], brightness)
            with open(p + 'multi_intensity', 'w') as f:
                f.write(expanded)

    def _color_has_output(self, out):
        try:
            return any(int(float(v)) > 0 for v in out.strip().split())
        except Exception:
            return False

    def _path_channels(self, p):
        try:
            with open(p + 'multi_index', 'r') as f:
                values = f.readline().strip().split()
                if values:
                    return values
        except Exception:
            pass
        try:
            with open(p + 'multi_intensity', 'r') as f:
                values = f.readline().strip().split()
                if values:
                    return ["red", "green", "blue"][:len(values)]
        except Exception:
            pass
        return ["red", "green", "blue"]

    def _brightness_scale(self):
        conf = batoconf("led.brightness")
        if conf is None:
            conf = 100
        try:
            return max(0.0, min(100.0, float(conf))) / 100.0
        except Exception:
            return 1.0

    def _parse_rgb_values(self, out):
        values = out.strip().split()
        if len(values) < 3:
            values = (values + ["0", "0", "0"])[:3]
        else:
            values = values[:3]
        parsed = []
        for value in values:
            try:
                parsed.append(max(0, min(255, int(float(value)))))
            except Exception:
                parsed.append(0)
        return parsed

    def _scale_rgb_values(self, values):
        scale = self._brightness_scale()
        return [str(max(0, min(255, int(v * scale)))) for v in values]

    def _expand_color_for_path(self, p, out):
        r, g, b = self._parse_rgb_values(out)
        ordered = {
            "red": r,
            "green": g,
            "blue": b,
            "white": max(r, g, b),
        }

        channels = self._path_channels(p)
        if len(channels) <= 3:
            return " ".join(self._scale_rgb_values([
                ordered.get(channel.lower(), 0)
                for channel in channels
            ]))

        values = [r, g, b]
        channel_count = len(channels)
        repeat = (channel_count + 2) // 3
        return " ".join(self._scale_rgb_values((values * repeat)[:channel_count]))

    def _set_paths_brightness(self, targets, b):
        for p in targets:
            with open(p + 'brightness', 'w') as f:
                f.write(str(b))

    def _path_max_brightness(self, p, default=255):
        try:
            with open(p + 'max_brightness', 'r') as m:
                return int(m.readline().strip())
        except Exception:
            return default

    def _set_paths_brightness_conf(self, targets):
        # Multicolor groups on some handhelds behave like on/off brightness gates;
        # actual dimming is applied by scaling multi_intensity in _set_paths_color().
        for p in targets:
            self._set_paths_brightness([p], self._path_max_brightness(p))

    def set_status_color(self, rgb):
        if len(rgb) != 6 and rgb not in [ "PULSE", "RAINBOW", "CHROMA", "OFF", "ESCOLOR" ]:
            print (f'Error Color {rgb} is invalid')
            return
        if rgb == "PULSE":
            # Keep status LED simple/stable for battery usage.
            rgb = "FF0000"
        elif rgb in ("RAINBOW", "CHROMA"):
            rgb = "ESCOLOR"
        elif rgb == "OFF":
            # Fully off (brightness + color), so it doesn't stay dark after re-enable.
            self._set_paths_brightness(self.status_paths, 0)
            self._set_paths_color(self.status_paths, "0 0 0")
            return
        elif rgb == "ESCOLOR":
            self._set_paths_brightness_conf(self.status_paths)
            r, g, b = batoconf_color()
            out = f'{r} {g} {b}'
            self._set_paths_color(self.status_paths, out)
            return
        # Ensure the status LED is visible (power-led brightness may be 0 after disable).
        self._set_paths_brightness_conf(self.status_paths)
        r, g, b = rgb[0:2], rgb[2:4], rgb[4:6]
        out = f'{hex_to_dec(r)} {hex_to_dec(g)} {hex_to_dec(b)}'
        self._set_paths_color(self.status_paths, out)

    def set_color (self, rgb):
        if len(rgb) != 6 and rgb not in [ "PULSE", "RAINBOW", "CHROMA", "OFF", "ESCOLOR" ]:
            print (f'Error Color {rgb} is invalid')
            return
        if rgb == "PULSE":
            self.pulse_effect()
            return
        elif rgb == "RAINBOW":
            self.rainbow_effect()
            return
        elif rgb == "CHROMA":
            self.chroma_effect()
            return
        elif rgb == "OFF":
            self.turn_off()
            return
        elif rgb == "ESCOLOR":
            r, g, b = batoconf_color()
            out = f'{r} {g} {b}'
        else:
            r, g, b = rgb[0:2], rgb[2:4], rgb[4:6]
            out = f'{hex_to_dec(r)} {hex_to_dec(g)} {hex_to_dec(b)}'
        if (DEBUG):
            print (f'Set color to: {out}')
        # User color/effects target accent LEDs on split-capable devices.
        self._set_paths_color(self.accent_paths, out)

    def get_color (self) -> str:
        with open (self.base, 'r') as p:
            rgb = p.readline().strip()
            values = rgb.split()
            if len(values) < 3:
                return "000000"
            channels = self._path_channels(self.bpath)
            channel_values = {
                channels[i].lower(): values[i]
                for i in range(min(len(channels), len(values)))
            }
            r = channel_values.get("red", values[0])
            g = channel_values.get("green", values[1])
            b = channel_values.get("blue", values[2])
            out = f'{dec_to_hex(r)}{dec_to_hex(g)}{dec_to_hex(b)}'
            return (out)

    def set_color_dec (self, rgb):
        if (DEBUG):
            print (f'Set color to: {rgb}')
        self._set_paths_color(self.accent_paths, rgb)

    def get_color_dec (self) -> str:
        with open (self.base, 'r') as p:
            rgb = p.readline().strip()
            values = rgb.split()
            if len(values) < 3:
                return "0 0 0"
            channels = self._path_channels(self.bpath)
            channel_values = {
                channels[i].lower(): values[i]
                for i in range(min(len(channels), len(values)))
            }
            r = channel_values.get("red", values[0])
            g = channel_values.get("green", values[1])
            b = channel_values.get("blue", values[2])
            out = f'{r} {g} {b}'
            return (out)

    def rainbow_effect(self):
        prev = self.get_color()
        for i in range (0, EFFECT_STEP):
            o = getRainbowRGB(float (i/EFFECT_STEP))
            self.set_color(o)
            time.sleep(EFFECT_DURATION/EFFECT_STEP)
        self.set_color(prev)

    def chroma_effect(self):
        self.rainbow_effect()

    def pulse_effect(self):
        prev = self.get_color()
        for i in range (0, EFFECT_STEP):
            o = getPulseRGB(i, EFFECT_STEP, prev)
            self.set_color(o)
            time.sleep(PULSE_DURATION/EFFECT_STEP)
        self.set_color(prev)

    def blink_effect(self):
        prev = self.get_color()
        self.set_brightness_conf()
        for _ in range(BLINK_COUNT):
            self.set_color(prev)
            time.sleep(BLINK_ON_DURATION)
            self._set_paths_color(self.accent_paths, "0 0 0")
            time.sleep(BLINK_OFF_DURATION)
        self.set_brightness_conf()
        self.set_color(prev)

    def turn_off(self):
        # User-facing OFF only blanks accent/ring LEDs. Split devices keep the
        # status LED under battery policy so power/charge indication stays visible.
        self._set_paths_color(self.accent_paths, "0 0 0")

    def turn_off_all(self):
        self._set_paths_brightness(self.status_paths, 0)
        self._set_paths_brightness(self.accent_paths, 0)
        self._set_paths_color(self.status_paths, "0 0 0")
        self._set_paths_color(self.accent_paths, "0 0 0")

    def set_brightness (self, b):
        self.set_color("ESCOLOR")

    def set_brightness_conf (self):
        self.set_color("ESCOLOR")

    def get_brightness (self):
        with open (self.brightness, 'r') as p:
            b = p.readline().strip()
        with open (self.max_brightness, 'r') as m:
            x = m.readline().strip()
        return (b, x)


####################
# Handhelds that use a PWM interface (trickier)
class pwmled(object):
    def __init__(self):
        c = glob.glob('/sys/class/pwm/pwmchip*')
        self.period = 100
        self.led = []
        for t in c:
            ret = self.pwmchip_init(t)
            if ret:
                self.led.append(ret)
        self.brightness     = -1
        self.max_brightness = -1

    def pwmchip_init (self, chip):
        self.base   = chip
        self.device = self.base + '/device/name'
        if not os.path.isdir(self.base):
            if (DEBUG):
                print ('PWM device driver not found: ' + self.base)
            return None
        try:
            with open (self.device) as f:
                m = f.readline().strip()
                if m != 'htr3212-pwm':
                    if (DEBUG):
                        print ('PWM device not a supported LED: ' + self.device)
                    return None
            with open (self.base + '/npwm') as f:
                npwm = int(f.readline().strip())
            if (npwm % 3) != 0:
                if (DEBUG):
                    print (f'Error: PWM is not a supported RGB LED: {npwm} pins')
                return None
            for i in range(npwm):
                p = self.base + f'/pwm{i}'
                if not os.path.isdir(p):
                    with open (self.base + '/export', 'w') as ex:
                        ex.write(str(i))
                with open (p + '/enable', 'w') as pe, \
                        open (p + '/period', 'w') as pp, \
                        open (p + '/duty_cycle', 'w') as pd:
                    pe.write('1')
                    pp.write(str(self.period))
                    # pd.write('0')
        except Exception as e:
            if (DEBUG):
                print('Error: PWM device is not a supported LED: {} ({})'.format(self.base, e))
            return None
        return (chip)

    def _get_factor(self):
        val = batoconf("led.brightness")
        if val is None: return 1.0
        try:
            return max(0, min(100, float(val))) / 100.0
        except: return 1.0

    def set_color (self, rgb):
        if len(rgb) != 6 and rgb not in [ "PULSE", "RAINBOW", "CHROMA", "OFF", "ESCOLOR" ]:
            print (f'Error Color {rgb} is invalid')
            return
        if rgb == "PULSE":
            self.pulse_effect()
            return
        elif rgb == "RAINBOW":
            self.rainbow_effect()
            return
        elif rgb == "CHROMA":
            self.chroma_effect()
            return
        elif rgb == "OFF":
            self.turn_off()
            return
        
        factor = self._get_factor()
        if rgb == "ESCOLOR":
            r_raw, g_raw, b_raw = batoconf_color()
        else:
            r_raw, g_raw, b_raw = hex_to_dec(rgb[0:2]), hex_to_dec(rgb[2:4]), hex_to_dec(rgb[4:6])

        r = str(int((int(r_raw)/255.0) * factor * self.period))
        g = str(int((int(g_raw)/255.0) * factor * self.period))
        b = str(int((int(b_raw)/255.0) * factor * self.period))

        if (DEBUG):
            print (f'Set color to: {r} {g} {b}')
        for l in self.led:
            for i in range (0, 12, 3):
                with open (l + f'/pwm{i}/duty_cycle', 'w') as p:
                    p.write(r)
            for i in range (1, 12, 3):
                with open (l + f'/pwm{i}/duty_cycle', 'w') as p:
                    p.write(g)
            for i in range (2, 12, 3):
                with open (l + f'/pwm{i}/duty_cycle', 'w') as p:
                    p.write(b)

    def get_color (self) -> str:
        if not self.led:
            return "000000"
        l = self.led[0]
        with open (l + f'/pwm0/duty_cycle', 'r') as p:
                r = p.readline().strip()
        with open (l + f'/pwm1/duty_cycle', 'r') as p:
                g = p.readline().strip()
        with open (l + f'/pwm2/duty_cycle', 'r') as p:
                b = p.readline().strip()
        out = f'{pwm_to_hex(r, self.period)}{pwm_to_hex(g, self.period)}{pwm_to_hex(b, self.period)}'
        return(out)

    def set_color_dec (self, rgb):
        int_list = [int(x) for x in rgb.split()]
        if len(int_list) != 3:
            print (f'Argument expects three ints for R G B, not {rgb}')
            return (1)
        
        factor = self._get_factor()
        r = str(int((int_list[0]/255.0) * factor * self.period))
        g = str(int((int_list[1]/255.0) * factor * self.period))
        b = str(int((int_list[2]/255.0) * factor * self.period))

        if (DEBUG):
            print (f'Set color to: {r} {g} {b}')
        for l in self.led:
            for i in range (0, 12, 3):
                with open (l + f'/pwm{i}/duty_cycle', 'w') as p:
                    p.write(r)
            for i in range (1, 12, 3):
                with open (l + f'/pwm{i}/duty_cycle', 'w') as p:
                    p.write(g)
            for i in range (2, 12, 3):
                with open (l + f'/pwm{i}/duty_cycle', 'w') as p:
                    p.write(b)

    def get_color_dec (self) -> str:
        l = self.led[0]
        with open (l + f'/pwm0/duty_cycle', 'r') as p:
                r = p.readline().strip()
        with open (l + f'/pwm1/duty_cycle', 'r') as p:
                g = p.readline().strip()
        with open (l + f'/pwm2/duty_cycle', 'r') as p:
                b = p.readline().strip()
        out = f'{pwm_to_dec(r, self.period)} {pwm_to_dec(g, self.period)} {pwm_to_dec(b, self.period)}'
        return(out)

    def rainbow_effect(self):
        prev = self.get_color()
        for i in range (0, EFFECT_STEP):
            o = getRainbowRGB(float (i/EFFECT_STEP))
            self.set_color(o)
            time.sleep(EFFECT_DURATION/EFFECT_STEP)
        self.set_color(prev)

    def chroma_effect(self):
        self.rainbow_effect()

    def pulse_effect(self):
        prev = self.get_color()
        for i in range (0, EFFECT_STEP):
            o = getPulseRGB(i, EFFECT_STEP, prev)
            self.set_color(o)
            time.sleep(PULSE_DURATION/EFFECT_STEP)
        self.set_color(prev)

    def blink_effect(self):
        prev = self.get_color()
        for _ in range(BLINK_COUNT):
            self.set_color(prev)
            time.sleep(BLINK_ON_DURATION)
            self.turn_off()
            time.sleep(BLINK_OFF_DURATION)
        self.set_color(prev)

    def turn_off(self):
        self.set_color("000000")

    def set_brightness (self, b):
        self.set_color("ESCOLOR")

    def set_brightness_conf (self):
        self.set_color("ESCOLOR")

    def ret_brightness (self):
        return (batoconf("led.brightness") or "100", str(self.period))

####################
# Handhelds that use a direct RGB interface with each LED addressable
class rgbledaddr(object):
    def __init__(self):
        # Use glob to find all red, green, and blue channels for both left (l) and right (r)
        self.all_r = sorted(glob.glob('/sys/class/leds/[lr]:r?/brightness'))
        self.all_g = sorted(glob.glob('/sys/class/leds/[lr]:g?/brightness'))
        self.all_b = sorted(glob.glob('/sys/class/leds/[lr]:b?/brightness'))
        
        # Determine hardware max brightness (usually 255)
        self.max_val = self._get_hw_max()

    def _get_hw_max(self):
        test_paths = self.all_r + self.all_g + self.all_b
        if test_paths:
            try:
                max_path = test_paths[0].replace('brightness', 'max_brightness')
                with open(max_path, 'r') as f:
                    return int(f.readline().strip())
            except: pass
        return 255 

    def _get_factor(self):
        val = batoconf("led.brightness")
        if val is None: 
            return 1.0
        try:
            # Strictly treat as percentage (0 to 100)
            f_val = float(val)
            f_val = max(0, min(100, f_val)) # Clamp to 0-100 range
            return f_val / 100.0
        except:
            return 1.0

    def _write_scaled(self, r, g, b):
        factor = self._get_factor()
        
        # Math: (Color_Input / 255) * User_Brightness_Percent * Hardware_Max_Limit
        rs = str(int((r / 255.0) * factor * self.max_val))
        gs = str(int((g / 255.0) * factor * self.max_val))
        bs = str(int((b / 255.0) * factor * self.max_val))
        
        # Batch write to all color-specific sysfs paths
        for path in self.all_r:
            try:
                with open(path, 'w') as f: f.write(rs)
            except: pass
        for path in self.all_g:
            try:
                with open(path, 'w') as f: f.write(gs)
            except: pass
        for path in self.all_b:
            try:
                with open(path, 'w') as f: f.write(bs)
            except: pass

    def turn_off(self):
        self._write_scaled(0, 0, 0)

    def set_color(self, rgb):
        if rgb == "OFF":
            self.turn_off()
        elif rgb == "ESCOLOR":
            r, g, b = batoconf_color()
            self._write_scaled(int(r), int(g), int(b))
        elif rgb == "RAINBOW":
            self.rainbow_effect()
        elif rgb == "CHROMA":
            self.chroma_effect()
        elif rgb == "PULSE":
            self.pulse_effect()
        elif len(rgb) == 6:
            r, g, b = hex_to_dec(rgb[0:2]), hex_to_dec(rgb[2:4]), hex_to_dec(rgb[4:6])
            self._write_scaled(r, g, b)

    def set_color_dec(self, rgb_str):
        try:
            r, g, b = [int(x) for x in rgb_str.split()]
            self._write_scaled(r, g, b)
        except: pass

    def get_color(self):
        try:
            with open(self.all_r[0], 'r') as f: r = int(f.readline().strip())
            with open(self.all_g[0], 'r') as f: g = int(f.readline().strip())
            with open(self.all_b[0], 'r') as f: b = int(f.readline().strip())
            # Convert hardware-specific value back to standard 255-scale for the UI
            r_norm = int((r / self.max_val) * 255)
            g_norm = int((g / self.max_val) * 255)
            b_norm = int((b / self.max_val) * 255)
            return f"{dec_to_hex(r_norm)}{dec_to_hex(g_norm)}{dec_to_hex(b_norm)}"
        except: return "000000"

    def get_color_dec(self):
        try:
            with open(self.all_r[0], 'r') as f: r = f.readline().strip()
            with open(self.all_g[0], 'r') as f: g = f.readline().strip()
            with open(self.all_b[0], 'r') as f: b = f.readline().strip()
            return f"{r} {g} {b}"
        except: return "0 0 0"

    def rainbow_effect(self):
        for i in range(0, EFFECT_STEP):
            o_hex = getRainbowRGB(float(i/EFFECT_STEP))
            r, g, b = hex_to_dec(o_hex[0:2]), hex_to_dec(o_hex[2:4]), hex_to_dec(o_hex[4:6])
            self._write_scaled(r, g, b)
            time.sleep(EFFECT_DURATION/EFFECT_STEP)

    def chroma_effect(self):
        self.rainbow_effect()

    def pulse_effect(self):
        # Get the 'base' color from config to pulse against
        r_base, g_base, b_base = batoconf_color()
        for i in range(0, EFFECT_STEP):
            # Calculate pulse intensity
            if i < EFFECT_STEP/2:
                coeff = float(1 - 2*i/EFFECT_STEP)
            else:
                coeff = float((i - EFFECT_STEP/2) / (EFFECT_STEP/2))
            
            # Apply pulse coefficient AND brightness factor via _write_scaled
            self._write_scaled(int(int(r_base)*coeff), int(int(g_base)*coeff), int(int(b_base)*coeff))
            time.sleep(PULSE_DURATION/EFFECT_STEP)

    def blink_effect(self):
        prev = self.get_color()
        for _ in range(BLINK_COUNT):
            self.set_color(prev)
            time.sleep(BLINK_ON_DURATION)
            self.turn_off()
            time.sleep(BLINK_OFF_DURATION)
        self.set_color(prev)

    def set_brightness(self, b):
        self.set_color("ESCOLOR")

    def set_brightness_conf(self):
        self.set_color("ESCOLOR")

    def get_brightness(self):
        return (batoconf("led.brightness") or "100", str(self.max_val))

####################
# Unified class for Batocera handhelds
class led(object):
    def __new__(cls):
        m = batocera_model()
        if m == "pwm":
            return pwmled()
        elif m == "rgb":
            return rgbled()
        elif m == "rgbaddr":
            return rgbledaddr()
        elif m == "legiongos":
            return legiongosled()
        else:
            print(m)

####################
# Helper functions and effects
def dec_to_hex(i):
    return f'{int(i):0>2X}'

def hex_to_dec(hx):
    return int('0x'+hx, 16)

def hex_to_pwm(hx, period):
    return int(float((int('0x'+hx, 16)/255)*period))

def pwm_to_hex(i, period):
    return f'{int(255*float(i)/period):0>2X}'

def dec_to_pwm(d, period):
    return int(float((int(d)/255)*period))

def pwm_to_dec(i, period):
    return f'{int(255*float(i)/period)}'

def getAngleDiff(a, b):
    return (a < b and a+360-b or a-b)

def getRainbowRGB(num):
    angle = num*360 # num = starting point between 0 and 1 (randomized)
    comp = []
    for i in range(0, 3):
        startAngle = ((i+1)*120)%360
        diffFromStart = getAngleDiff(angle, startAngle)
        if diffFromStart < 60:
            comp.append(int(diffFromStart/60*255))
        elif diffFromStart <= 180:
            comp.append(255)
        elif diffFromStart < 240:
            comp.append(int((240-diffFromStart)/60*255))
        else:
            comp.append(0)
    out = f'{comp[0]:0>2X}{comp[1]:0>2X}{comp[2]:0>2X}'
    return (out)

def getPulseRGB(num, step, rgb): # num = order from 0 to step
    r, g, b = hex_to_dec(rgb[0:2]), hex_to_dec(rgb[2:4]), hex_to_dec(rgb[4:6])
    if num < step/2:
        coeff = float(1-2*num/step)
    else:
        coeff = float((num-step/2)/(step/2))
    nr, ng, nb = int(coeff*float(r)), int(coeff*float(g)), int(coeff*float(b))
    out = f'{nr:0>2X}{ng:0>2X}{nb:0>2X}'
    return (out)

####################
# if invoked as a command line: respond with supported Model, or None
if __name__ == '__main__':
    print (batocera_model())
