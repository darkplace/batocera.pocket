import os
import sys


def _looks_like_umu_process() -> bool:
    argv0 = os.path.basename(sys.argv[0] if sys.argv else "")
    return "umu" in argv0


def _force_non_root_uid_for_umu() -> None:
    fake_uid = int(os.environ.get("BATOCERA_UMU_FAKE_UID", "1000"))

    def _fake_uid() -> int:
        return fake_uid

    os.getuid = _fake_uid
    os.geteuid = _fake_uid


if _looks_like_umu_process() and os.geteuid() == 0:
    _force_non_root_uid_for_umu()
