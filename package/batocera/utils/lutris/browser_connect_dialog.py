"""Login via the system browser instead of embedded WebKit.

Google and other IdPs often refuse or hang inside WebKitGTK. On Batocera
handhelds, Firefox also mishandles touch taps (scroll/pinch work, buttons
do not). Default to Chrome for OAuth; Firefox remains available if chosen.

Lutris recovers the redirect URL from browser history (or a paste field),
splits the screen (Lutris left / browser right), and closes the browser
when login finishes.
"""

from __future__ import annotations

import json
import os
import shutil
import sqlite3
import subprocess
import tempfile
import time
from gettext import gettext as _
from typing import TYPE_CHECKING, List, Optional, Tuple
from urllib.parse import urlparse

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk  # type: ignore[attr-defined]

from lutris.gui.dialogs import ModelessDialog
from lutris.util.log import logger

if TYPE_CHECKING:
    from lutris.services.base import OnlineService

# Chrome stores visit times as µs since 1601-01-01.
_CHROME_EPOCH_DELTA = 11644473600


def _firefox_places_candidates() -> List[str]:
    homes = [
        os.environ.get("BATOCERA_FIREFOX_HOME", "/userdata/saves/apps/firefox"),
        os.path.expanduser("~"),
    ]
    out: List[str] = []
    for home in homes:
        if not home:
            continue
        for root in (
            os.path.join(home, ".config", "mozilla", "firefox"),
            os.path.join(home, ".mozilla", "firefox"),
        ):
            if not os.path.isdir(root):
                continue
            for dirpath, _dirnames, filenames in os.walk(root):
                if "places.sqlite" in filenames:
                    out.append(os.path.join(dirpath, "places.sqlite"))
    return out


def _chrome_history_candidates() -> List[str]:
    homes = [
        os.environ.get("BATOCERA_CHROME_HOME", "/userdata/saves/apps/chrome"),
        os.path.expanduser("~"),
    ]
    out: List[str] = []
    for home in homes:
        if not home:
            continue
        for rel in (
            ".config/google-chrome/Default/History",
            ".config/chromium/Default/History",
            ".config/google-chrome-unstable/Default/History",
        ):
            path = os.path.join(home, rel)
            if os.path.isfile(path):
                out.append(path)
    return out


def _query_like_urls(db_path: str, sql: str, params: tuple) -> Optional[str]:
    tmp = None
    try:
        fd, tmp = tempfile.mkstemp(prefix="lutris-browser-db-", suffix=".sqlite")
        os.close(fd)
        shutil.copy2(db_path, tmp)
        # Chrome often has -wal; best-effort copy beside
        for suffix in ("-wal", "-shm"):
            side = db_path + suffix
            if os.path.isfile(side):
                try:
                    shutil.copy2(side, tmp + suffix)
                except OSError:
                    pass
        conn = sqlite3.connect(tmp)
        try:
            cur = conn.cursor()
            cur.execute(sql, params)
            row = cur.fetchone()
            if row and row[0]:
                return row[0]
        finally:
            conn.close()
    except Exception as exc:  # pylint: disable=broad-except
        logger.debug("Browser DB probe failed for %s: %s", db_path, exc)
    finally:
        if tmp and os.path.exists(tmp):
            try:
                os.remove(tmp)
            except OSError:
                pass
            for suffix in ("-wal", "-shm"):
                side = tmp + suffix
                if os.path.exists(side):
                    try:
                        os.remove(side)
                    except OSError:
                        pass
    return None


def _find_redirect_in_history(redirect_uris: List[str], since_ts: float) -> Optional[str]:
    """Return the newest history URL matching a redirect prefix."""
    if not redirect_uris:
        return None
    since_us = int(since_ts * 1_000_000)
    since_chrome = int((since_ts + _CHROME_EPOCH_DELTA) * 1_000_000)

    for places in _firefox_places_candidates():
        for prefix in redirect_uris:
            url = _query_like_urls(
                places,
                "SELECT url FROM moz_places "
                "WHERE url LIKE ? AND IFNULL(last_visit_date, 0) >= ? "
                "ORDER BY last_visit_date DESC LIMIT 1",
                (prefix + "%", since_us),
            )
            if url:
                return url

    for history in _chrome_history_candidates():
        for prefix in redirect_uris:
            url = _query_like_urls(
                history,
                "SELECT url FROM urls "
                "WHERE url LIKE ? AND IFNULL(last_visit_time, 0) >= ? "
                "ORDER BY last_visit_time DESC LIMIT 1",
                (prefix + "%", since_chrome),
            )
            if url:
                return url
    return None


