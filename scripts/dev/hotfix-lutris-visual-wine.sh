#!/usr/bin/env bash
# Hotfix Lutris visuals (covers/icons) + Batocera Wine defaults on a live Odin.
# Does not require a full image rebuild; package patches land on next OTA.
set -euo pipefail

HOST="${HOST:-root@10.10.10.115}"
PASS="${PASS:-linux}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"

sshpass -p "$PASS" scp -o StrictHostKeyChecking=no -o LogLevel=ERROR \
	"${REPO_ROOT}/package/batocera/utils/lutris/lutris" \
	"${HOST}:/usr/bin/lutris"

GI_DIR="${REPO_ROOT}/output/sm8750/target/usr/lib/python3.12/site-packages/gi"
if [ -f "${GI_DIR}/_gi_cairo.cpython-312-aarch64-linux-gnu.so" ]; then
	sshpass -p "$PASS" scp -o StrictHostKeyChecking=no -o LogLevel=ERROR \
		"${GI_DIR}/_gi_cairo.cpython-312-aarch64-linux-gnu.so" \
		"${GI_DIR}/_gi.cpython-312-aarch64-linux-gnu.so" \
		"${HOST}:/usr/lib/python3.12/site-packages/gi/"
fi


sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
export HOME=/userdata/saves/lutris

python3 - <<'PY'
from pathlib import Path

# --- utils.py: cairo fallback ---
utils = Path("/usr/lib/python3.12/site-packages/lutris/gui/widgets/utils.py")
text = utils.read_text()
if "_pixbuf_as_cairo_surface" not in text:
    if "import tempfile" not in text:
        text = text.replace("import array\n", "import array\nimport tempfile\n", 1)
    helper = '''
def _pixbuf_as_cairo_surface(pixbuf):
    """Convert a GdkPixbuf to a Cairo ImageSurface without gi-cairo bindings."""
    try:
        _success, png_bytes = pixbuf.save_to_bufferv("png", [], [])
    except Exception as ex:  # pylint: disable=broad-except
        logger.debug("pixbuf save_to_bufferv failed: %s", ex)
        return None
    if not png_bytes:
        return None
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
            tmp.write(png_bytes)
            tmp_path = tmp.name
        return cairo.ImageSurface.create_from_png(tmp_path)
    except Exception as ex:  # pylint: disable=broad-except
        logger.debug("cairo create_from_png failed: %s", ex)
        return None
    finally:
        if tmp_path:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass


'''
    needle = "def get_scaled_surface_by_path(path, size, device_scale, preserve_aspect_ratio=True):"
    if needle not in text:
        raise SystemExit("get_scaled_surface_by_path not found")
    text = text.replace(needle, helper + needle, 1)
    old = """    surface = cairo.ImageSurface(cairo.Format.ARGB32, pixel_width, pixel_height)  # pylint:disable=no-member
    cr = cairo.Context(surface)  # pylint:disable=no-member
    cr.scale(scale_x, scale_y)
    Gdk.cairo_set_source_pixbuf(cr, pixbuf, 0, 0)
    cr.get_source().set_extend(cairo.Extend.PAD)  # pylint: disable=no-member
    cr.paint()
    surface.set_device_scale(device_scale, device_scale)
    return surface
"""
    new = """    surface = cairo.ImageSurface(cairo.Format.ARGB32, pixel_width, pixel_height)  # pylint:disable=no-member
    cr = cairo.Context(surface)  # pylint:disable=no-member
    cr.scale(scale_x, scale_y)
    try:
        Gdk.cairo_set_source_pixbuf(cr, pixbuf, 0, 0)
        cr.get_source().set_extend(cairo.Extend.PAD)  # pylint: disable=no-member
    except (TypeError, KeyError, AttributeError, GLib.Error):
        tmp_surface = _pixbuf_as_cairo_surface(pixbuf)
        if not tmp_surface:
            return None
        cr.set_source_surface(tmp_surface, 0, 0)
        try:
            cr.get_source().set_extend(cairo.Extend.PAD)  # pylint: disable=no-member
        except Exception:  # pylint: disable=broad-except
            pass
    cr.paint()
    surface.set_device_scale(device_scale, device_scale)
    return surface
"""
    if old not in text:
        raise SystemExit("cairo paint block not found for patch")
    text = text.replace(old, new, 1)
    utils.write_text(text)
    print("patched utils.py")
else:
    print("utils.py already patched")

