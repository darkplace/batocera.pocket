# Building batocera.pocket

English documentation for developers. Chat / support with maintainers may be in other languages; **all project docs under `docs/` and the README must stay in English** (including user guides such as ADDING_ROMS and CONTROLS_AND_FAQ).

## Requirements

- Linux host with Docker
- Plenty of disk (≈200 GB free recommended **per active board** under `output/<board>/`; three boards ≈600 GB+)
- Shared download cache `dl/` (≈90 GB once warm)
- Image: `batoceralinux/batocera.linux-build`

Optional: see `batocera.mk` for `MAKE_JLEVEL`, Docker image name, and paths.

## Canonical: Docker (all boards)

Primary path for **sm8750**, **sm8550**, and **sm8250**:

```bash
make sm8750-build DIRECT_BUILD= PARALLEL_BUILD= BATCH_MODE=1 MAKE_JLEVEL=12 MAKE_LLEVEL=12
make sm8550-build DIRECT_BUILD= PARALLEL_BUILD= BATCH_MODE=1 MAKE_JLEVEL=12 MAKE_LLEVEL=12
make sm8250-build DIRECT_BUILD= PARALLEL_BUILD= BATCH_MODE=1 MAKE_JLEVEL=12 MAKE_LLEVEL=12
```

- Do **not** set `DIRECT_BUILD` or `PARALLEL_BUILD` for Docker trees.
- `output/<target>/host` must have been produced **inside** the Docker image (or start from an empty `output/<target>`).
- Prefer one board at a time on a single machine (disk + CPU); queue with `scripts/dev/build-release-queue.sh` if needed.

### Layout

| Path | Role |
|------|------|
| `output/sm8750` | Docker tree — AYN Odin 3 |
| `output/sm8550` | Docker tree — Odin 2 / Thor / AYANEO / RP6 |
| `output/sm8250` | Docker tree — RP5 / Mini / Flip2 |
| `dl/` | Shared source download cache (safe to move to NAS + symlink) |

Arch `DIRECT_BUILD` / `output/sm8750-arch-backup` is **retired**. Builds are Docker-only.

Product-lock rebuild examples:

```bash
./rebuild-sm8750-product-lock.sh
./rebuild-sm8550-product-lock.sh
./rebuild-sm8250-product-lock.sh
```

## Disk hygiene (after GitHub upload)

Published releases live on GitHub. Local copies of flash/OTA packages are optional.

**Safe to delete after upload** (does not break incremental Docker builds):

- `output/<board>/images/batocera/images/<board>/batocera-*.img.gz`
- `output/<board>/images/batocera/images/<board>/batocera-*.{zip,z01,z02}`
- `output/<board>/images/batocera/images/<board>/boot.tar.xz*`
- `output/<board>/images/batocera/boot_<board>/boot/{batocera,rufomaculata}` (duplicates of squashfs/rufoma; regenerable)
- Root `docker-*-build.log*` / `rebuild-*.log` / fail logs

**Keep for incremental builds:**

- `output/<board>/{build,host,target,Makefile}`
- `dl/`
- `buildroot-ccache/` (optional speed)

**NAS migration (recommended):** keep one active `output/<board>` on the build PC; put idle board trees and `dl/` on the NAS (symlink `dl` locally).

## Other Qualcomm targets

```bash
TARGETS="sm8550 sm8250" DIRECT_BUILD= ./scripts/dev/build-release-queue.sh
```

Force Docker in the queue script (`DIRECT_BUILD=`). Defaults that still mention Arch are legacy — override on the CLI.

## Outputs

After a successful build:

```
output/sm8750/images/batocera/images/sm8750/
  batocera-sm8750-*.img.gz   # full flash image
  boot.tar.xz                # OTA payload (optional to publish)
  batocera.version
```

Prepare GitHub assets with `scripts/dev/split-release.sh` (see [UPDATES.md](UPDATES.md)). Prefer publishing from the Docker tree after device smoke, then delete local packages (see Disk hygiene).

## Targets

| Make prefix | Board |
|-------------|--------|
| `sm8750` | AYN Odin 3 (primary smoke device) |
| `sm8550` | Odin 2 / Thor / AYANEO / RP6 |
| `sm8250` | Retroid Pocket 5 / Mini / Flip 2 |

Use `make <target>-supported` / defconfigs under `configs/` for the full list.
