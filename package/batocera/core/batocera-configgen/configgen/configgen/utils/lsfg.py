from __future__ import annotations

import os
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from collections.abc import MutableMapping

    from ..Emulator import Emulator

_LSFG_LAYER = "VK_LAYER_LS_frame_generation"
_HOME = Path("/userdata/system")


def _append_colon_value(env: MutableMapping[str, str | Path], key: str, value: str) -> None:
    existing = str(env.get(key, "")).strip()
    values = [item for item in existing.split(":") if item]
    if value not in values:
        values.insert(0, value)
    env[key] = ":".join(values)


def _resolve_lossless_dll(configured_path: str) -> Path | None:
    candidates: list[Path] = []
    if configured_path:
        if configured_path.startswith("~/"):
            candidates.append(_HOME / configured_path[2:])
        else:
            candidates.append(Path(configured_path))

    candidates.extend(
        (
            _HOME / "wine" / "lossless-scaling" / "Lossless.dll",
            _HOME / "wine" / ".local" / "share" / "Steam" / "steamapps" / "common" / "Lossless Scaling" / "Lossless.dll",
            _HOME / ".local" / "share" / "Steam" / "steamapps" / "common" / "Lossless Scaling" / "Lossless.dll",
            Path("/userdata/roms/windows/Lossless Scaling/Lossless.dll"),
        )
    )

    for candidate in candidates:
        if candidate.is_file():
            return candidate

    return None


def _default_performance_mode() -> bool:
    return os.uname().machine.lower() in {"aarch64", "arm64"}


def _default_flow_scale() -> str:
    return "0.75" if os.uname().machine.lower() in {"aarch64", "arm64"} else "1.0"


def _resolve_layer_paths(*, use_wine_layer: bool = False, wine_mode: str = "box64") -> tuple[Path, Path, Path] | None:
    machine = os.uname().machine.lower()
    use_private_x64_layer = use_wine_layer and (
        machine not in {"aarch64", "arm64"} or wine_mode == "fex"
    )

    if use_private_x64_layer:
        root = Path("/usr/wine/lsfg-vk/x64")
        return (
            root,
            root / "lib" / "liblsfg-vk.so",
            root / "share" / "vulkan" / "explicit_layer.d",
        )

    if machine in {"x86_64", "amd64"}:
        root = Path("/usr/wine/lsfg-vk/x64")
        return (
            root,
            root / "lib" / "liblsfg-vk.so",
            root / "share" / "vulkan" / "explicit_layer.d",
        )

    if machine in {"aarch64", "arm64"}:
        root = Path("/usr")
        return (
            root,
            root / "lib" / "liblsfg-vk.so",
            root / "share" / "vulkan" / "explicit_layer.d",
        )

    return None


def apply_lsfg_vk(
    system: Emulator,
    env: MutableMapping[str, str | Path],
    *,
    backend_key: str | None = None,
    process_name: str | None = None,
    use_wine_layer: bool = False,
    defer_layer_env: bool = False,
) -> None:
    wine_mode = system.config.get_str("aarch64_wine_mode", "box64").strip().lower()
    layer_paths = _resolve_layer_paths(use_wine_layer=use_wine_layer, wine_mode=wine_mode)
    if layer_paths is None:
        return

    if not system.config.get_bool("lsfg_vk", False):
        return

    if backend_key and system.config.get_str(backend_key, "1") != "1":
        return

    root, library, layer_dir = layer_paths
    if not library.is_file() or not layer_dir.is_dir():
        return

    dll_path = _resolve_lossless_dll(system.config.get_str("lsfg_vk_dll", "").strip())
    if dll_path is None:
        return

    env["ENABLE_LSFG"] = "1"
    env["LSFG_LEGACY"] = "1"
    env["LSFG_DLL_PATH"] = str(dll_path)
    env["LSFG_MULTIPLIER"] = system.config.get_str("lsfg_vk_multiplier", "2")
    env["LSFG_FLOW_SCALE"] = system.config.get_str("lsfg_vk_flow_scale", _default_flow_scale())
    env["LSFG_PERFORMANCE_MODE"] = system.config.get_bool(
        "lsfg_vk_performance", _default_performance_mode(), return_values=("1", "0")
    )
    env["LSFG_HDR_MODE"] = system.config.get_bool("lsfg_vk_hdr", False, return_values=("1", "0"))

    present_mode = system.config.get_str("lsfg_vk_present_mode", "").strip()
    if present_mode in {"fifo", "vsync", "mailbox", "immediate"}:
        env["LSFG_EXPERIMENTAL_PRESENT_MODE"] = present_mode

    if process_name:
        env["LSFG_PROCESS"] = process_name

    if defer_layer_env:
        env["BATOCERA_LSFG_WINE_LAYER"] = "1"
        return

    _append_colon_value(env, "VK_LAYER_PATH", str(layer_dir))
    _append_colon_value(env, "LD_LIBRARY_PATH", str(root / "lib"))
    _append_colon_value(env, "VK_INSTANCE_LAYERS", _LSFG_LAYER)
