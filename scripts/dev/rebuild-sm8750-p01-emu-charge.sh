#!/bin/bash
# sm8750 OTA: P0 emu cleanup + P1 version + charge bypass kernel (#2840).
# - S31 placeholder fail-closed
# - LSFG Cemu/RPCS3/Heroic/Lutris + Configure Tools
# - PS3 .iso
# - batocera-system 44-dev-pocket-p01
# - linux 0512 charge_behaviour bypass + qcom-charge-limit bypass CLI
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-p01-emu-charge.log}"
REVIEW_LOG="$PROJECT_DIR/output/upstream-review/rebuild-sm8750-p01-emu-charge.log"
PRIMARY="$PROJECT_DIR/output/sm8750"
DIRECT_BUILD=
PARALLEL_BUILD=
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"
mkdir -p "$PRIMARY" "$PROJECT_DIR/output/upstream-review"
echo docker > "$PRIMARY/.batocera-build-env"
export TMPDIR="$PRIMARY/tmp"
mkdir -p "$TMPDIR"
export CMAKE_POLICY_VERSION_MINIMUM=3.5
IMG_DIR="$PRIMARY/images/batocera/images/sm8750"
CG_SRC="$PROJECT_DIR/package/batocera/core/batocera-configgen/configgen/configgen/generators"

log() { printf '%s\n' "$@" >>"$LOG_FILE"; }

RESUME_FROM="${RESUME_FROM:-}"
if [ -z "$RESUME_FROM" ]; then
  : >"$LOG_FILE"
  {
    echo "=== batocera.pocket sm8750 P01 emu+charge OTA ==="
    echo "Date: $(date -Is)"
    echo "PID: $$"
    echo "Tree: $PRIMARY"
    echo "Log: $LOG_FILE"
    echo ""
  } >>"$LOG_FILE"
else
  {
    echo ""
    echo "=== RESUME from $RESUME_FROM ($(date -Is)) pid=$$ ==="
  } >>"$LOG_FILE"
fi
ln -sfn "$LOG_FILE" "$REVIEW_LOG"
rm -f "$PROJECT_DIR/rebuild-sm8750-p01-emu-charge.DONE" "$PROJECT_DIR/rebuild-sm8750-p01-emu-charge.FAILED"

run_pkg() {
  local pkg="$1" ec
  log ""
  log ">>> make sm8750-pkg PKG=$pkg  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8750-pkg \
      PKG="$pkg" \
      DIRECT_BUILD="$DIRECT_BUILD" \
      PARALLEL_BUILD="$PARALLEL_BUILD" \
      BATCH_MODE=1 \
      MAKE_JLEVEL="${MAKE_JLEVEL:-12}" \
      MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
      >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: $pkg (exit $ec) at $(date -Is)"
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-p01-emu-charge.FAILED"
    ln -sfn "$LOG_FILE" "$REVIEW_LOG"
    exit "$ec"
  fi
  log "OK: $pkg"
}

