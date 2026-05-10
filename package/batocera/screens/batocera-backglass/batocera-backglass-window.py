#!/usr/bin/env python3

import os

os.environ["GDK_BACKEND"] = "x11"
os.environ.pop("GDK_GL", None)
os.environ.pop("GSK_RENDERER", None)
os.environ.pop("LIBGL_ALWAYS_SOFTWARE", None)
os.environ.setdefault("WEBKIT_DISABLE_COMPOSITING_MODE", "1")
os.environ.setdefault("WEBKIT_DISABLE_DMABUF_RENDERER", "1")
os.environ.setdefault("WEBKIT_DMABUF_RENDERER_DISABLE_GBM", "1")

import webview
from http.server  import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse
from urllib.parse import parse_qs
import urllib.request
import json
import hashlib
import argparse
import re
import glob
import subprocess
import time
import signal
import traceback

class BackglassAPI(BaseHTTPRequestHandler):

    imgvideo_extensions = ["png", "jpg", "gif", "avi", "mp4"]
    imgvideo_properties = ["image", "video", "marquee", "thumbnail", "fanart", "manual", "titleshot", "bezel", "magazine", "manual", "boxart", "boxback", "wheel", "mix"]
    record_pidfile = "/var/run/batocera-backglass-record.pid"
    record_logfile = "/var/log/batocera-backglass-record.log"
    api_logfile = "/var/log/batocera-backglass-window.log"
    flycast_vmu_prefix = "/var/run/flycast-vmu"
    cached_model = None
    last_cpu_total = None
    last_cpu_idle = None
    last_gpu_busy = {}

    def sendHeaders(self, contentType):
        self.send_response(200)
        self.send_header("Content-type", contentType)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

    def log_message(self, format, *args):
        try:
            with open(BackglassAPI.api_logfile, "a") as fp:
                fp.write("{} {}\n".format(
                    time.strftime("%Y-%m-%d %H:%M:%S"),
                    format % args
                ))
        except Exception:
            pass

    def readFile(path):
        try:
            with open(path, "r") as fd:
                return fd.read().strip()
        except Exception:
            return ""

    def readBinaryFile(path):
        try:
            with open(path, "rb") as fd:
                return fd.read()
        except Exception:
            return b""

    def runCommand(cmd):
        try:
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=1)
            return res.stdout.strip()
        except Exception:
            return ""

    def getFlycastVmu(slot):
        slot = (slot or "A1").upper()
        if slot not in ("A1", "A2", "B1", "B2", "C1", "C2", "D1", "D2"):
            slot = "A1"

        path = "{}-{}.raw".format(BackglassAPI.flycast_vmu_prefix, slot)
        data = BackglassAPI.readBinaryFile(path)
        if len(data) != 48 * 32:
            data = b"\x00" * (48 * 32)
        return data

    def runCommandResult(cmd):
        try:
            return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=3)
        except Exception:
            return None

    def setupWaylandEnv():
        runtime_dirs = (
            os.environ.get("XDG_RUNTIME_DIR", ""),
            "/var/run/0-runtime-dir",
            "/run/0-runtime-dir",
            "/run/user/0",
            "/run/user/1000",
        )

        for runtime in runtime_dirs:
            if not runtime:
                continue
            if not os.path.isdir(runtime):
                continue

            wayland = os.environ.get("WAYLAND_DISPLAY", "")
            if not wayland or not os.path.exists(os.path.join(runtime, wayland)):
                for candidate in sorted(glob.glob(os.path.join(runtime, "wayland-*"))):
                    if os.path.exists(candidate):
                        os.environ["WAYLAND_DISPLAY"] = os.path.basename(candidate)
                        break

            if os.environ.get("WAYLAND_DISPLAY") and os.path.exists(os.path.join(runtime, os.environ["WAYLAND_DISPLAY"])):
                os.environ["XDG_RUNTIME_DIR"] = runtime
                break

        runtime = os.environ.get("XDG_RUNTIME_DIR", "")
        if runtime and not os.environ.get("SWAYSOCK"):
            sockets = sorted(glob.glob(os.path.join(runtime, "sway-ipc.*.sock")))
            if sockets:
                os.environ["SWAYSOCK"] = sockets[0]
                os.environ["I3SOCK"] = sockets[0]

        if os.environ.get("WAYLAND_DISPLAY"):
            os.environ.setdefault("XDG_SESSION_TYPE", "wayland")
            os.environ.setdefault("XDG_CURRENT_DESKTOP", "sway")

    def getCpuTemp():
        temps = []
        for path in glob.glob("/sys/class/thermal/thermal_zone*/temp"):
            raw = BackglassAPI.readFile(path)
            try:
                value = int(raw)
                if value > 1000:
                    value = value / 1000
                if value > 0:
                    temps.append(round(value, 1))
            except Exception:
                pass
        if len(temps) == 0:
            return None
        return max(temps)

    def getBattery():
        paths = []
        for path in glob.glob("/sys/class/power_supply/*"):
            supply_type = BackglassAPI.readFile(os.path.join(path, "type")).lower()
            if supply_type == "battery" and os.path.exists(os.path.join(path, "capacity")):
                paths.append(path)
        if not paths:
            paths = glob.glob("/sys/class/power_supply/BAT*")

        for path in paths:
            capacity = BackglassAPI.readFile(os.path.join(path, "capacity"))
            status = BackglassAPI.readFile(os.path.join(path, "status"))
            try:
                capacity = int(capacity)
            except Exception:
                capacity = None
            return {"percent": capacity, "status": status}
        return {"percent": None, "status": ""}

    def getBrightness():
        values = []
        for path in glob.glob("/sys/class/backlight/*"):
            try:
                brightness = int(BackglassAPI.readFile(os.path.join(path, "brightness")))
                max_brightness = int(BackglassAPI.readFile(os.path.join(path, "max_brightness")))
                if max_brightness > 0:
                    values.append(round(brightness * 100 / max_brightness))
            except Exception:
                pass
        if len(values) == 0:
            return None
        return min(values)

    def getMemory():
        total = 0
        available = 0
        for line in BackglassAPI.readFile("/proc/meminfo").splitlines():
            parts = line.split()
            if len(parts) < 2:
                continue
            if parts[0] == "MemTotal:":
                total = int(parts[1])
            elif parts[0] == "MemAvailable:":
                available = int(parts[1])
        used = max(total - available, 0)
        percent = round(used * 100 / total) if total > 0 else None
        return {"total_mb": round(total / 1024), "used_mb": round(used / 1024), "percent": percent}

    def getCpuUsage():
        lines = BackglassAPI.readFile("/proc/stat").splitlines()
        if not lines:
            return {"percent": None}
        parts = lines[0].split()
        if len(parts) < 5 or parts[0] != "cpu":
            return {"percent": None}

        values = [int(value) for value in parts[1:]]
        idle = values[3] + (values[4] if len(values) > 4 else 0)
        total = sum(values)

        percent = None
        if BackglassAPI.last_cpu_total is not None:
            total_delta = total - BackglassAPI.last_cpu_total
            idle_delta = idle - BackglassAPI.last_cpu_idle
            if total_delta > 0:
                percent = round(100 * (total_delta - idle_delta) / total_delta)

        BackglassAPI.last_cpu_total = total
        BackglassAPI.last_cpu_idle = idle
        return {"percent": percent}

    def parseFirstInt(value):
        match = re.search(r"-?\d+", value or "")
        if match:
            try:
                return int(match.group(0))
            except Exception:
                return None
        return None

    def getTopOutput():
        BackglassAPI.setupWaylandEnv()
        raw = BackglassAPI.runCommand(["swaymsg", "-t", "get_outputs"])
        if not raw:
            return None

        try:
            outputs = json.loads(raw)
        except Exception:
            return None

        active = [output for output in outputs if output.get("active")]
        if not active:
            return None

        for output in active:
            if output.get("name") == "DSI-2":
                return output.get("name")

        active.sort(key=lambda output: (
            output.get("rect", {}).get("y", 0),
            output.get("rect", {}).get("x", 0),
        ))
        return active[0].get("name")

    def captureScreenshot(target):
        outdir = "/userdata/screenshots"
        os.makedirs(outdir, exist_ok=True)

        prefix = "top-screen" if target == "top" else "screenshot"
        filename = "{}-{}.png".format(prefix, time.strftime("%Y.%m.%d-%Hh%M.%S"))
        path = os.path.join(outdir, filename)

        if target == "top":
            BackglassAPI.setupWaylandEnv()
            output = BackglassAPI.getTopOutput()
            if output:
                result = BackglassAPI.runCommandResult(["grim", "-o", output, path])
            else:
                result = BackglassAPI.runCommandResult(["batocera-screenshot", path])
        else:
            result = BackglassAPI.runCommandResult(["batocera-screenshot", path])

        if result is None or result.returncode != 0 or not os.path.exists(path):
            return {
                "ok": False,
                "path": "",
                "error": result.stderr.strip() if result and result.stderr else "screenshot failed",
            }

        BackglassAPI.runCommandResult(["batocera-flash-screen"])
        return {"ok": True, "path": path, "error": ""}

    def killEmulator():
        result = BackglassAPI.runCommandResult(["batocera-es-swissknife", "--emukill", "0.5"])
        if result is None:
            return {"ok": False, "code": -1, "message": "failed to run emukill"}

        message = (result.stdout or result.stderr or "").strip()
        return {
            "ok": result.returncode in (0, 20, 22, 25),
            "code": result.returncode,
            "message": message,
        }

    def getRecordPid():
        pid = BackglassAPI.parseFirstInt(BackglassAPI.readFile(BackglassAPI.record_pidfile))
        if not pid:
            return None

        if BackglassAPI.readFile("/proc/{}/stat".format(pid)).split()[2:3] == ["Z"]:
            try:
                os.waitpid(pid, os.WNOHANG)
            except Exception:
                pass
            try:
                os.unlink(BackglassAPI.record_pidfile)
            except Exception:
                pass
            return None

        try:
            os.kill(pid, 0)
            return pid
        except Exception:
            try:
                os.unlink(BackglassAPI.record_pidfile)
            except Exception:
                pass
            return None

    def startRecording():
        pid = BackglassAPI.getRecordPid()
        if pid:
            return {"ok": True, "recording": True, "pid": pid, "message": "already recording"}

        BackglassAPI.setupWaylandEnv()
        try:
            os.makedirs(os.path.dirname(BackglassAPI.record_logfile), exist_ok=True)
            log = open(BackglassAPI.record_logfile, "a")
            proc = subprocess.Popen(
                ["batocera-record", "--ultra-fast"],
                stdout=log,
                stderr=log,
                stdin=subprocess.DEVNULL,
                start_new_session=True,
            )
            with open(BackglassAPI.record_pidfile, "w") as fp:
                fp.write(str(proc.pid))
            return {"ok": True, "recording": True, "pid": proc.pid, "message": "recording started"}
        except Exception as e:
            return {"ok": False, "recording": False, "pid": None, "message": str(e)}

    def stopRecording():
        pid = BackglassAPI.getRecordPid()
        if not pid:
            return {"ok": True, "recording": False, "pid": None, "message": "not recording"}

        try:
            os.killpg(pid, signal.SIGINT)
            for _ in range(20):
                try:
                    waited, _ = os.waitpid(pid, os.WNOHANG)
                    if waited == pid:
                        break
                except ChildProcessError:
                    break
                except Exception:
                    pass
                try:
                    os.kill(pid, 0)
                    time.sleep(0.1)
                except Exception:
                    break
            else:
                os.killpg(pid, signal.SIGTERM)
                try:
                    os.waitpid(pid, 0)
                except Exception:
                    pass
        except Exception as e:
            return {"ok": False, "recording": True, "pid": pid, "message": str(e)}

        try:
            os.unlink(BackglassAPI.record_pidfile)
        except Exception:
            pass
        return {"ok": True, "recording": False, "pid": pid, "message": "recording stopped"}

    def readFreq(path):
        value = BackglassAPI.parseFirstInt(BackglassAPI.readFile(path))
        if value is None or value <= 0:
            return None
        return value

    def getGpuFromKgslBusy(path):
        raw = BackglassAPI.readFile(path).split()
        if len(raw) < 2:
            return None
        try:
            busy = int(raw[0])
            total = int(raw[1])
        except Exception:
            return None

        last = BackglassAPI.last_gpu_busy.get(path)
        BackglassAPI.last_gpu_busy[path] = (busy, total)
        if last is None:
            return None

        busy_delta = busy - last[0]
        total_delta = total - last[1]
        if total_delta <= 0:
            return None
        return round(max(0, min(100, 100 * busy_delta / total_delta)))

    def getGpuStats():
        for path in (
            "/sys/class/kgsl/kgsl-3d0/gpu_busy_percentage",
            "/sys/kernel/debug/dri/0/gpu_busy",
            "/sys/kernel/debug/dri/1/gpu_busy",
        ):
            value = BackglassAPI.parseFirstInt(BackglassAPI.readFile(path))
            if value is not None:
                return {"percent": max(0, min(100, value)), "source": "busy"}

        for path in glob.glob("/sys/class/kgsl/kgsl-3d0/gpubusy"):
            value = BackglassAPI.getGpuFromKgslBusy(path)
            if value is not None:
                return {"percent": value, "source": "busy"}

        for path in glob.glob("/sys/class/devfreq/*gpu*"):
            cur = BackglassAPI.readFreq(os.path.join(path, "cur_freq"))
            max_freq = BackglassAPI.readFreq(os.path.join(path, "max_freq"))
            if max_freq is None:
                freqs = []
                for value in BackglassAPI.readFile(os.path.join(path, "available_frequencies")).split():
                    try:
                        freqs.append(int(value))
                    except Exception:
                        pass
                if freqs:
                    max_freq = max(freqs)
            if cur is not None and max_freq is not None and max_freq > 0:
                return {
                    "percent": round(max(0, min(100, 100 * cur / max_freq))),
                    "mhz": round(cur / 1000000),
                    "max_mhz": round(max_freq / 1000000),
                    "source": "clock"
                }

        return {"percent": None, "source": ""}

    def qcomFanDaemonRunning():
        def matches(pid):
            if pid == os.getpid():
                return False
            try:
                with open("/proc/{}/cmdline".format(pid), "rb") as fp:
                    raw = fp.read().decode("utf-8", "ignore")
                return "qcom-fan" in raw and "\0start" in raw
            except Exception:
                return False

        pid = BackglassAPI.parseFirstInt(BackglassAPI.readFile("/var/run/qcom-fan.pid"))
        if pid and matches(pid):
            return True
        for path in glob.glob("/proc/[0-9]*"):
            pid = BackglassAPI.parseFirstInt(os.path.basename(path))
            if pid and matches(pid):
                return True
        return False

    def getFanStats():
        hwmon_candidates = []
        for base in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
            fan_inputs = sorted(glob.glob(os.path.join(base, "fan*_input")))
            pwms = [
                path for path in sorted(glob.glob(os.path.join(base, "pwm[0-9]*")))
                if not path.endswith("_enable")
            ]
            if not fan_inputs and not pwms:
                continue
            name = BackglassAPI.readFile(os.path.join(base, "name"))
            score = 0
            if "fan" in name.lower():
                score += 20
            if fan_inputs:
                score += 5
            if pwms:
                score += 5
            if any(os.access(path, os.W_OK) for path in pwms):
                score += 5
            hwmon_candidates.append({
                "score": score,
                "base": base,
                "name": name,
                "fan_inputs": fan_inputs,
                "pwms": pwms,
            })
        hwmon_candidates.sort(key=lambda item: item["score"], reverse=True)

        rpm = None
        percent = None
        mode = ""
        name = ""
        control = False
        enable = None
        if hwmon_candidates:
            hwmon = hwmon_candidates[0]
            name = hwmon["name"] or os.path.basename(hwmon["base"])
            if hwmon["fan_inputs"]:
                rpm = BackglassAPI.parseFirstInt(BackglassAPI.readFile(hwmon["fan_inputs"][0]))
            if hwmon["pwms"]:
                pwm_path = hwmon["pwms"][0]
                pwm = BackglassAPI.parseFirstInt(BackglassAPI.readFile(pwm_path))
                if pwm is not None:
                    percent = round(max(0, min(255, pwm)) * 100 / 255)
                enable = BackglassAPI.parseFirstInt(BackglassAPI.readFile(pwm_path + "_enable"))
                control = os.access(pwm_path, os.W_OK)

        if percent is None:
            for base in sorted(glob.glob("/sys/class/thermal/cooling_device*")):
                ctype = BackglassAPI.readFile(os.path.join(base, "type"))
                if "fan" not in ctype.lower():
                    continue
                cur = BackglassAPI.parseFirstInt(BackglassAPI.readFile(os.path.join(base, "cur_state")))
                max_state = BackglassAPI.parseFirstInt(BackglassAPI.readFile(os.path.join(base, "max_state")))
                if cur is not None and max_state and max_state > 0:
                    percent = round(max(0, min(max_state, cur)) * 100 / max_state)
                    name = name or ctype
                    control = control or os.access(os.path.join(base, "cur_state"), os.W_OK)
                    break

        available = bool(hwmon_candidates or name)
        if BackglassAPI.qcomFanDaemonRunning():
            mode = "auto"
        elif enable == 2:
            mode = "driver auto"
        elif control:
            mode = "manual"
        elif available:
            mode = "read only"

        return {
            "available": available,
            "control": control,
            "name": name,
            "rpm": rpm,
            "percent": percent,
            "mode": mode,
        }

    def getStorage(path):
        try:
            stat = os.statvfs(path)
            total = stat.f_blocks * stat.f_frsize
            free = stat.f_bavail * stat.f_frsize
            used = total - free
            return {
                "total_gb": round(total / 1024 / 1024 / 1024, 1),
                "free_gb": round(free / 1024 / 1024 / 1024, 1),
                "percent": round(used * 100 / total) if total > 0 else None
            }
        except Exception:
            return {"total_gb": None, "free_gb": None, "percent": None}

    def getStats():
        load = BackglassAPI.readFile("/proc/loadavg").split()
        uptime_seconds = 0
        try:
            uptime_seconds = int(float(BackglassAPI.readFile("/proc/uptime").split()[0]))
        except Exception:
            pass
        if BackglassAPI.cached_model is None:
            BackglassAPI.cached_model = BackglassAPI.runCommand(["batocera-model"])

        return {
            "model": BackglassAPI.cached_model,
            "time": time.strftime("%H:%M"),
            "date": time.strftime("%a %b %d"),
            "uptime_seconds": uptime_seconds,
            "load": load[:3],
            "cpu": BackglassAPI.getCpuUsage(),
            "cpu_temp_c": BackglassAPI.getCpuTemp(),
            "gpu": BackglassAPI.getGpuStats(),
            "fan": BackglassAPI.getFanStats(),
            "memory": BackglassAPI.getMemory(),
            "battery": BackglassAPI.getBattery(),
            "brightness": BackglassAPI.getBrightness(),
            "userdata": BackglassAPI.getStorage("/userdata")
        }

    def gameShortName(path):
        # just filename without extension
        res = os.path.splitext(os.path.basename(path))[0]
        # remove anything in parenthesis
        res = re.sub(r"\([^)]*\)", "", res)
        # remove anything non alpha
        res = re.sub(r"[^A-Za-z0-9]", "", res)
        # lowercase
        return res.lower()

    def do_GET(self):

        try:
            query = urlparse(self.path)
            qs = parse_qs(query.query)

            if query.path == "/game":
                self.sendHeaders("text/plain")
                system = qs["system"][0]
                path   = qs["path"][0]
                hash   = hashlib.md5(path.encode('utf-8')).hexdigest()
                data   = {}
                with urllib.request.urlopen("http://localhost:1234/systems/{}/games/{}".format(system, hash)) as url:
                    data = json.load(url)
                    for prop in BackglassAPI.imgvideo_properties:
                        if prop in data:
                            shortname = BackglassAPI.gameShortName(path)
                            for ext in BackglassAPI.imgvideo_extensions:
                                if os.path.exists("/userdata/system/backglass/systems/{}/games/{}/{}.{}".format(system, prop, shortname, ext)):
                                    data[prop] = "http://localhost:2033/static/images/systems/{}/games/{}/{}.{}".format(system, prop, shortname, ext)
                                    break
                            else:
                                data[prop] = "http://localhost:1234" + data[prop]
                    window.evaluate_js("onGame(" + json.dumps(data) + ")")
                self.wfile.write(bytes("OK\n", "utf-8"))

            elif query.path == "/system":
                self.sendHeaders("text/plain")
                system = qs["system"][0]
                data   = {}
                with urllib.request.urlopen("http://localhost:1234/systems/{}".format(system)) as url:
                    data = json.load(url)
                    for prop in ["logo"]:
                        if prop in data:
                            for ext in BackglassAPI.imgvideo_extensions:
                                if os.path.exists("/userdata/system/backglass/systems/{}/{}.{}".format(system, prop, ext)):
                                    data[prop] = "http://localhost:2033/static/images/systems/{}/{}.{}".format(system, prop, ext)
                                    break
                            else:
                                data[prop] = "http://localhost:1234" + data[prop]

                    window.evaluate_js("onSystem(" + json.dumps(data) + ")")
                self.wfile.write(bytes("OK\n", "utf-8"))

            elif query.path == "/location":
                self.sendHeaders("text/plain")
                url = qs["url"][0]
                window.load_url(url)

            elif query.path == "/stats":
                self.sendHeaders("application/json")
                self.wfile.write(bytes(json.dumps(BackglassAPI.getStats()), "utf-8"))

            elif query.path == "/flycast-vmu":
                self.sendHeaders("application/octet-stream")
                slot = qs.get("slot", ["A1"])[0]
                self.wfile.write(BackglassAPI.getFlycastVmu(slot))

            elif query.path == "/screenshot":
                self.sendHeaders("application/json")
                target = qs.get("target", ["current"])[0]
                self.wfile.write(bytes(json.dumps(BackglassAPI.captureScreenshot(target)), "utf-8"))

            elif query.path == "/emukill":
                self.sendHeaders("application/json")
                self.wfile.write(bytes(json.dumps(BackglassAPI.killEmulator()), "utf-8"))

            elif query.path == "/record-start":
                self.sendHeaders("application/json")
                self.wfile.write(bytes(json.dumps(BackglassAPI.startRecording()), "utf-8"))

            elif query.path == "/record-stop":
                self.sendHeaders("application/json")
                self.wfile.write(bytes(json.dumps(BackglassAPI.stopRecording()), "utf-8"))

            elif query.path.startswith("/static/images/"):
                if ".." not in  query.path: # don't allow to escape
                    with open("/userdata/system/backglass/{}".format(query.path[15:]), "rb") as fd:
                        if query.path.endswith(".png"):
                            self.sendHeaders("image/png")
                        elif query.path.endswith(".jpg"):
                            self.sendHeaders("image/jpeg")
                        elif query.path.endswith(".gif"):
                            self.sendHeaders("image/gif")
                        elif query.path.endswith(".mp4"):
                            self.sendHeaders("video/mp4")
                        elif query.path.endswith(".avi"):
                            self.sendHeaders("video/mpeg") # hum
                        else:
                            raise Exception("Invalid extension")
                        self.wfile.write(fd.read())

        except Exception as e:
            try:
                with open(BackglassAPI.api_logfile, "a") as fp:
                    fp.write(time.strftime("%Y-%m-%d %H:%M:%S "))
                    fp.write(self.path)
                    fp.write("\n")
                    traceback.print_exc(file=fp)
            except Exception:
                pass
            try:
                self.send_response(500)
                self.send_header("Content-type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
            except Exception:
                pass
            self.wfile.write(bytes(json.dumps({"ok": False, "error": str(e)}), "utf-8"))

def handle_api(window):
    webServer = HTTPServer(("localhost", 2033), BackglassAPI)
    print("Server started http://%s:%s" % ("localhost", 2033))
    try:
        webServer.serve_forever()
    except:
        webServer.server_close()

def listMissingCustoms(system, mediatype):
    if mediatype not in BackglassAPI.imgvideo_properties:
        raise Exception("invalid media type")
    with urllib.request.urlopen("http://localhost:1234/systems/{}/games".format(system, hash)) as url:
        data = json.load(url)
        for game in data:
            fname = game["path"]
            shortname = BackglassAPI.gameShortName(fname)

            for ext in BackglassAPI.imgvideo_extensions:
                if os.path.exists("/userdata/system/backglass/systems/{}/games/{}/{}.{}".format(system, mediatype, shortname, ext)):
                    break
            else:
                print("/userdata/system/backglass/systems/{}/games/{}/{}.{}".format(system, mediatype, shortname, BackglassAPI.imgvideo_extensions[0]))

parser = argparse.ArgumentParser(prog="batocera-backglass")
parser.add_argument("--www", default="/usr/share/batocera-backglass/www/backglass-default/index.htm", help="path to the web page")
parser.add_argument("--x",      type=int, default=0,   help="window x position")
parser.add_argument("--y",      type=int, default=0,   help="window y position")
parser.add_argument("--width",  type=int, default=800, help="window width")
parser.add_argument("--height", type=int, default=600, help="window height")
parser.add_argument("--list-missing-customs", type=str, nargs=2, help="list missing custom files for a given system/format (ie snes marquee)")
args = parser.parse_args()

if args.list_missing_customs:
    listMissingCustoms(args.list_missing_customs[0], args.list_missing_customs[1])
else:
    window = webview.create_window('backglass', args.www, x=args.x, y=args.y, width=args.width, height=args.height, focus=False)
    webview.start(handle_api, window)
