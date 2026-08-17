#!/bin/bash
# sm8750 OTA: 720p shadPS4 + community patches + Heroic/Lutris + ES force-kill resume.
# Docker tree only. Does NOT ship Lossless.dll (userdata-only).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

LOG_FILE="${LOG_FILE:-$PROJECT_DIR/rebuild-sm8750-720p-heroic.log}"
REVIEW_LOG="$PROJECT_DIR/output/upstream-review/rebuild-sm8750-720p-heroic.log"
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
    echo "=== batocera.pocket sm8750 720p/patches/Heroic OTA ==="
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
rm -f "$PROJECT_DIR/rebuild-sm8750-720p-heroic.DONE" "$PROJECT_DIR/rebuild-sm8750-720p-heroic.FAILED"

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
    echo "FAILED $pkg $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-720p-heroic.FAILED"
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
    echo "FAILED CMD=$cmd $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-720p-heroic.FAILED"
    ln -sfn "$LOG_FILE" "$REVIEW_LOG"
    exit "$ec"
  fi
  log "OK: CMD=$cmd"
}

skipping=0
[ -n "$RESUME_FROM" ] && skipping=1

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

run_cmd_gated olddefconfig

GUEST_SHADPS4="$PROJECT_DIR/output/sm8750_x86_64_v3_shadps4/target/usr/bin/shadps4/shadps4"
if [ "$skipping" -eq 1 ]; then
  log "SKIP side-build (resume from $RESUME_FROM)"
elif [ ! -x "$GUEST_SHADPS4" ]; then
  log ">>> x86_64 shadPS4 guest missing; building side tree"
  set +e
  stdbuf -oL -eL make sm8750_x86_64_v3_shadps4-build \
      DIRECT_BUILD="$DIRECT_BUILD" \
      PARALLEL_BUILD="$PARALLEL_BUILD" \
      BATCH_MODE=1 \
      MAKE_JLEVEL="${MAKE_JLEVEL:-12}" \
      MAKE_LLEVEL="${MAKE_LLEVEL:-12}" \
      >>"$LOG_FILE" 2>&1
  ec=$?
  set -e
  if [ "$ec" -ne 0 ]; then
    log "FAILED: sm8750_x86_64_v3_shadps4-build (exit $ec) at $(date -Is)"
    echo "FAILED shadps4-side $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-720p-heroic.FAILED"
    ln -sfn "$LOG_FILE" "$REVIEW_LOG"
    exit "$ec"
  fi
  log "OK: sm8750_x86_64_v3_shadps4-build"
else
  log "SKIP side-build (guest already at $GUEST_SHADPS4)"
fi

run_pkg_gated batocera-scripts-rebuild
run_pkg_gated batocera-configgen-rebuild
run_pkg_gated batocera-es-system-rebuild
run_pkg_gated batocera-emulationstation-reinstall
run_pkg_gated shadps4-fex-rebuild
run_pkg_gated heroic-rebuild
run_pkg_gated lutris-rebuild
run_pkg_gated batocera-desktopapps-reinstall
run_pkg_gated rpcs3-reinstall
run_pkg_gated cemu-reinstall
run_pkg_gated batocera-system-reinstall
run_cmd_gated target-finalize

if [ -x "$PROJECT_DIR/board/batocera/scripts/inject-shadps4-fex-rootfs.sh" ]; then
  log ">>> inject-shadps4-fex-rootfs"
  "$PROJECT_DIR/board/batocera/scripts/inject-shadps4-fex-rootfs.sh" \
      SM8750 "$PRIMARY/target" "$PROJECT_DIR" >>"$LOG_FILE" 2>&1 \
    || { echo FAILED inject >"$PROJECT_DIR/rebuild-sm8750-720p-heroic.FAILED"; ln -sfn "$LOG_FILE" "$REVIEW_LOG"; exit 1; }
fi

TARGET="$PRIMARY/target"

# Keep Odin 3 splash over generic reinstalls.
SPLASH_ODIN3="$PROJECT_DIR/package/batocera/core/batocera-splash-odin3"
install -m 0755 "$SPLASH_ODIN3/images/logo.png" \
  "$TARGET/usr/share/batocera/splash/boot-logo.png"
install -m 0755 "$SPLASH_ODIN3/images/logo-480p.png" \
  "$TARGET/usr/share/batocera/splash/boot-logo-4x3.png"
