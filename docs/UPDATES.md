# Updates (OTA)

batocera.pocket serves updates from **GitHub Releases** of this repository:

`https://github.com/darkplace/batocera.pocket`

## Channel behaviour

Stock Batocera exposes `updates.type` (`stable` / `butterfly`). On batocera.pocket **both map to the same payload**: the GitHub **latest** release. Changing the type in the UI has no effect on which build is fetched.

## Release asset layout

Each release that ships an OTA update should include:

| Asset | Purpose |
|-------|---------|
| `batocera.version` | Version string compared by `batocera-config canupdate` |
| `boot.tar.xz.md5` | Checksum of the full archive |
| `boot.tar.xz` **or** `boot.tar.xz.part01` … `partN` | Update payload (split when &gt; ~1.9 GB) |

Optional (fresh install for Windows users):

| Asset | Purpose |
|-------|---------|
| `….zip` + `….z01` + `….z02` … | Multi-volume ZIP of the `.img.gz` |
| `….img.gz.md5` | Checksum of the full image |

## Maintainer: preparing assets

```bash
# OTA payload (joined on the device by batocera-upgrade)
./scripts/dev/split-release.sh --ota output/sm8750/images/batocera/images/sm8750/boot.tar.xz

# Windows flash set (joined by 7-Zip / WinZip — no .sh for end users)
./scripts/dev/split-release.sh --image output/sm8750/images/batocera/images/sm8750/batocera-sm8750-*.img.gz
```

Upload the generated files plus `batocera.version` to a new GitHub Release. Prefer one “latest” release (or always publish the newest build as the latest tag) so OTA stays simple.

## Manual update on device

```bash
# Copy boot.tar.xz to the device, then:
batocera-upgrade manual
```
(with the file at `/userdata/system/upgrade/boot.tar.xz`)

## Live hotpatch (developers)

See [HOTPATCH.md](HOTPATCH.md) to apply source fixes onto a running device without reflashing.

