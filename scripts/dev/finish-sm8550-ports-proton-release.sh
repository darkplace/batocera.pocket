#!/usr/bin/env bash
# Wait for sm8550 full-fixes rebuild, then split + GitHub release v44-sm8550-20260819.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"
LOG=/tmp/finish-sm8550-ports-proton-release.log
DONE_BUILD="$PROJECT_DIR/rebuild-sm8550-full-fixes-ota.DONE"
FAIL_BUILD="$PROJECT_DIR/rebuild-sm8550-full-fixes-ota.FAILED"
IMG="$PROJECT_DIR/output/sm8550/images/batocera/images/sm8550"
TAG=v44-sm8550-20260819
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
  if ! pgrep -f 'rebuild-sm8550-full-fixes-ota' >/dev/null \
     && ! pgrep -f 'sm8550-build|sm8550-pkg' >/dev/null; then
    if [ -f "$IMG/boot.tar.xz" ] && [ -f "$IMG/batocera.version" ] \
       && ls "$IMG"/batocera-sm8550-*.img.gz >/dev/null 2>&1; then
      echo "OK artifacts $(date -Is)" >"$DONE_BUILD"
      log "artifacts present — continuing"
      break
    fi
    log "rebuild gone without DONE/artifacts"
    echo "FAILED orphan $(date -Is)" >"$FAIL_BUILD"
    exit 1
  fi
  sleep 45
done

grep -qE 'ports_translator|PORTS TRANSLATOR' \
  "$PROJECT_DIR/output/sm8550/target/usr/share/emulationstation/es_features.cfg"
grep -q 'proton_cachyos_arm64\|PROTON_CACHYOS_STEAM_DIR' \
  "$PROJECT_DIR/output/sm8550/target/usr/bin/batocera-steam"
VER=$(cat "$IMG/batocera.version")
IMG_GZ=$(ls -1 "$IMG"/batocera-sm8550-*.img.gz | head -1)
log "version=$VER img=$IMG_GZ"

./scripts/dev/split-release.sh --ota "$IMG/boot.tar.xz" | tee -a "$LOG"
./scripts/dev/split-release.sh --image "$IMG_GZ" | tee -a "$LOG"

BASE=$(basename "$IMG_GZ")
STEM=${BASE%.img.gz}
if ! gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" -R "$REPO" --target main \
    --title "batocera.pocket SM8550 (Odin 2 Portal) — 2026-08-19 (Ports translator + Proton tips)" \
    --notes "$(cat <<EOF
### Version
- Image: \`${STEM}\`
- System string: \`${VER}\`
- Board: **SM8550** / AYN Odin 2 Portal

> Same Ports translator + Proton tip polish as sm8750 \`v44-sm8750-20260819\`, on top of Golden Rabbit / Portal baseline.

### What's new

<details>
<summary><b>Updates</b></summary>

- **Ports X86 Translator:** Tools + **Advanced Options → PORTS TRANSLATOR** (Box64 ↔ FEX). Docs: [CONTROLS_AND_FAQ.md](https://github.com/darkplace/batocera.pocket/blob/main/docs/CONTROLS_AND_FAQ.md).
- **Steam Proton tips:** \`★ Recommended\` / \`★ Rockstar\` labels; tip folders \`proton_cachyos_arm64\` / \`proton_ge_arm64\`.
- **xenia-edge** patches; Xbox 360 default → \`xenia-edge\`.

</details>

<details>
<summary><b>Fixes</b></summary>

- Proton tip picker order via stable Steam-facing folder names.
- Tools Ports launcher: copy from datainit into userdata if missing after OTA.

</details>

Full notes: [docs/CHANGELOG.md](https://github.com/darkplace/batocera.pocket/blob/main/docs/CHANGELOG.md)

### In-device OTA
EmulationStation → **Updates**. Assets:
- \`batocera.version\`
- \`boot.tar.xz.md5\`
- \`boot.tar.xz.part01\` + \`part02\` + \`part03\`

### Fresh install (Windows)
1. Download **ALL** volumes: \`${STEM}.zip\` + \`.z01\` + \`.z02\` (same folder, do not rename).
2. Open the \`.zip\` with 7-Zip / WinZip → extract \`${BASE}\`.
3. Optional verify: \`${BASE}.md5\`.
4. Flash with balenaEtcher / Rufus / Raspberry Pi Imager.

> Requires the [ROCKNIX ABL](https://github.com/ROCKNIX/abl) on the boot partition before flashing.

### Support
**@lukemotion** on Discord
EOF
)" \
    "$IMG/batocera.version" \
    "$IMG/boot.tar.xz.md5" \
    "${IMG_GZ}.md5"
  log "release created"
else
  log "release already exists"
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
echo "OK $(date -Is)" >/tmp/finish-sm8550-ports-proton-release.DONE
