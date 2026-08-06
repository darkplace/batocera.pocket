# Building batocera.pocket

English documentation for developers. Chat / support with maintainers may be in other languages; all project docs stay in English.

## Requirements

- Linux host with Docker
- Plenty of disk (200 GB+ free recommended under `output/`)
- Image: `batoceralinux/batocera.linux-build`

Optional: see `batocera.mk` for `MAKE_JLEVEL`, Docker image name, and paths.

## Quick start

```bash
git clone https://github.com/darkplace/batocera.pocket.git
cd batocera.pocket

# Configure + build SM8750 (Odin 3)
make sm8750-build
```

Package-only rebuild example:

```bash
make sm8750-shell BATCH_MODE=y CMD='make gamescope-rebuild gamescope-reinstall'
```

## Outputs

After a successful build:

```
output/sm8750/images/batocera/images/sm8750/
  batocera-sm8750-*.img.gz   # full flash image
  boot.tar.xz                # OTA payload
  batocera.version
```

Prepare GitHub assets with `scripts/dev/split-release.sh` (see [UPDATES.md](UPDATES.md)).

## Targets

| Make prefix | Board |
|-------------|--------|
| `sm8750` | AYN Odin 3 (primary) |
| `sm8550` | Other Qualcomm handhelds (when configured) |

Use `make <target>-supported` / defconfigs under `configs/` for the full list.
