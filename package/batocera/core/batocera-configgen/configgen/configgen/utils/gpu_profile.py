from __future__ import annotations

from contextlib import contextmanager
import logging
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from collections.abc import Iterator

    from ..config import SystemConfig

_logger = logging.getLogger(__name__)

_AUTO_ARCHS = {"sm8550", "qcs6490"}
_AUTO_SYSTEMS = {"odcommander", "scummvm", "android", "waydroid", "n64recomp", "steam"}
_AUTO_ROM_MARKERS = (
    "portmaster",
    "vacuumtube",
    "waydroid",
    "youtubetv",
    "youtube-tv",
    "youtube_tv",
    "file_manager",
    "file-manager",
)

_GPU_POWER_NODES = (
    Path("/sys/devices/platform/soc@0/3d00000.gpu/power/control"),
    Path("/sys/devices/platform/soc@0/3d6a000.gmu/power/control"),
    Path("/sys/class/drm/card0/device/power/control"),
)


def _read(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return None


def _write(path: Path, value: str) -> bool:
    try:
        path.write_text(value, encoding="utf-8")
        return True
    except OSError as exc:
        _logger.debug("Failed to write %s to %s: %s", value, path, exc)
        return False


def _arch() -> str:
    return (_read(Path("/usr/share/batocera/batocera.arch")) or "").lower()


def _find_gpu_devfreq() -> Path | None:
    preferred = Path("/sys/class/devfreq/3d00000.gpu")
    if preferred.exists():
        return preferred

    for candidate in Path("/sys/class/devfreq").glob("*"):
        name = (_read(candidate / "name") or candidate.name).lower()
        if "gpu" in name:
            return candidate

    return None


def _available_governors(devfreq: Path) -> set[str]:
    return set((_read(devfreq / "available_governors") or "").split())


def _set_first_available_governor(devfreq: Path, preferred: tuple[str, ...]) -> None:
    available = _available_governors(devfreq)
    for governor in preferred:
        if governor in available:
            _write(devfreq / "governor", governor)
            return


def _lowest_frequency(devfreq: Path) -> str | None:
    frequencies = []
    for item in (_read(devfreq / "available_frequencies") or "").split():
        try:
            frequencies.append(int(item))
        except ValueError:
            pass

    if frequencies:
        return str(min(frequencies))

    return _read(devfreq / "min_freq")


def _power_control_nodes(devfreq: Path | None) -> list[Path]:
    nodes: list[Path] = []
    if devfreq is not None:
        nodes.append(devfreq / "power" / "control")
    nodes.extend(_GPU_POWER_NODES)
    nodes.extend(sorted(Path("/sys/class/drm").glob("card*/device/power/control")))

    seen: set[Path] = set()
    unique_nodes: list[Path] = []
    for node in nodes:
        if node not in seen and node.exists():
            seen.add(node)
            unique_nodes.append(node)
    return unique_nodes


def _normalize_profile(profile: object) -> str:
    normalized = str(profile or "auto").strip().lower().replace("_", "")
    aliases = {
        "": "auto",
        "enabled": "auto",
        "max": "highperformance",
        "high": "highperformance",
        "performance": "highperformance",
        "powersave": "powersaver",
        "power_saver": "powersaver",
        "off": "default",
        "disabled": "default",
        "none": "default",
    }
    return aliases.get(normalized, normalized)


def _auto_profile(system_name: str, emulator: str, core: str, rom: Path) -> str:
    if _arch() not in _AUTO_ARCHS:
        return "default"

    system_key = str(system_name or "").lower()
    emulator_key = str(emulator or "").lower()
    core_key = str(core or "").lower()
    if system_key in _AUTO_SYSTEMS or emulator_key in _AUTO_SYSTEMS or core_key in _AUTO_SYSTEMS:
        return "highperformance"

    rom_key = rom.name.lower()
    rom_stem = rom.stem.lower()
    if any(marker in rom_key or marker in rom_stem for marker in _AUTO_ROM_MARKERS):
        return "highperformance"

    return "default"


def _apply_profile(profile: str, devfreq: Path | None, power_nodes: list[Path]) -> None:
    if profile == "highperformance":
        for node in power_nodes:
            _write(node, "on")

        if devfreq is not None:
            _set_first_available_governor(devfreq, ("performance", "userspace"))
            if max_freq := _read(devfreq / "max_freq"):
                _write(devfreq / "min_freq", max_freq)
        return

    if profile == "balanced":
        for node in power_nodes:
            _write(node, "auto")

        if devfreq is not None:
            _set_first_available_governor(devfreq, ("simple_ondemand", "ondemand", "performance"))
            if min_freq := _lowest_frequency(devfreq):
                _write(devfreq / "min_freq", min_freq)
        return

    if profile == "powersaver":
        for node in power_nodes:
            _write(node, "auto")

        if devfreq is not None:
            _set_first_available_governor(devfreq, ("powersave", "simple_ondemand", "ondemand"))
            if min_freq := _lowest_frequency(devfreq):
                _write(devfreq / "min_freq", min_freq)


@contextmanager
def gpu_profile(
    config: SystemConfig,
    system_name: str,
    emulator: str,
    core: str,
    rom: Path,
) -> Iterator[None]:
    profile = _normalize_profile(config.get("gpu_performance_profile", "auto"))
    if profile == "auto":
        profile = _auto_profile(system_name, emulator, core, rom)

    if profile == "default":
        yield
        return

    devfreq = _find_gpu_devfreq()
    power_nodes = _power_control_nodes(devfreq)
    saved_values: dict[Path, str] = {}

    for node in (*power_nodes,):
        if value := _read(node):
            saved_values[node] = value

    if devfreq is not None:
        for node in (devfreq / "governor", devfreq / "min_freq"):
            if value := _read(node):
                saved_values[node] = value

    _logger.info("Applying GPU performance profile: %s", profile)
    _apply_profile(profile, devfreq, power_nodes)

    try:
        yield
    finally:
        for node, value in reversed(saved_values.items()):
            _write(node, value)
