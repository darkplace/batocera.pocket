#!/bin/sh
# Apply Batocera Lutris browser-login hook into an installed lutris tree.
# Usage: apply-browser-login.sh <site-packages/lutris>
set -eu
ROOT="${1:?lutris package root}"
DIALOGS="$ROOT/gui/dialogs"
BASE="$ROOT/services/base.py"
SRC_DIALOG="$(dirname "$0")/browser_connect_dialog.py"

install -D -m 0644 "$SRC_DIALOG" "$DIALOGS/browser_connect_dialog.py"

python3 - "$BASE" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
needle = '''        logger.debug("Connecting to %s", self.name)
        dialog = WebConnectDialog(self, parent)
        dialog.run()'''
repl = '''        logger.debug("Connecting to %s", self.name)
        # Batocera: prefer Firefox for OAuth (Google, etc.). WebKitGTK often
        # hangs after password / 2FA inside the embedded WebConnectDialog.
        if os.environ.get("BATOCERA_LUTRIS_BROWSER_LOGIN", "1") == "1":
            from lutris.gui.dialogs.browser_connect_dialog import BrowserConnectDialog

            dialog = BrowserConnectDialog(self, parent)
        else:
            dialog = WebConnectDialog(self, parent)
        dialog.run()'''
if "BrowserConnectDialog" in text:
    print("already patched:", path)
    raise SystemExit(0)
if needle not in text:
    raise SystemExit(f"login hook not found in {path}")
if "import os" not in text.split("\n", 40)[0:40].__str__() and "\nimport os\n" not in text and not text.startswith("import os"):
    # base.py already imports os at top in stock Lutris
    pass
path.write_text(text.replace(needle, repl, 1), encoding="utf-8")
print("patched", path)
PY
