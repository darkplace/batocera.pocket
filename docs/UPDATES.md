# Updates (OTA)

batocera.pocket serves updates from **GitHub Releases** of this repository:

`https://github.com/darkplace/batocera.pocket`

Per-tag notes (collapsible **Updates** / **Fixes**): **[CHANGELOG.md](CHANGELOG.md)**.  
Controls / user FAQ: **[CONTROLS_AND_FAQ.md](CONTROLS_AND_FAQ.md)**.

<details>
<summary><b>Recent baselines (August 2026)</b></summary>

| Tag | Board | Notes |
|-----|--------|--------|
| `v44-sm8750-20260816` | SM8750 | Odin 3 — **OTA + flash** (**Golden Rabbit**) |
| `v44-sm8750-20260815` | SM8750 | Odin 3 — **OTA + flash** (Steam touch / OSK) |
| `v44-sm8750-20260814` | SM8750 | Odin 3 — OTA RC1 |
| `v44-sm8550-20260818` | SM8550 | Odin 2 Portal — **OTA + flash** (**Golden Rabbit**) |
| `v44-sm8550-20260817` | SM8550 | Odin 2 Portal — **OTA + flash** (stick LEDs + analog DZ) |
| `v44-sm8550-20260816` | SM8550 | Odin 2 Portal — **OTA + flash** (Steam touch / OSK) |
| `v44-sm8550-20260815` | SM8550 | Odin 2 Portal — **OTA + flash** |
| `v44-sm8550-20260813` | SM8550 | Odin 2 Portal — flash baseline |
| `v44-sm8250-20260811` | SM8250 | Community / untested |
| `v44-sm8750-20260809` | SM8750 | Flash baseline (no OTA payload) |

Full Updates/Fixes: [CHANGELOG.md](CHANGELOG.md).

</details>

## Channel behaviour

Stock Batocera exposes `updates.type` (`stable` / `butterfly`). On batocera.pocket
both map to the same payload for a given board: the newest GitHub Release whose
tag contains `-<board>-` (e.g. `v44-sm8750-20260807`). Devices must **not** use
`/releases/latest` once multiple SoCs publish releases.

Images from `v44-sm8750-20260807` still use `/releases/latest`. Install
`batocera-pocket-ota-per-board-prep.zip` once (see [HOTPATCH.md](HOTPATCH.md)).

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

<details>
<summary><b>Private Release Candidate (no GitHub)</b></summary>

For maintainer RC smoke: package a full OTA that **you** can install with
`batocera-upgrade` / `batocera-config update`, without publishing a
`v44-<soc>-…` GitHub Release (so devices never see it via `canupdate`).

```bash
./scripts/dev/package-private-rc-ota.sh --board sm8750
# → releases/private/sm8750-rc-…/  (gitignored)
```

**Apply (manual):** copy `ota/boot.tar.xz{,.md5}` to
`/userdata/system/upgrade/` on the device, then `batocera-upgrade manual`.

**Apply (ES / batocera-config update):** serve `http-root/` on your LAN, set
`updates.url` to that HTTP base temporarily, run the update, then **restore**
`updates.url` to `https://github.com/darkplace/batocera.pocket`.

Do **not** upload the RC under a `-<soc>-` tag. After install, `canupdate`
compares dates: a newer RC will not be nagged to downgrade to an older public
tag; the next *newer* public release will still show up normally.

Host SSH smoke (no `batocera-upgrade`): `scripts/dev/apply-sm8750-ota.sh`.

</details>

## Live hotpatch (developers)

See [HOTPATCH.md](HOTPATCH.md) to apply source fixes onto a running device without reflashing.

