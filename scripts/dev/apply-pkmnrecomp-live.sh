#!/usr/bin/env bash
# Install Pokemon Recomp (gen1 + gen2 AppImages) on a live Odin without a full rebuild.
# AppImages go to userdata (not the overlay). Wrapper/configgen/ES stay in overlay.
#
# Usage:
#   ./scripts/dev/apply-pkmnrecomp-live.sh
#   ./scripts/dev/apply-pkmnrecomp-live.sh 10.10.10.115
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOST="${1:-10.10.10.115}"
USER_NAME="${HOTPATCH_USER:-root}"
PASS="${HOTPATCH_PASS:-linux}"
DL_DIR="${PKMNRECOMP_DL_DIR:-$ROOT/dl/pkmnrecomp}"
GEN1_AI="gen1recomp-0.1.99-linux-arm64.AppImage"
GEN2_AI="Gen2Recomped-0.7.10-linux-arm64.AppImage"

need() { [ -f "$1" ] || { echo "Missing: $1" >&2; exit 1; }; }
need "$ROOT/package/batocera/emulators/pkmnrecomp/pkmnrecomp"
need "$ROOT/package/batocera/core/batocera-configgen/configgen/configgen/generators/pkmnrecomp/pkmnrecompGenerator.py"
need "$DL_DIR/$GEN1_AI"
need "$DL_DIR/$GEN2_AI"
command -v sshpass >/dev/null || { echo "sshpass required" >&2; exit 1; }