# --- egs.py: truncated JPEGs ---
egs = Path("/usr/lib/python3.12/site-packages/lutris/services/egs.py")
text = egs.read_text()
if "LOAD_TRUNCATED_IMAGES" not in text:
    text = text.replace(
        "from gi.repository import Gio\n",
        "from gi.repository import Gio\nfrom PIL import ImageFile\n",
        1,
    )
    text = text.replace(
        "EGS_GAME_ART_PATH = os.path.expanduser(\"~/.cache/lutris/egs/game_box\")\n",
        "ImageFile.LOAD_TRUNCATED_IMAGES = True\n\n"
        "EGS_GAME_ART_PATH = os.path.expanduser(\"~/.cache/lutris/egs/game_box\")\n",
        1,
    )
    old = """    def _render_filename(self, filename):
        game_box_path = os.path.join(self.dest_path, filename)
        logo_path = os.path.join(EGS_LOGO_PATH, filename.replace(".jpg", ".png"))
        has_logo = os.path.exists(logo_path)
        thumb_image = Image.open(game_box_path)
        thumb_image = thumb_image.convert("RGBA")
        thumb_image = thumbnail_image(thumb_image, self.remote_size)
        if has_logo:
            logo_image = Image.open(logo_path)
            logo_image = logo_image.convert("RGBA")
            logo_width, logo_height = logo_image.size
            if logo_width > self.min_logo_x:
                logo_image = logo_image.resize(
                    (self.min_logo_x, int(logo_height * (self.min_logo_x / logo_width))),
                    resample=Image.Resampling.BICUBIC,
                )
            elif logo_height > self.min_logo_y:
                logo_image = logo_image.resize(
                    (int(logo_width * (self.min_logo_y / logo_height)), self.min_logo_y),
                    resample=Image.Resampling.BICUBIC,
                )
            thumb_image = paste_overlay(thumb_image, logo_image)
        thumb_path = os.path.join(self.dest_path, filename)
        thumb_image = thumb_image.convert("RGB")
        thumb_image.save(thumb_path)
"""
    new = """    def _render_filename(self, filename):
        try:
            game_box_path = os.path.join(self.dest_path, filename)
            logo_path = os.path.join(EGS_LOGO_PATH, filename.replace(".jpg", ".png"))
            has_logo = os.path.exists(logo_path)
            thumb_image = Image.open(game_box_path)
            thumb_image = thumb_image.convert("RGBA")
            thumb_image = thumbnail_image(thumb_image, self.remote_size)
            if has_logo:
                logo_image = Image.open(logo_path)
                logo_image = logo_image.convert("RGBA")
                logo_width, logo_height = logo_image.size
                if logo_width > self.min_logo_x:
                    logo_image = logo_image.resize(
                        (self.min_logo_x, int(logo_height * (self.min_logo_x / logo_width))),
                        resample=Image.Resampling.BICUBIC,
                    )
                elif logo_height > self.min_logo_y:
                    logo_image = logo_image.resize(
                        (int(logo_width * (self.min_logo_y / logo_height)), self.min_logo_y),
                        resample=Image.Resampling.BICUBIC,
                    )
                thumb_image = paste_overlay(thumb_image, logo_image)
            thumb_path = os.path.join(self.dest_path, filename)
            thumb_image = thumb_image.convert("RGB")
            thumb_image.save(thumb_path)
        except OSError as ex:
            logger.warning("Skipping corrupt EGS media %s: %s", filename, ex)
"""
    if old not in text:
        raise SystemExit("_render_filename block not found")
    text = text.replace(old, new, 1)
    egs.write_text(text)
    print("patched egs.py")
else:
    print("egs.py already patched")

# --- wine.py: Batocera defaults ---
wine = Path("/usr/lib/python3.12/site-packages/lutris/util/wine/wine.py")
text = wine.read_text()
if "BATOCERA_WINE_DEFAULT" not in text:
    text = text.replace(
        'GE_PROTON_LATEST: str = "ge-proton"\nWINE_PATHS: Dict[str, str] = {\n'
        '    "winehq-devel": "/opt/wine-devel/bin/wine",\n',
        'GE_PROTON_LATEST: str = "ge-proton"\n'
        'BATOCERA_WINE_DEFAULT: str = "wine-proton"\n'
        "WINE_PATHS: Dict[str, str] = {\n"
        '    "wine-proton": "/usr/wine/wine-proton/bin/wine",\n'
        '    "wine-tkg": "/usr/wine/wine-tkg/bin/wine",\n'
        '    "winehq-devel": "/opt/wine-devel/bin/wine",\n',
        1,
    )
    insert = '''    if system.path_exists("/usr/wine"):
        for _candidate in os.listdir("/usr/wine/"):
            _wine_path = os.path.join("/usr/wine/", _candidate, "bin/wine")
            if os.path.isfile(_wine_path) and _candidate not in WINE_PATHS:
                WINE_PATHS[_candidate] = _wine_path
'''
    marker = '                    WINE_PATHS["System " + _candidate] = _wine_path\n'
    if marker in text and insert not in text:
        text = text.replace(marker, marker + insert, 1)
    old_default = '''def get_default_wine_version() -> str:
    """Return the default version of wine."""
    return GE_PROTON_LATEST
'''
    new_default = '''def get_default_wine_version() -> str:
    """Return the default version of wine.

    Prefer Batocera-packaged Proton/TkG runners that ship in the image;
    fall back to umu ge-proton when those are absent.
    """
    for candidate in (BATOCERA_WINE_DEFAULT, "wine-tkg", GE_PROTON_LATEST):
        if candidate in WINE_PATHS and get_system_wine_version(WINE_PATHS[candidate]):
            return candidate
        if candidate == GE_PROTON_LATEST:
            try:
                proton.get_umu_path()
                return GE_PROTON_LATEST
            except Exception:
                continue
    return BATOCERA_WINE_DEFAULT
'''
    if old_default not in text:
        raise SystemExit("get_default_wine_version not found")
    text = text.replace(old_default, new_default, 1)
    wine.write_text(text)
    print("patched wine.py")
