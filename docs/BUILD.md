# Building batocera.pocket

English documentation for developers. Chat / support with maintainers may be in other languages; all project docs stay in English.

## Requirements

- Linux host with Docker
- Plenty of disk (200 GB+ free recommended under `output/`; more if keeping an Arch backup tree)
- Image: `batoceralinux/batocera.linux-build`

Optional: see `batocera.mk` for `MAKE_JLEVEL`, Docker image name, and paths.

## Canonical: Docker (all boards, including sm8750)

Primary path — same as the successful **sm8550** Docker build:

```bash
# Same flags for all three Qualcomm release boards:
make sm8750-build DIRECT_BUILD= PARALLEL_BUILD= BATCH_MODE=1 MAKE_JLEVEL=12 MAKE_LLEVEL=12
make sm8550-build DIRECT_BUILD= PARALLEL_BUILD= BATCH_MODE=1 MAKE_JLEVEL=12 MAKE_LLEVEL=12
make sm8250-build DIRECT_BUILD= PARALLEL_BUILD= BATCH_MODE=1 MAKE_JLEVEL=12 MAKE_LLEVEL=12
```

- Do **not** set `DIRECT_BUILD` or `PARALLEL_BUILD` for Docker trees.
- `output/<target>/host` must have been produced **inside** the Docker image (or start from an empty `output/<target>`).
- Never point Docker at an Arch-linked `host/` (openssl/glib ABI mismatch).
- Prefer one board at a time on a single machine (disk + CPU); queue with `scripts/dev/build-release-queue.sh` if needed.

### sm8750 layout

| Path | Role |
|------|------|
| `output/sm8750` | **Primary** Docker tree (releases after smoke) |
| `output/sm8750-arch-backup` | Frozen Arch tree that produced known-good images; emergency only |

Do not mix the two. Do not `mv` Arch backup back over `output/sm8750` while a Docker build is in progress.

Product-lock rebuild (Docker primary):

```bash
./rebuild-sm8750-product-lock.sh
# ARCH_BACKUP=1 ./rebuild-sm8750-product-lock.sh   # emergency: Arch tree only
```

## Emergency: Arch DIRECT_BUILD (sm8750 only)

Only if Docker sm8750 is broken and you need the last known-good incremental tree.

Requirements: Arch host + `libxcrypt-compat`.

```bash
sudo pacman -S libxcrypt-compat
./build-arch-persistent.sh
```

The script builds against `output/sm8750-arch-backup` (override with `SM8750_ARCH_OUT`). It temporarily swaps that tree into `output/sm8750` for Make (target name is always `sm8750`), then restores any Docker tree that was present.

Equivalent manual flags:

```bash
make sm8750-build DIRECT_BUILD=y PARALLEL_BUILD=y MAKE_JLEVEL=12 MAKE_LLEVEL=12
```

(only while `output/sm8750` is the Arch tree)

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

Prepare GitHub assets with `scripts/dev/split-release.sh` (see [UPDATES.md](UPDATES.md)). Prefer publishing from the **Docker** tree after device smoke. Keep Arch backup until that smoke passes; reclaim disk later if needed (at minimum keep `images/` under the backup).

## Targets

| Make prefix | Board |
|-------------|--------|
| `sm8750` | AYN Odin 3 (primary smoke device) |
| `sm8550` | Odin 2 / Thor / AYANEO / RP6 |
| `sm8250` | Retroid Pocket 5 / Mini / Flip 2 |

Use `make <target>-supported` / defconfigs under `configs/` for the full list.