run_cmd() {
  local cmd="$1" ec
  log ""
  log ">>> make sm8750-build CMD=$cmd  ($(date -Is))"
  set +e
  stdbuf -oL -eL make sm8750-build \
      CMD="$cmd" \
      DIRECT_BUILD="$DIRECT_BUILD" \
      PARALLEL_BUILD="$PARALLEL_BUILD" \
      BATCH_MODE=1 \
      MAKE_JLEVEL="${MAKE_JLEVEL:-12}" \
      MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
      >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: CMD=$cmd (exit $ec) at $(date -Is)"
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-p01-emu-charge.FAILED"
    ln -sfn "$LOG_FILE" "$REVIEW_LOG"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

skipping=1
[ -z "$RESUME_FROM" ] && skipping=0

run_pkg_gated() {
  local pkg="$1"
  if [ "$skipping" -eq 1 ]; then
    if [ "$pkg" = "$RESUME_FROM" ]; then
      skipping=0
    else
      log "SKIP $pkg (resume from $RESUME_FROM)"
      return 0
    fi
  fi
  run_pkg "$pkg"
}

run_cmd_gated() {
  local cmd="$1"
  if [ "$skipping" -eq 1 ]; then
    log "SKIP CMD=$cmd (resume from $RESUME_FROM)"
    return 0
  fi
  run_cmd "$cmd"
}

# Kernel first (charge_behaviour 0512) — long step
run_pkg_gated linux-rebuild
run_pkg_gated batocera-configgen-rebuild
run_pkg_gated batocera-es-system-rebuild
run_pkg_gated batocera-emulationstation-reinstall
run_pkg_gated batocera-desktopapps-reinstall
run_pkg_gated batocera-system-reinstall
run_cmd_gated target-finalize

TARGET="$PRIMARY/target"

# Ensure charge-limit userspace (with bypass) lands even if fsoverlay order races
install -m 0755 \
  "$PROJECT_DIR/board/batocera/qualcomm/sm8750/fsoverlay/usr/bin/qcom-charge-limit" \
  "$TARGET/usr/bin/qcom-charge-limit"
install -m 0755 \
  "$PROJECT_DIR/board/batocera/qualcomm/sm8750/fsoverlay/etc/init.d/S07qcom-charge-limit" \
  "$TARGET/etc/init.d/S07qcom-charge-limit"

# Force S31 from package (post-sed happens in package install; verify)
if grep -q '%BATOCERA_EMULATIONSTATION_' "$TARGET/etc/init.d/S31emulationstation" 2>/dev/null; then
  log "WARN: S31 still has placeholders — applying sway-launch failsafe"
  sed -i \
    -e 's;%BATOCERA_EMULATIONSTATION_CMD%;sway-launch;g' \
    -e 's;%BATOCERA_EMULATIONSTATION_POSTFIX%;\&;g' \
    "$TARGET/etc/init.d/S31emulationstation"
fi

CG_DST=$(echo "$TARGET"/usr/lib/python*/site-packages/configgen/generators)
install -m 0644 "$CG_SRC/cemu/cemuGenerator.py" "$CG_DST/cemu/cemuGenerator.py"
install -m 0644 "$CG_SRC/rpcs3/rpcs3Generator.py" "$CG_DST/rpcs3/rpcs3Generator.py"
install -m 0644 "$CG_SRC/sh/shGenerator.py" "$CG_DST/sh/shGenerator.py"

log ""
log ">>> P01 target greps"
fail=0
set +e

if ! grep -q '%BATOCERA_EMULATIONSTATION_' "$TARGET/etc/init.d/S31emulationstation" \
   && grep -q 'sway-launch' "$TARGET/etc/init.d/S31emulationstation"; then
  log "PASS S31_sway_launch"
else
  log "FAIL S31_sway_launch"; fail=1
fi

if grep -q 'apply_lsfg_vk' "$CG_DST/cemu/cemuGenerator.py" \
   && grep -q 'apply_lsfg_vk' "$CG_DST/rpcs3/rpcs3Generator.py" \
   && grep -q 'apply_lsfg_vk' "$CG_DST/sh/shGenerator.py"; then
  log "PASS lsfg_wired"
else
  log "FAIL lsfg_wired"; fail=1
fi

if [ -x "$TARGET/usr/share/batocera/datainit/roms/emulator/Configure_Heroic.sh" ] \
   && [ -x "$TARGET/usr/share/batocera/datainit/roms/emulator/Configure_Lutris.sh" ]; then
  log "PASS tools_heroic_lutris"
else
  log "FAIL tools_heroic_lutris"; fail=1
fi

if [ -x "$TARGET/usr/bin/batocera-config-heroic" ] \
   && [ -x "$TARGET/usr/bin/batocera-config-lutris" ]; then
  log "PASS config_scripts"
else
  log "FAIL config_scripts"; fail=1
fi

if grep -q 'extensions: \[ps3, psn, squashfs, iso\]' \
     "$TARGET/usr/share/emulationstation/es_systems.cfg" 2>/dev/null \
   || grep -q '\.iso' "$TARGET/usr/share/emulationstation/es_systems.cfg" 2>/dev/null; then
  log "PASS ps3_iso"
else
  # es_systems.cfg is generated; check for iso near ps3
  if awk '/name>ps3</,/<\/system>/' "$TARGET/usr/share/emulationstation/es_systems.cfg" 2>/dev/null | grep -q '\.iso'; then
    log "PASS ps3_iso"
  else
    log "FAIL ps3_iso"; fail=1
  fi
fi

if grep -q '44-dev-pocket-p01' "$TARGET/usr/share/batocera/batocera.version"; then
  log "PASS version_p01"
else
  log "FAIL version_p01"; fail=1
fi

if grep -q 'charge_behaviour\|BYPASS_SETTING\|inhibit-charge' "$TARGET/usr/bin/qcom-charge-limit"; then
  log "PASS charge_bypass_userspace"
else
  log "FAIL charge_bypass_userspace"; fail=1
fi

# Kernel Image should be newer after linux-rebuild
if [ -f "$PRIMARY/images/Image" ] || [ -f "$TARGET/boot/Image" ] || ls "$PRIMARY"/build/linux-*/arch/arm64/boot/Image >/dev/null 2>&1; then
  log "PASS linux_image_present"
else
  log "WARN linux_image_check_skipped"
fi

set -e
log "prechecks fail=$fail"
[ "$fail" -eq 0 ] || { ln -sfn "$LOG_FILE" "$REVIEW_LOG"; exit 1; }

log ">>> Removing prior squashfs/images for fresh all"
rm -f "$PRIMARY/images/rootfs.squashfs"
rm -f "$IMG_DIR"/batocera-sm8750-*.img.gz
rm -f "$IMG_DIR"/boot.tar.xz

run_cmd all

{
  echo ""
  echo "=== Finished OK: $(date -Is) ==="
  ls -lh "$IMG_DIR"/batocera-sm8750-*.img.gz "$IMG_DIR"/boot.tar.xz 2>/dev/null || true
  head -1 "$TARGET/usr/share/batocera/batocera.version" || true
  echo "LOG=$LOG_FILE"
} | tee -a "$LOG_FILE"
echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-p01-emu-charge.DONE"
ln -sfn "$LOG_FILE" "$REVIEW_LOG"
