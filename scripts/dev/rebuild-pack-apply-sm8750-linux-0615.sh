#!/usr/bin/env bash
# Rebuild userspace changes (keep already-built linux 0615 + cairo), pack OTA,
# apply on the Odin, reboot, verify squashfs contents.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_DIR"

CHAIN_LOG="${CHAIN_LOG:-$PROJECT_DIR/rebuild-pack-apply-sm8750-linux-0615.log}"
HOST="${HOST:-root@10.10.10.115}"
PW="${PW:-linux}"
export SKIP_LINUX="${SKIP_LINUX:-1}"
export SKIP_GOBJECT="${SKIP_GOBJECT:-1}"
export DOCKER_OPTS="${DOCKER_OPTS:---dns 9.9.9.9 --dns 1.1.1.1}"

: >"$CHAIN_LOG"
rm -f "$PROJECT_DIR/rebuild-pack-apply-sm8750-linux-0615.DONE" \
      "$PROJECT_DIR/rebuild-pack-apply-sm8750-linux-0615.FAILED" \
      "$PROJECT_DIR/rebuild-pack-apply-sm8750-linux-0615.VERIFY"

log() { printf '%s\n' "$*" | tee -a "$CHAIN_LOG"; }
SSH() { sshpass -p "$PW" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$HOST" "$@"; }

fail() {
  log "FAILED: $*"
  echo "FAILED $* $(date -Is)" >"$PROJECT_DIR/rebuild-pack-apply-sm8750-linux-0615.FAILED"
  exit 1
}

log "=== chain start $(date -Is) SKIP_LINUX=$SKIP_LINUX SKIP_GOBJECT=$SKIP_GOBJECT ==="

log ">>> rebuild"
./scripts/dev/rebuild-sm8750-linux-0615.sh || fail rebuild
log ">>> pack"
./scripts/dev/pack-sm8750-linux-0615-ota.sh || fail pack

T="$PROJECT_DIR/output/sm8750/target"
HP_STAGE="$PROJECT_DIR/output/sm8750/hotpatch-refresh"
mkdir -p "$HP_STAGE"
cp -a "$T/usr/libexec/onscreen-keyboard/wvkbd-mobintl" "$HP_STAGE/"
cp -a "$T/usr/bin/onscreen-keyboard" "$HP_STAGE/"
cp -a "$T/usr/bin/batocera-osk-sway-shift" "$HP_STAGE/"
cp -a "$T/etc/sway/config" "$HP_STAGE/config"
cp -a "$T/usr/share/batocera/splash/batocera.pocket-logo.png" "$HP_STAGE/"
log ">>> refresh device hotpatch from new target (no version/srt clobber)"
sshpass -p "$PW" scp -O -o StrictHostKeyChecking=no \
  "$HP_STAGE/wvkbd-mobintl" \
  "$HP_STAGE/onscreen-keyboard" \
  "$HP_STAGE/batocera-osk-sway-shift" \
  "$HP_STAGE/config" \
  "$HP_STAGE/batocera.pocket-logo.png" \
  "$HOST:/userdata/system/upgrade/hotpatch/" || fail hotpatch-scp
SSH 'cp -a /userdata/system/upgrade/hotpatch/wvkbd-mobintl /userdata/system/upgrade/hotpatch/wvkbd-mobintl-noexcl
     chmod 755 /userdata/system/upgrade/hotpatch/wvkbd-mobintl /userdata/system/upgrade/hotpatch/wvkbd-mobintl-noexcl
     rm -f /userdata/system/upgrade/hotpatch/batocera.version /userdata/system/upgrade/hotpatch/splash.srt' \
  || fail hotpatch-chmod

log ">>> apply OTA"
./scripts/dev/apply-sm8750-ota.sh || fail apply

log ">>> reboot"
SSH 'sync; reboot' || true
log "waiting for SSH after reboot"
ok=0
for i in $(seq 1 60); do
  sleep 10
  if SSH 'true' >/dev/null 2>&1; then
    ok=1
    log "SSH up after ${i}0s"
    break
  fi
  log "wait $i/60"
done
[ "$ok" = 1 ] || fail ssh-timeout

sleep 8
if ! ./scripts/dev/verify-sm8750-must-ship.sh device; then
  fail "must-ship-device"
fi

VERIFY="$PROJECT_DIR/rebuild-pack-apply-sm8750-linux-0615.VERIFY"
SSH 'bash -s' >"$VERIFY" 2>&1 <<'REMOTE' || true
echo "=== version ==="
cat /usr/share/batocera/batocera.version
echo "=== splash.srt ==="
cat /usr/share/batocera/splash/splash.srt
echo "=== swaybg ==="
grep "output \* bg" /etc/sway/config
ls -l /usr/share/batocera/splash/batocera.pocket-logo.png
pgrep -af swaybg | grep -v pgrep || true
echo "=== osk ==="
grep -n discord_running /usr/bin/onscreen-keyboard | head
echo "=== mouse M2 ==="
grep -n PADDLE_M2 /usr/bin/batocera-mouse-mode | head
echo "=== ps2/ps3 ==="
grep -c anyFile /usr/bin/batocera-systems || true
python3 - <<'PY'
import sys
sys.path.insert(0, "/usr/lib/python3.12/site-packages")
try:
    from configgen.generators.rpcs3.rpcs3Paths import RPCS3_SHARE_PATCH
    print("RPCS3_SHARE_PATCH", RPCS3_SHARE_PATCH)
except Exception as e:
    print("RPCS3_FAIL", e)
try:
    from configgen.emulatorlauncher import get_generator
    g = get_generator("rpcs3")
    print("rpcs3_generator", type(g).__name__)
except Exception as e:
    print("rpcs3_gen_fail", e)
PY
echo "=== oled ==="
command -v batocera-oled-care
ls -l /etc/init.d/S33oledcare
batocera-oled-care status 2>/dev/null | head -20 || true
echo "=== kernel wifi ==="
zcat /proc/config.gz 2>/dev/null | grep CERTIFICATION_ONUS || true
echo "=== lutris cairo ==="
python3 -c "from gi import _gi_cairo; print('gi_cairo_ok')" 2>/dev/null || echo gi_cairo_missing
REMOTE

log "=== verify dump ==="
tee -a "$CHAIN_LOG" <"$VERIFY"

failn=0
grep -q '^44-pocket ' "$VERIFY" || { log "VERIFY fail version"; failn=1; }
grep -q 'golden-rabbit' "$VERIFY" && { log "VERIFY fail long version still present"; failn=1; }
grep -q '44-pocket' "$VERIFY" || { log "VERIFY fail splash srt"; failn=1; }
grep -q 'batocera.pocket-logo.png' "$VERIFY" || { log "VERIFY fail logo"; failn=1; }
grep -q discord_running "$VERIFY" || { log "VERIFY fail osk shift"; failn=1; }
grep -q PADDLE_M2 "$VERIFY" || { log "VERIFY fail M2"; failn=1; }
grep -q anyFile "$VERIFY" || { log "VERIFY fail ps2"; failn=1; }
grep -q RPCS3_SHARE_PATCH "$VERIFY" || { log "VERIFY fail rpcs3"; failn=1; }
grep -q batocera-oled-care "$VERIFY" || { log "VERIFY fail oled"; failn=1; }

if [ "$failn" -ne 0 ]; then
  fail "verify (see $VERIFY)"
fi

echo "OK $(date -Is)" >"$PROJECT_DIR/rebuild-pack-apply-sm8750-linux-0615.DONE"
log "=== CHAIN OK $(date -Is) ==="
