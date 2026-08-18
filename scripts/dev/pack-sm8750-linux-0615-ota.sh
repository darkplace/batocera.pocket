#!/usr/bin/env bash
# Pack boot.tar.xz from the already-built sm8750 linux+Lutris target.
# Does NOT rebuild packages. Does NOT touch USB gadget / ConnMan / iwd / NM.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/pack-sm8750-linux-0615-ota.log}"
PRIMARY="$PROJECT_DIR/output/sm8750"
IMG_DIR="$PRIMARY/images/batocera/images/sm8750"
DIRECT_BUILD=
PARALLEL_BUILD=
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
mkdir -p "$PRIMARY" "$PRIMARY/tmp"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
: >"$LOG_FILE"
rm -f "$PROJECT_DIR/pack-sm8750-linux-0615-ota.DONE" \
      "$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"

run_cmd() {
  local cmd="$1" ec
  log ""; log ">>> make sm8750-build CMD=$cmd  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8750-build CMD="$cmd" DIRECT_BUILD="$DIRECT_BUILD" \
    PARALLEL_BUILD="$PARALLEL_BUILD" BATCH_MODE=1 \
    MAKE_JLEVEL="${MAKE_JLEVEL:-12}" MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
    >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: $cmd ($ec)"
    echo "FAILED $cmd $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
    exit "$ec"
  fi
  log "OK: $cmd"
}

log "=== pack sm8750 OTA linux 0615/0616/0617 + Lutris cairo ($(date -Is)) ==="

if ! grep -q 'timeout 2 sh -c "echo resume' \
     "$PRIMARY/target/usr/bin/batocera-config-lutris"; then
  log "FAILED: launcher not in target — rebuild packages first"
  echo "FAILED launcher-missing $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
  exit 1
fi
if ! ls "$PRIMARY"/target/usr/lib/python*/site-packages/gi/_gi_cairo*.so >/dev/null 2>&1; then
  log "FAILED: gi._gi_cairo missing in target"
  echo "FAILED cairo-missing $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
  exit 1
fi

# python-gobject rebuild invalidates configgen; hatchling rejects VERSION=1.41e
# unless _version.py maps it to PEP 440 (1.41.post5).
# Always refresh scripts too: PS2 BIOS check, RPCS3 paths, M2 mouse, OLED care.
# Also stamp short version, splash subtitle, pocket logo, OSK exclusive-zone.
run_cmd batocera-configgen-dirclean
run_cmd batocera-scripts-dirclean
run_cmd batocera-system-dirclean
run_cmd batocera-splash-dirclean
run_cmd batocera-splash-odin3-dirclean
run_cmd batocera-onscreen-keyboard-dirclean
run_cmd batocera-es-system-dirclean
run_cmd pkmnrecomp-dirclean
run_cmd batocera-steam-aarch64-dirclean
run_cmd target-finalize
SWAY_SRC="$PROJECT_DIR/package/batocera/emulationstation/batocera-emulationstation/wayland/sway"
install -m 0755 "$SWAY_SRC/config" "$PRIMARY/target/etc/sway/config"
install -m 0644 "$SWAY_SRC/batocera.pocket-logo.png" \
  "$PRIMARY/target/usr/share/batocera/splash/batocera.pocket-logo.png"
if ! grep -q 'RPCS3_SHARE_PATCH' \
     "$PRIMARY"/target/usr/lib/python*/site-packages/configgen/generators/rpcs3/rpcs3Paths.py \
     2>/dev/null; then
  log "FAILED: rpcs3Paths.py missing RPCS3_SHARE_PATCH after finalize"
  echo "FAILED rpcs3-paths $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
  exit 1
fi
if ! grep -q 'anyFile' "$PRIMARY/target/usr/bin/batocera-systems"; then
  log "FAILED: batocera-systems still has strict PS2 BIOS MD5"
  echo "FAILED ps2-bios-check $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
  exit 1
fi
if ! grep -q 'PADDLE_M2' "$PRIMARY/target/usr/bin/batocera-mouse-mode"; then
  log "FAILED: batocera-mouse-mode missing M2 toggle"
  echo "FAILED mouse-m2 $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
  exit 1
fi
if [ ! -x "$PRIMARY/target/usr/bin/batocera-oled-care" ] \
   || [ ! -x "$PRIMARY/target/etc/init.d/S33oledcare" ]; then
  log "FAILED: OLED care missing after scripts rebuild"
  echo "FAILED oled-care $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
  exit 1
fi
if ! grep -q '^44-pocket ' "$PRIMARY/target/usr/share/batocera/batocera.version"; then
  log "FAILED: batocera.version is not the short 44-pocket prefix"
  echo "FAILED version-prefix $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
  exit 1
fi
if ! grep -q '44-pocket' "$PRIMARY/target/usr/share/batocera/splash/splash.srt"; then
  log "FAILED: splash.srt missing short version"
  echo "FAILED splash-srt $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
  exit 1
fi
if ! grep -q 'batocera.pocket-logo.png' "$PRIMARY/target/etc/sway/config"; then
  log "FAILED: sway config missing pocket logo"
  echo "FAILED sway-logo $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
  exit 1
fi
if ! grep -q 'discord_running' "$PRIMARY/target/usr/bin/onscreen-keyboard"; then
  log "FAILED: onscreen-keyboard still shifts all windows"
  echo "FAILED osk-shift $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
  exit 1
fi
if ! grep -q 'set_exclusive_zone(layer_surface, 0)' \
     "$PRIMARY/build/batocera-onscreen-keyboard-v0.17/main.c"; then
  log "FAILED: wvkbd exclusive_zone is not 0"
  echo "FAILED osk-exclusive $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
  exit 1
fi

log ">>> wipe prior squashfs / OTA (keep split zip parts)"
rm -f "$PRIMARY/images/rootfs.squashfs"
rm -f "$IMG_DIR"/batocera-sm8750-*.img.gz
rm -f "$IMG_DIR"/boot.tar.xz "$IMG_DIR"/boot.tar.xz.md5

run_cmd all

if ! "$PROJECT_DIR/scripts/dev/verify-sm8750-must-ship.sh" target; then
  log "FAILED: verify-sm8750-must-ship target"
  echo "FAILED must-ship-target $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
  exit 1
fi

if [ ! -f "$IMG_DIR/boot.tar.xz" ]; then
  log "FAILED: boot.tar.xz missing after all"
  echo "FAILED no-boot-tar $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.FAILED"
  exit 1
fi
md5sum "$IMG_DIR/boot.tar.xz" | awk '{print $1}' > "$IMG_DIR/boot.tar.xz.md5"

{
  echo ""
  echo "=== Finished OK: $(date -Is) ==="
  ls -lh "$IMG_DIR"/boot.tar.xz "$IMG_DIR"/boot.tar.xz.md5 "$IMG_DIR"/batocera.version 2>/dev/null || true
  cat "$IMG_DIR"/batocera.version 2>/dev/null || true
} | tee -a "$LOG_FILE"

echo "OK $(date -Is)" >"$PROJECT_DIR/pack-sm8750-linux-0615-ota.DONE"
log "DONE — apply with ./scripts/dev/apply-sm8750-ota.sh"