def _browser_command(url: str) -> List[str]:
    explicit = os.environ.get("BATOCERA_LUTRIS_BROWSER", "").strip()
    # Prefer Chrome on Batocera handhelds: Firefox Wayland often scrolls/zooms
    # but does not deliver button clicks from touch taps.
    candidates = []
    if explicit:
        candidates.append(explicit)
    candidates.extend(
        (
            "/usr/bin/batocera-app-chrome",
            "/usr/share/batocera/apps/google-chrome/google-chrome",
            "/usr/bin/batocera-app-firefox",
            "/usr/share/batocera/apps/firefox/firefox",
            "google-chrome",
            "chromium",
            "firefox",
            "xdg-open",
        )
    )
    for candidate in candidates:
        if candidate in ("firefox", "xdg-open", "google-chrome", "chromium"):
            if not shutil.which(candidate):
                continue
            return [candidate, url]
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            # Chrome needs a few touch-friendly flags when invoked directly.
            if "chrome" in candidate or "chromium" in candidate:
                return [
                    candidate,
                    "--no-sandbox",
                    "--ozone-platform=wayland",
                    "--touch-events=enabled",
                    "--enable-features=OverlayScrollbar",
                    url,
                ]
            return [candidate, url]
    return ["xdg-open", url]


def _browser_env() -> dict:
    """Launch the browser without Lutris DPI/scale overrides (breaks touch taps)."""
    env = os.environ.copy()
    for key in (
        "GDK_SCALE",
        "GDK_DPI_SCALE",
        "GTK_THEME",
        "QT_SCALE_FACTOR",
        "QT_FONT_DPI",
        "QT_AUTO_SCREEN_SCALE_FACTOR",
        "WL_OUTPUT_SCALE",
        "BATOCERA_UI_SCALE",
    ):
        env.pop(key, None)
    env["MOZ_ENABLE_WAYLAND"] = "1"
    env["GDK_BACKEND"] = "wayland"

    cmd0 = (_browser_command("about:blank") or ["firefox"])[0]
    if "chrome" in cmd0 or "chromium" in cmd0:
        home = os.environ.get("BATOCERA_CHROME_HOME", "/userdata/saves/apps/chrome")
    else:
        home = os.environ.get("BATOCERA_FIREFOX_HOME", "/userdata/saves/apps/firefox")
    env["HOME"] = home
    env["XDG_CONFIG_HOME"] = os.path.join(home, ".config")
    env["XDG_DATA_HOME"] = os.path.join(home, ".local", "share")
    env["XDG_CACHE_HOME"] = os.path.join(home, ".cache")
    return env


def _sway(*args: str) -> bool:
    if not shutil.which("swaymsg"):
        return False
    try:
        subprocess.run(
            ["swaymsg", *args],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=5,
        )
        return True
    except (OSError, subprocess.TimeoutExpired):
        return False


def _sway_tree() -> Optional[dict]:
    if not shutil.which("swaymsg"):
        return None
    try:
        out = subprocess.check_output(["swaymsg", "-t", "get_tree"], text=True, timeout=5)
        return json.loads(out)
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError, subprocess.CalledProcessError):
        return None


def _sway_output_size() -> Tuple[int, int]:
    if not shutil.which("swaymsg"):
        return (1280, 720)
    try:
        outs = json.loads(
            subprocess.check_output(["swaymsg", "-t", "get_outputs"], text=True, timeout=5)
        )
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError, subprocess.CalledProcessError):
        return (1280, 720)
    out = next((o for o in outs if o.get("focused")), None) or next(
        (o for o in outs if o.get("active")), None
    )
    if not out:
        return (1280, 720)
    rect = out.get("rect") or {}
    return int(rect.get("width") or 1280), int(rect.get("height") or 720)


def _walk_nodes(node: dict):
    yield node
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        yield from _walk_nodes(child)


def _find_con_ids(pred) -> List[int]:
    tree = _sway_tree()
    if not tree:
        return []
    ids: List[int] = []
    for n in _walk_nodes(tree):
        try:
            if pred(n) and n.get("id") is not None:
                ids.append(int(n["id"]))
        except (TypeError, ValueError):
            continue
    return ids


def _is_browser_win(n: dict) -> bool:
    app = (n.get("app_id") or "").lower()
    name = (n.get("name") or "").lower()
    cls = ((n.get("window_properties") or {}).get("class") or "").lower()
    blob = f"{app} {name} {cls}"
    return any(
        key in blob
        for key in (
            "firefox",
            "mozilla",
            "chrome",
            "chromium",
            "google-chrome",
        )
    )


def _is_lutris_main(n: dict) -> bool:
    app = (n.get("app_id") or "").lower()
    name = (n.get("name") or "")
    return "lutris" in app and name == "Lutris"