SSH=(sshpass -p "$PASS" ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
SCP=(sshpass -p "$PASS" scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

echo "Installing pkmnrecomp on ${USER_NAME}@${HOST} ..."
"${SSH[@]}" "${USER_NAME}@${HOST}" 'mkdir -p /userdata/system/pkmnrecomp /userdata/roms/pkmnrecomp /userdata/system/upgrade/pkmnrecomp /tmp/pkmnrecomp-live'

"${SCP[@]}" \
  "$ROOT/package/batocera/emulators/pkmnrecomp/pkmnrecomp" \
  "$ROOT/package/batocera/core/batocera-configgen/configgen/configgen/generators/pkmnrecomp/pkmnrecompGenerator.py" \
  "${USER_NAME}@${HOST}:/tmp/pkmnrecomp-live/"

echo "Copying AppImages to userdata (not overlay) ..."
"${SCP[@]}" "$DL_DIR/$GEN1_AI" "${USER_NAME}@${HOST}:/userdata/system/pkmnrecomp/gen1recomp.AppImage"
"${SCP[@]}" "$DL_DIR/$GEN2_AI" "${USER_NAME}@${HOST}:/userdata/system/pkmnrecomp/gen2recomp.AppImage"

"${SSH[@]}" "${USER_NAME}@${HOST}" bash -s <<'REMOTE'
set -euo pipefail
chmod 0755 /tmp/pkmnrecomp-live/pkmnrecomp \
  /userdata/system/pkmnrecomp/gen1recomp.AppImage \
  /userdata/system/pkmnrecomp/gen2recomp.AppImage
cp -a /tmp/pkmnrecomp-live/pkmnrecomp /usr/bin/pkmnrecomp

PYDIR="$(python3 -c 'import configgen, os; print(os.path.dirname(configgen.__file__))')"
mkdir -p "${PYDIR}/generators/pkmnrecomp"
cp -a /tmp/pkmnrecomp-live/pkmnrecompGenerator.py "${PYDIR}/generators/pkmnrecomp/pkmnrecompGenerator.py"
touch "${PYDIR}/generators/pkmnrecomp/__init__.py"
python3 - "${PYDIR}/generators/importer.py" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
needle = "    'n64recomp': ('sh.shGenerator', 'ShGenerator'),"
insert = needle + "\n    'pkmnrecomp': ('pkmnrecomp.pkmnrecompGenerator', 'PkmnrecompGenerator'),"
if "pkmnrecomp" in text:
    print("importer.py already has pkmnrecomp")
elif needle not in text:
    raise SystemExit("importer.py: n64recomp line not found")
else:
    p.write_text(text.replace(needle, insert, 1))
    print("patched", p)
PY
python3 - /usr/share/batocera/configgen/configgen-defaults.yml <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
block = """pokemini:
  emulator: libretro
  core:     pokemini
pkmnrecomp:
  emulator: pkmnrecomp
  core:     gen1recomp
"""
if "\npkmnrecomp:\n" in text or text.startswith("pkmnrecomp:\n"):
    print("configgen-defaults.yml already has pkmnrecomp")
elif "pokemini:\n  emulator: libretro\n  core:     pokemini\n" not in text:
    # Fallback: append
    if not text.endswith("\n"):
        text += "\n"
    p.write_text(text + "pkmnrecomp:\n  emulator: pkmnrecomp\n  core:     gen1recomp\n")
    print("appended pkmnrecomp to", p)
else:
    p.write_text(text.replace(
        "pokemini:\n  emulator: libretro\n  core:     pokemini\n",
        block,
        1,
    ))
    print("patched", p)
PY

CFG=/usr/share/emulationstation/es_systems.cfg
if ! grep -q '<name>pkmnrecomp</name>' "$CFG"; then
  python3 - "$CFG" <<'PY'
import sys
from pathlib import Path
cfg = Path(sys.argv[1])
text = cfg.read_text()
needle = "</systemList>"
block = """  <system>
        <fullname>Pokemon Recomp</fullname>
        <name>pkmnrecomp</name>
        <manufacturer>Nintendo</manufacturer>
        <release>1996</release>
        <hardware>portable</hardware>
        <path>/userdata/roms/pkmnrecomp</path>
        <extension>.gb .gbc .GB .GBC</extension>
        <command>emulatorlauncher %CONTROLLERSCONFIG% -system %SYSTEM% -rom %ROM% -gameinfoxml %GAMEINFOXML% -systemname %SYSTEMNAME%</command>
        <platform>gb</platform>
        <theme>gb</theme>
        <emulators>
            <emulator name="pkmnrecomp">
                <cores>
                    <core default="true">gen1recomp</core>
                    <core>gen2recomp</core>
                </cores>
            </emulator>
        </emulators>
  </system>
"""
idx = text.rfind(needle)
if idx < 0:
    raise SystemExit("es_systems.cfg: missing </systemList>")
cfg.write_text(text[:idx] + block + text[idx:])
print("injected pkmnrecomp into", cfg)
PY
else
  echo "es_systems.cfg already has pkmnrecomp"
fi

FEAT=/usr/share/emulationstation/es_features.cfg
if [ -f "$FEAT" ] && ! grep -q 'name="pkmnrecomp"' "$FEAT"; then
  python3 - "$FEAT" <<'PY'
import sys
from pathlib import Path
cfg = Path(sys.argv[1])
text = cfg.read_text()
needle = "</features>"
block = """  <emulator name="pkmnrecomp" features="padtokeyboard">
    <sharedFeatures>
      <sharedFeature value="powermode" />
      <sharedFeature value="videomode" />
      <sharedFeature value="opengl_driver" />
      <sharedFeature value="gpu_performance_profile" />
    </sharedFeatures>
  </emulator>
"""
idx = text.rfind(needle)
if idx < 0:
    raise SystemExit("es_features.cfg: missing </features>")
cfg.write_text(text[:idx] + block + text[idx:])
print("injected pkmnrecomp features into", cfg)
PY
fi

cat > /userdata/roms/pkmnrecomp/_info.txt <<'EOF'
Pokemon Recomp
Place canonical US Red/Blue/Yellow (.gb/.gbc) and Gold/Silver/Crystal (.gbc) dumps here.
SHA-1 selects gen1recomp or gen2recomp. First launch imports the ROM (Gen 2 can take a few minutes).
EOF

echo "=== SHA-1 scan of gb/gbc (canonical only) ==="
python3 - <<'PY'
import hashlib, os
from pathlib import Path
wanted = {
    "ea9bcae617fdf159b045185467ae58b2e4a48b9a": ("red", "Pokemon Red.gb"),
    "d7037c83e1ae5b39bde3c30787637ba1d4c48ce2": ("blue", "Pokemon Blue.gb"),
    "cc7d03262ebfaf2f06772c1a480c7d9d5f4a38e1": ("yellow", "Pokemon Yellow.gbc"),
    "d8b8a3600a465308c9953dfa04f0081c05bdcb94": ("gold", "Pokemon Gold.gbc"),
    "49b163f7e57702bc939d642a18f591de55d92dae": ("silver", "Pokemon Silver.gbc"),
    "f2f52230b536214ef7c9924f483392993e226cfb": ("crystal", "Pokemon Crystal.gbc"),
    "f4cd194bdee0d04ca4eac29e09b8e4e9d818c133": ("crystal", "Pokemon Crystal.gbc"),
}
roots = [Path("/userdata/roms/gb"), Path("/userdata/roms/gbc"), Path("/userdata/roms/pkmnrecomp")]
found = {}
for root in roots:
    if not root.is_dir():
        continue
    for p in root.rglob("*"):
        if not p.is_file() or p.suffix.lower() not in {".gb", ".gbc"}:
            continue
        try:
            size = p.stat().st_size
        except OSError:
            continue
        if size not in (1048576, 2097152):
            continue
        h = hashlib.sha1(p.read_bytes()).hexdigest()
        if h in wanted:
            found[h] = p
            print(f"MATCH {wanted[h][0]}: {p}")
dest = Path("/userdata/roms/pkmnrecomp")
for h, (game, name) in wanted.items():
    if h not in found:
        continue
    src = found[h]
    target = dest / name
    if target.exists() or target.is_symlink():
        print(f"keep {target}")
        continue
    try:
        target.symlink_to(src)
        print(f"symlink {target} -> {src}")
    except OSError as exc:
        print(f"skip link {name}: {exc}")
if not found:
    print("No canonical dumps found under roms/gb or roms/gbc.")
    print("Copy your own US ROMs into /userdata/roms/pkmnrecomp/")
PY

batocera-save-overlay 50 || batocera-save-overlay || true
batocera-es-swissknife --restart || /etc/init.d/S31emulationstation restart || true
echo "pkmnrecomp live install done"
ls -l /usr/bin/pkmnrecomp /userdata/system/pkmnrecomp /userdata/roms/pkmnrecomp
REMOTE