else:
    print("wine.py already patched")
PY

# Favorite/tag icon aliases (PNG)
for sz in 16x16 24x24 32x32 48x48; do
  mkdir -p "/usr/share/icons/hicolor/${sz}/actions"
  fav="/usr/share/icons/Adwaita/${sz}/emblems/emblem-favorite-symbolic.symbolic.png"
  star="/usr/share/icons/Adwaita/${sz}/status/starred-symbolic.symbolic.png"
  if [ -f "$fav" ]; then
    ln -snf "$fav" "/usr/share/icons/hicolor/${sz}/actions/favorite-symbolic.png"
    ln -snf "$fav" "/usr/share/icons/hicolor/${sz}/actions/tag-symbolic.png"
  elif [ -f "$star" ]; then
    ln -snf "$star" "/usr/share/icons/hicolor/${sz}/actions/favorite-symbolic.png"
    ln -snf "$star" "/usr/share/icons/hicolor/${sz}/actions/tag-symbolic.png"
  fi
done
gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true

# Convert runtime SVG service icons -> PNG
icon_root="/userdata/saves/lutris/.local/share/lutris/runtime/icons/hicolor"
if command -v rsvg-convert >/dev/null && [ -d "${icon_root}/scalable/apps" ]; then
  mkdir -p "${icon_root}/64x64/apps" "${icon_root}/24x24/apps"
  for svg in "${icon_root}/scalable/apps"/*.svg; do
    [ -f "$svg" ] || continue
    base="$(basename "$svg" .svg)"
    for size_dir in 64x64 24x24; do
      size="${size_dir%x*}"
      png="${icon_root}/${size_dir}/apps/${base}.png"
      rsvg-convert -w "$size" -h "$size" "$svg" -o "$png" 2>/dev/null || true
    done
  done
  if [ ! -f "${icon_root}/index.theme" ]; then
    cat > "${icon_root}/index.theme" <<'EOF'
[Icon Theme]
Name=Lutris Runtime
Comment=Lutris bundled service/runner icons
Directories=64x64/apps,24x24/apps,scalable/apps,symbolic/apps

[64x64/apps]
Size=64
Context=Applications
Type=Fixed

[24x24/apps]
Size=24
Context=Applications
Type=Fixed

[scalable/apps]
Size=128
Context=Applications
Type=Scalable
MinSize=1
MaxSize=256

[symbolic/apps]
Size=16
Context=Applications
Type=Scalable
MinSize=1
MaxSize=256
EOF
  fi
  echo "converted $(ls ${icon_root}/64x64/apps/*.png 2>/dev/null | wc -l) service icons to PNG"
fi

# Wire Batocera wines into runners tree
wine_dir="/userdata/saves/lutris/.local/share/lutris/runners/wine"
mkdir -p "$wine_dir"
for name in wine-proton wine-tkg; do
  if [ -x "/usr/wine/${name}/bin/wine" ]; then
    ln -snf "/usr/wine/${name}" "${wine_dir}/${name}"
  fi
done
ls -la "$wine_dir"

# Rebuild gdk-pixbuf loader cache from modules that actually exist.
cache=/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
if command -v gdk-pixbuf-query-loaders >/dev/null 2>&1; then
  gdk-pixbuf-query-loaders /usr/lib/gdk-pixbuf-2.0/2.10.0/loaders/*.so > "$cache"
  echo "regenerated gdk-pixbuf loaders.cache"
fi

# Sanity: cairo surface + wine default
export HOME=/userdata/saves/lutris
export SWAYSOCK=/var/run/sway-ipc.0.sock XDG_RUNTIME_DIR=/var/run WAYLAND_DISPLAY=wayland-1 GDK_BACKEND=wayland
python3 - <<'PY'
import os
os.environ["HOME"]="/userdata/saves/lutris"
import gi
gi.require_version("Gtk","3.0")
gi.require_version("Gdk","3.0")
from gi.repository import Gtk, Gdk
from lutris.gui.widgets.utils import get_scaled_surface_by_path
from lutris.util.wine.wine import get_default_wine_version, WINE_PATHS, get_installed_wine_versions
p="/userdata/saves/lutris/.cache/lutris/egs/game_box/abzu.jpg"
surf=get_scaled_surface_by_path(p,(158,89),1)
print("surface_ok", bool(surf), "size", surf.get_width() if surf else None)
print("default_wine", get_default_wine_version())
print("wine_paths", {k:v for k,v in WINE_PATHS.items() if k.startswith("wine-")})
print("installed_sample", sorted(get_installed_wine_versions())[:12])
# icon png exists
import os
print("egs.png", os.path.exists("/userdata/saves/lutris/.local/share/lutris/runtime/icons/hicolor/64x64/apps/egs.png"))
print("favorite-symbolic", os.path.exists("/usr/share/icons/hicolor/16x16/actions/favorite-symbolic.png"))
PY

echo "HOTFIX_OK"
REMOTE
