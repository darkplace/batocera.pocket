# Building batocera.pocket

English documentation for developers. Chat / support with maintainers may be in other languages; all project docs stay in English.

## Requirements

- Linux host with Docker
- Plenty of disk (200 GB+ free recommended under `output/`)
- Image: `batoceralinux/batocera.linux-build`

Optional: see `batocera.mk` for `MAKE_JLEVEL`, Docker image name, and paths.

## Quick start (AYN Odin 3 / sm8750 on Arch)

The working Odin 3 tree under `output/sm8750` was built with **direct Arch builds**, not Docker:

```bash
# one-time on Arch
sudo pacman -S libxcrypt-compat

./build-arch-persistent.sh
# equivalent:
# make sm8750-build DIRECT_BUILD=y PARALLEL_BUILD=y MAKE_JLEVEL=20
```

Do **not** continue that tree inside Docker: `output/sm8750/host` is linked against Arch glibc.

## Docker (clean trees only)

```bash
make sm8750-build   # uses batoceralinux/batocera.linux-build
```

Use Docker only when `output/<target>/host` was produced inside that image (or after a clean wipe of that output dir).

## Other Qualcomm targets

```bash
TARGETS="sm8550 sm8250" ./scripts/dev/build-release-queue.sh
```

`sm8550` covers Odin 2 / Thor / AYANEO / RP6. `sm8250` covers RP5 / Mini / Flip2.

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
