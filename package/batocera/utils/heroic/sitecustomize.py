"""Batocera Heroic runtime overrides.

Legendary 0.20.25+ introduced install preflight checks that hard-fail when
`os.access(path, os.W_OK)` reports false. In root-only appliance environments
this can reject valid install targets too early.

This hook only applies to Legendary processes and only for W_OK checks.
"""

import os
import sys


def _truthy(name: str, default: str = "1") -> bool:
    value = os.environ.get(name, default).strip().lower()
    return value in {"1", "true", "yes", "on"}


def _looks_like_legendary_process() -> bool:
    argv0 = os.path.basename(sys.argv[0] if sys.argv else "")
    return "legendary" in argv0


def _looks_like_umu_process() -> bool:
    argv0 = os.path.basename(sys.argv[0] if sys.argv else "")
    return "umu" in argv0


def _force_non_root_uid_for_umu() -> None:
    # umu-launcher hard-fails when euid is 0; Batocera runs ports as root.
    # Pretend to be the regular batocera uid so umu can continue.
    fake_uid = int(os.environ.get("BATOCERA_HEROIC_UMU_FAKE_UID", "1000"))

    def _fake_uid() -> int:
        return fake_uid

    os.getuid = _fake_uid
    os.geteuid = _fake_uid


if _truthy("BATOCERA_HEROIC_PATCH_LEGENDARY_PERMS", "1") and _looks_like_legendary_process():
    _orig_access = os.access

    def _patched_access(path: str, mode: int, *args, **kwargs) -> bool:
        if mode & os.W_OK:
            return True
        return _orig_access(path, mode, *args, **kwargs)

    os.access = _patched_access

if _truthy("BATOCERA_HEROIC_ALLOW_ROOT_UMU", "1") and _looks_like_umu_process() and os.geteuid() == 0:
    _force_non_root_uid_for_umu()
