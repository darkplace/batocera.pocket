#!/usr/bin/env bash
# Wait for sm8550 Golden Rabbit rebuild, then split + GitHub release v44-sm8550-20260818.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"
LOG=/tmp/finish-sm8550-golden-rabbit-release.log
DONE_BUILD="$PROJECT_DIR/rebuild-sm8550-golden-rabbit.DONE"
FAIL_BUILD="$PROJECT_DIR/rebuild-sm8550-golden-rabbit.FAILED"
IMG="$PROJECT_DIR/output/sm8550/images/batocera/images/sm8550"
TAG=v44-sm8550-20260818
REPO=darkplace/batocera.pocket
: >"$LOG"
log() { printf '%s\n' "[$(date -Is)] $*" | tee -a "$LOG"; }

log "waiting for rebuild DONE/FAILED…"
while true; do
  if [ -f "$FAIL_BUILD" ]; then
    log "BUILD FAILED: $(cat "$FAIL_BUILD")"
    exit 1
  fi
  if [ -f "$DONE_BUILD" ]; then
    log "rebuild DONE: $(cat "$DONE_BUILD")"
    break
  fi
  if ! pgrep -f 'rebuild-sm8550-golden-rabbit.sh' >/dev/null \
     && ! pgrep -f 'make O=/sm8550' >/dev/null \
     && ! pgrep -f 'sm8550-build|sm8550-pkg' >/dev/null; then
    if [ -f "$IMG/boot.tar.xz" ] && [ -f "$IMG/batocera.version" ] \
       && ls "$IMG"/batocera-sm8550-*.img.gz >/dev/null 2>&1 \
       && grep -q golden-rabbit "$IMG/batocera.version" 2>/dev/null; then
      echo "OK artifacts $(date -Is)" >"$DONE_BUILD"
      break
    fi
    log "rebuild gone without Golden Rabbit artifacts"
    echo "FAILED orphan $(date -Is)" >"$FAIL_BUILD"
    exit 1
  fi
  sleep 45
done

VER=$(cat "$IMG/batocera.version")
IMG_GZ=$(ls -1 "$IMG"/batocera-sm8550-*.img.gz | head -1)
log "version=$VER img=$IMG_GZ"

./scripts/dev/split-release.sh --ota "$IMG/boot.tar.xz" | tee -a "$LOG"
./scripts/dev/split-release.sh --image "$IMG_GZ" | tee -a "$LOG"

BASE=$(basename "$IMG_GZ")
STEM=${BASE%.img.gz}
if ! gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" -R "$REPO" --target main --latest \
    --title "batocera.pocket SM8550 (Odin 2 Portal) — 2026-08-18 (Golden Rabbit)" \
    --notes "$(cat <<EOF
### Version
- Image: \`${STEM}\`
- System string: \`${VER}\`
- Board: **SM8550** / AYN Odin 2 Portal
- Codename: **Golden Rabbit**

> Same Steam ARM cut as sm8750 Golden Rabbit (\`v44-sm8750-20260816\`), on top of stick LED + rsinput \`20260817\`.

### What's new

<details>
<summary><b>Updates</b></summary>

- **Proton 11.0 (ARM64) ★ recommended:** pure custom compatibility tool (no Steam AppID merge with depot 4628740 / missing SLR 4185400).
- **MangoApp:** on by default for ARM SteamOS / steam-direct.
- **Docs:** Steam + Batocera Control shortcuts (QAM overlay, M1+M2 MangoHud, Power, LSFG, Sleep).
- Expects **decky-bcc ≥ 0.2.18**.
- Keeps Portal stick LED groups + rsinput deadzone from \`v44-sm8550-20260817\`.

</details>

<details>
<summary><b>Fixes</b></summary>

- Official Proton 11 custom registration no longer symlink-merges into \`steamapps/common\` (AppError_51 / SLR 4185400).
- Steam direct session no longer defaults MangoApp off on ARM.

</details>

Full notes: [docs/CHANGELOG.md](https://github.com/darkplace/batocera.pocket/blob/main/docs/CHANGELOG.md)

### In-device OTA
EmulationStation → **Updates**. Assets used by \`batocera-upgrade\`:
- \`batocera.version\`
- \`boot.tar.xz.md5\`
- \`boot.tar.xz.part01\` + \`part02\` + \`part03\` (joined automatically on device)

### Fresh install (Windows)
1. Download **ALL** volumes: \`${STEM}.zip\` + \`.z01\` + \`.z02\` (same folder, do not rename).
2. Open the \`.zip\` with 7-Zip / WinZip → extract \`${STEM}.img.gz\`.
3. Optional verify: \`${STEM}.img.gz.md5\`.
4. Flash the \`.img.gz\` with balenaEtcher / Rufus / Raspberry Pi Imager.
5. Boot from the card.

> Requires the [ROCKNIX ABL](https://github.com/ROCKNIX/abl) on the boot partition before flashing.

### Docs / FAQ
- [INSTALL](https://github.com/darkplace/batocera.pocket/blob/main/docs/INSTALL.md) · [ADDING_ROMS](https://github.com/darkplace/batocera.pocket/blob/main/docs/ADDING_ROMS.md) · [CONTROLS_AND_FAQ](https://github.com/darkplace/batocera.pocket/blob/main/docs/CONTROLS_AND_FAQ.md) · [UPDATES](https://github.com/darkplace/batocera.pocket/blob/main/docs/UPDATES.md)

### Support
**@lukemotion** on Discord
EOF
)" \
    "$IMG/batocera.version" \
    "$IMG/boot.tar.xz.md5" \
    "${IMG_GZ}.md5"
  log "release created"
fi

shopt -s nullglob
for f in \
  "$IMG/boot.tar.xz.part01" \
  "$IMG/boot.tar.xz.part02" \
  "$IMG/boot.tar.xz.part03" \
  "$IMG"/batocera-sm8550-*.z01 \
  "$IMG"/batocera-sm8550-*.z02 \
  "$IMG"/batocera-sm8550-*.zip
do
  [ -f "$f" ] || continue
  log "upload $(basename "$f")"
  gh release upload "$TAG" -R "$REPO" --clobber "$f"
done

log "ALL DONE → https://github.com/${REPO}/releases/tag/${TAG}"
echo "OK $(date -Is)" >/tmp/finish-sm8550-golden-rabbit-release.DONE