install -m 0755 "$SPLASH_ODIN3/videos/splash.mp4" \
  "$TARGET/usr/share/batocera/splash/splash.mp4"

install -m 0755 \
  "$PROJECT_DIR/package/batocera/emulationstation/batocera-emulationstation/S31emulationstation" \
  "$TARGET/etc/init.d/S31emulationstation"
install -m 0755 \
  "$PROJECT_DIR/package/batocera/core/batocera-scripts/scripts/batocera-es-swissknife" \
  "$TARGET/usr/bin/batocera-es-swissknife"

CG_DST=$(echo "$TARGET"/usr/lib/python*/site-packages/configgen/generators)
install -m 0644 "$CG_SRC/shadps4/shadps4Generator.py" "$CG_DST/shadps4/shadps4Generator.py"
install -m 0644 "$CG_SRC/rpcs3/rpcs3Generator.py" "$CG_DST/rpcs3/rpcs3Generator.py"
install -m 0644 "$CG_SRC/rpcs3/rpcs3Paths.py" "$CG_DST/rpcs3/rpcs3Paths.py"
install -m 0644 "$CG_SRC/cemu/cemuGenerator.py" "$CG_DST/cemu/cemuGenerator.py"
install -m 0644 \
  "$PROJECT_DIR/package/batocera/core/batocera-configgen/configs/configgen-defaults-sm8750.yml" \
  "$TARGET/usr/share/batocera/configgen/configgen-defaults-arch.yml"

log ""
log ">>> 720p/patches/Heroic target greps"
fail=0
set +e

if grep -q '_render_size' "$CG_DST/shadps4/shadps4Generator.py" \
   && grep -q 'shadps4_resolution' "$TARGET/usr/share/batocera/configgen/configgen-defaults-arch.yml"; then
  log "PASS shadps4_720p_lock"
else
  log "FAIL shadps4_720p_lock"; fail=1
fi

if [ -f "$TARGET/usr/share/shadps4/patches/shadPS4/Bloodborne.xml" ] \
   && [ -f "$TARGET/usr/share/shadps4/patches/shadPS4/files.json" ]; then
  log "PASS shadps4_community_patches"
else
  log "FAIL shadps4_community_patches"; fail=1
fi

if [ -s "$TARGET/usr/share/rpcs3/patches/patch.yml" ]; then
  log "PASS rpcs3_community_patches"
else
  log "FAIL rpcs3_community_patches"; fail=1
fi

if [ -d "$TARGET/usr/share/cemu/graphicPacks/Resolutions" ]; then
  log "PASS cemu_graphic_packs"
else
  log "FAIL cemu_graphic_packs"; fail=1
fi

if grep -q 'resume_es_if_suspended' "$TARGET/usr/bin/batocera-es-swissknife" \
   && grep -q 'pidof emulationstation' "$TARGET/etc/init.d/S31emulationstation"; then
  log "PASS es_forcekill_resume"
else
  log "FAIL es_forcekill_resume"; fail=1
fi

if [ -x "$TARGET/usr/bin/heroic" ] \
   || [ -x "$TARGET/usr/share/heroic/heroic.AppImage" ] \
   || ls "$TARGET"/usr/share/heroic/heroic-arm64/*/heroic >/dev/null 2>&1; then
  log "PASS heroic_installed"
else
  log "FAIL heroic_installed"; fail=1
fi

if [ -x "$TARGET/usr/bin/lutris" ]; then
  log "PASS lutris_installed"
else
  log "FAIL lutris_installed"; fail=1
fi

if [ -x "$TARGET/usr/share/batocera/apps/shadps4-fex-rootfs/usr/bin/shadps4/shadps4" ]; then
  log "PASS shadps4_fex_rootfs"
else
  log "FAIL shadps4_fex_rootfs"; fail=1
fi

if [ ! -e "$TARGET/usr/share/batocera/datainit/system/wine/lossless-scaling/Lossless.dll" ] \
   && [ ! -e "$TARGET/usr/wine/lsfg-vk/Lossless.dll" ]; then
  log "PASS lossless_dll_not_in_image"
else
  log "FAIL lossless_dll_not_in_image"; fail=1
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
  echo "LOG=$LOG_FILE"
} | tee -a "$LOG_FILE"
echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-sm8750-720p-heroic.DONE"
ln -sfn "$LOG_FILE" "$REVIEW_LOG"
