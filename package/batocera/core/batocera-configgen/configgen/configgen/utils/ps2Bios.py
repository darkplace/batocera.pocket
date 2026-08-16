from __future__ import annotations

from pathlib import Path

# PCSX2-family dumps are 4 MiB. EROM.BIN / ROM2.BIN are companion NVRAM dumps and
# sort alphabetically *before* SCPH*.bin — picking them as "BIOS" soft-bricks boot.
_PS2_BIOS_SKIP = frozenset(
    {
        "erom.bin",
        "rom1.bin",
        "rom2.bin",
        "patches.zip",
    }
)
_PS2_BIOS_MIN_BYTES = 3_500_000
_PS2_PREFERRED = (
    "ps2-0230a-20080220.bin",
    "scph39001.bin",
    "scph7001.bin",
    "scph5501.bin",
    "scph30004r.bin",
)


def select_ps2_bios_filename(bios_dir: Path) -> str | None:
    """Return a usable PS2 BIOS filename inside bios_dir, or None."""
    if not bios_dir.is_dir():
        return None

    for name in _PS2_PREFERRED:
        candidate = bios_dir / name
        # Case-insensitive match on FAT/exfat userdata layouts.
        if not candidate.is_file():
            matches = [
                p
                for p in bios_dir.iterdir()
                if p.is_file() and p.name.lower() == name.lower()
            ]
            candidate = matches[0] if matches else candidate
        if candidate.is_file() and candidate.stat().st_size >= _PS2_BIOS_MIN_BYTES:
            return candidate.name

    candidates: list[Path] = []
    for path in bios_dir.iterdir():
        if not path.is_file():
            continue
        lower = path.name.lower()
        if lower in _PS2_BIOS_SKIP:
            continue
        if path.suffix.lower() not in {".bin", ".rom"}:
            continue
        try:
            size = path.stat().st_size
        except OSError:
            continue
        if size < _PS2_BIOS_MIN_BYTES:
            continue
        candidates.append(path)

    if not candidates:
        return None

    # Prefer SCPH* names, then alphabetical.
    candidates.sort(
        key=lambda p: (0 if p.name.lower().startswith("scph") else 1, p.name.lower())
    )
    return candidates[0].name
