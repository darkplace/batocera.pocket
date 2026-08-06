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

The hotpatch updates OTA scripts, LED defaults, Plasma LXC helper, decky-bcc URL,
Steam session scripts, splash logos, and optionally `gamescope` from the build
`output/sm8750/target` tree. It also sets `updates.url` in `/userdata/system/batocera.conf`.

After a successful apply, reboot once and verify with:

```bash
batocera-es-swissknife --update
batocera-config canupdate
ls -la /boot/boot/overlay
```

This is for development validation. End users receive the same fixes via a normal
GitHub Release OTA (`boot.tar.xz` / split parts) after a full image rebuild.
