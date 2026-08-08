# Live hotpatch (no reflash)

Developers can push the current source-tree fixes onto a running device and
persist them with Batocera's `/boot/boot/overlay` mechanism.

```bash
# Build tarball only
./scripts/dev/apply-hotpatch.sh

# Build + install on device + batocera-save-overlay
./scripts/dev/apply-hotpatch.sh --apply 10.10.10.104
```

Default SSH credentials: `root` / `linux` (override with `HOTPATCH_USER` / `HOTPATCH_PASS`).

The hotpatch updates OTA scripts (including `batocera-pocket-github-release` for
**per-board** GitHub tags — never `/releases/latest`), LED defaults, Plasma LXC
helper, decky-bcc URL, Steam session scripts, splash logos, and optionally
`gamescope` from the build `output/sm8750/target` tree. It also sets
`updates.url` in `/userdata/system/batocera.conf`.

After a successful apply, reboot once and verify with:

```bash
batocera-es-swissknife --update
batocera-config canupdate
ls -la /boot/boot/overlay
```

Release tags must contain `-<board>-` (e.g. `v44-sm8550-20260808`). Each SoC
has its own release; they must not share a single GitHub “Latest” for OTA.

This hotpatch path is for development validation on a live device. End-user
hotfixes will use the same scripts via pocket-delta / OTA once baked into the
board image.

## End-user OTA prep ZIP (sm8750 GitHub flashers)

Devices flashed from `v44-sm8750-20260807` still resolve Updates via
`/releases/latest`. Package a small ZIP they can install once:

```bash
./scripts/dev/pack-ota-prep-zip.sh
# → output/hotpatch/batocera-pocket-ota-per-board-prep.zip
```

Attach that asset to the sm8750 release (or a docs note). On device:

```bash
cd /userdata/system/upgrade
unzip -o batocera-pocket-ota-per-board-prep.zip
cd batocera-pocket-ota-per-board-prep && bash install.sh
```

Then reboot and run `batocera-config canupdate`.