def _place_floating(con_id: int, x: int, y: int, w: int, h: int, focus: bool = False) -> None:
    _sway(f"[con_id={con_id}] floating enable")
    _sway(f"[con_id={con_id}] fullscreen disable")
    _sway(f"[con_id={con_id}] border pixel 2")
    _sway(f"[con_id={con_id}] resize set {w} px {h} px")
    _sway(f"[con_id={con_id}] move absolute position {x} {y}")
    if focus:
        _sway(f"[con_id={con_id}] focus")


def _browser_focus_target(nodes: List[dict]) -> Optional[int]:
    """Prefer Google/OAuth popups over the original service login tab."""
    if not nodes:
        return None
    ranked: List[Tuple[int, int]] = []
    for n in nodes:
        name = (n.get("name") or "").lower()
        score = 0
        if "google" in name:
            score += 100
        if "sign in" in name or "accounts.google" in name:
            score += 50
        if "login" in name or "auth" in name:
            score += 10
        if "gog.com" in name or "epic" in name:
            score -= 20
        ranked.append((score, int(n["id"])))
    ranked.sort()
    return ranked[-1][1]


def _arrange_login_split() -> bool:
    """Lutris left / browser right (no overlap); focus the OAuth window."""
    ow, oh = _sway_output_size()
    left_w = max(320, ow // 2)
    right_w = max(320, ow - left_w)

    tree = _sway_tree()
    if not tree:
        return False

    lutris_ids: List[int] = []
    browser_nodes: List[dict] = []
    for n in _walk_nodes(tree):
        if _is_lutris_main(n) and n.get("id") is not None:
            lutris_ids.append(int(n["id"]))
        if _is_browser_win(n) and n.get("id") is not None:
            browser_nodes.append(n)
    if not browser_nodes:
        return False

    for cid in lutris_ids:
        _place_floating(cid, 0, 0, left_w, oh, focus=False)

    focus_id = _browser_focus_target(browser_nodes)
    for n in browser_nodes:
        cid = int(n["id"])
        _place_floating(cid, left_w, 0, right_w, oh, focus=(cid == focus_id))
    if focus_id is not None:
        _sway(f"[con_id={focus_id}] focus")
    return True


def _restore_lutris_fullscreen() -> None:
    ow, oh = _sway_output_size()
    for cid in _find_con_ids(_is_lutris_main):
        _place_floating(cid, 0, 0, ow, oh, focus=True)
        _sway(f"[con_id={cid}] border none")


def _kill_browser_windows() -> None:
    for cid in _find_con_ids(_is_browser_win):
        _sway(f"[con_id={cid}] kill")
    for pattern in (
        "/usr/share/batocera/apps/google-chrome/chrome",
        "/usr/share/batocera/apps/google-chrome/google-chrome",
        "/usr/bin/batocera-app-chrome",
        "/usr/share/batocera/apps/firefox/firefox-bin",
        "/usr/bin/batocera-app-firefox",
    ):
        try:
            subprocess.run(
                ["pkill", "-TERM", "-f", pattern],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
                timeout=5,
            )
        except (OSError, subprocess.TimeoutExpired):
            pass


class BrowserConnectDialog(ModelessDialog):
    """Open auth URL in Chrome/Firefox (split-screen) and finish on redirect."""

    def __init__(self, service: "OnlineService", parent=None):
        if service.is_login_in_progress:
            service.wipe_game_cache()

        service.is_login_in_progress = True
        self.service = service
        self._started = time.time()
        self._browser_proc: Optional[subprocess.Popen] = None
        self._poll_id = 0
        self._layout_id = 0
        self._layout_tries = 0
        self._finished = False
        self._split_done = False

        super().__init__(title=_("%s login") % service.name, parent=parent)
        self.set_default_size(420, 220)
        self.set_keep_above(False)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, margin=14)
        self.get_content_area().pack_start(box, True, True, 0)

        label = Gtk.Label(
            label=_(
                "A browser opens on the right so you can sign in to {service}.\n"
                "Use Google or any other provider as usual (touch works best in Chrome).\n\n"
                "When login succeeds, Lutris detects it and closes the browser "
                "automatically. If not, paste the address-bar URL and press Continue."
            ).format(service=service.name)
        )
        label.set_line_wrap(True)
        label.set_xalign(0.0)
        box.pack_start(label, False, False, 0)

        self.url_entry = Gtk.Entry()
        self.url_entry.set_placeholder_text(_("https://…/on_login_success?code=…"))
        box.pack_start(self.url_entry, False, False, 0)

        buttons = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        box.pack_end(buttons, False, False, 0)

        cancel_btn = Gtk.Button(label=_("Cancel"))
        cancel_btn.connect("clicked", self._on_cancel)
        buttons.pack_start(cancel_btn, False, False, 0)

        open_btn = Gtk.Button(label=_("Open browser"))
        open_btn.connect("clicked", lambda *_: self._open_browser())
        buttons.pack_start(open_btn, False, False, 0)

        cont_btn = Gtk.Button(label=_("Continue"))
        cont_btn.get_style_context().add_class("suggested-action")
        cont_btn.connect("clicked", self._on_continue)
        buttons.pack_end(cont_btn, False, False, 0)

        self.connect("delete-event", self._on_delete)
        self.show_all()
        GLib.idle_add(self._place_helper_dialog)
        self._open_browser()
        self._layout_id = GLib.timeout_add(300, self._poll_layout)
        self._poll_id = GLib.timeout_add_seconds(1, self._poll_redirect)

    def _place_helper_dialog(self) -> bool:
        ow, oh = _sway_output_size()
        left_w = max(320, ow // 2)
        title = self.get_title() or ""

        def match(n: dict) -> bool:
            return (n.get("name") or "") == title and "lutris" in (n.get("app_id") or "").lower()

        for cid in _find_con_ids(match):
            _place_floating(cid, 8, oh - 240, min(400, left_w - 16), 220, focus=False)
        return False

    def _open_browser(self) -> None:
        url = getattr(self.service, "login_url", None)
        if not url:
            logger.error("Service %s has no login_url", self.service.id)
            return
        cmd = _browser_command(url)
        logger.info("Opening browser for %s login: %s", self.service.id, cmd[0])
        self._split_done = False
        self._layout_tries = 0
        try:
            self._browser_proc = subprocess.Popen(  # pylint: disable=consider-using-with
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
                env=_browser_env(),
            )
        except OSError as exc:
            logger.error("Failed to open browser: %s", exc)
            return
        if not self._layout_id:
            self._layout_id = GLib.timeout_add(300, self._poll_layout)

    def _poll_layout(self) -> bool:
        if self._finished:
            self._layout_id = 0
            return False
        self._layout_tries += 1
        if _arrange_login_split():
            self._split_done = True
            self._place_helper_dialog()
            if self._layout_tries < 40:
                return True
            self._layout_id = 0
            return False
        if self._layout_tries > 80:
            self._layout_id = 0
            return False
        return True

    def _poll_redirect(self) -> bool:
        if self._finished:
            return False
        if self._split_done:
            for cid in _find_con_ids(_is_browser_win):
                _sway(f"[con_id={cid}] focus")
                break
        url = _find_redirect_in_history(list(self.service.redirect_uris), self._started - 5)
        if url:
            self._finish_with_url(url)
            return False
        return True

    def _on_continue(self, *_args) -> None:
        typed = (self.url_entry.get_text() or "").strip()
        if typed:
            self._finish_with_url(typed)
            return
        url = _find_redirect_in_history(list(self.service.redirect_uris), self._started - 5)
        if url:
            self._finish_with_url(url)
            return
        self.url_entry.set_placeholder_text(_("Success URL not detected yet…"))
        self.url_entry.grab_focus()

    def _url_matches_redirect(self, url: str) -> bool:
        return any(url.startswith(prefix) for prefix in self.service.redirect_uris)

    def _finish_with_url(self, url: str) -> None:
        if self._finished:
            return
        if not self._url_matches_redirect(url):
            parsed = urlparse(url)
            if "code=" not in (parsed.query or ""):
                logger.error("URL does not look like a login redirect: %s", url)
                self.url_entry.set_text(url)
                self.url_entry.set_placeholder_text(_("Invalid URL — paste the success URL"))
                return
        self._finished = True
        if self._poll_id:
            GLib.source_remove(self._poll_id)
            self._poll_id = 0
        if self._layout_id:
            GLib.source_remove(self._layout_id)
            self._layout_id = 0
        try:
            self.service.login_callback(url)
        except Exception:  # pylint: disable=broad-except
            logger.exception("login_callback failed for %s", self.service.id)
        finally:
            self.service.is_login_in_progress = False
        self._close_browser()
        _restore_lutris_fullscreen()
        self.response(Gtk.ResponseType.OK)
        self.destroy()

    def _close_browser(self) -> None:
        proc = self._browser_proc
        if proc:
            try:
                if proc.poll() is None:
                    proc.terminate()
            except OSError:
                pass
        _kill_browser_windows()

    def _on_cancel(self, *_args) -> None:
        self._abort()

    def _on_delete(self, *_args):
        self._abort()
        return False

    def _abort(self) -> None:
        if self._finished:
            return
        self._finished = True
        if self._poll_id:
            GLib.source_remove(self._poll_id)
            self._poll_id = 0
        if self._layout_id:
            GLib.source_remove(self._layout_id)
            self._layout_id = 0
        self.service.is_login_in_progress = False
        self._close_browser()
        _restore_lutris_fullscreen()
        self.response(Gtk.ResponseType.CANCEL)
        self.destroy()
