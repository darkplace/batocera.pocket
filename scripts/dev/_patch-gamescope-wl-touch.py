#!/usr/bin/env python3
"""Apply wl_touch wiring to gamescope WaylandBackend.cpp and emit a package patch."""
from __future__ import annotations

import difflib
import shutil
import sys
from pathlib import Path

SRC = Path(
    "/home/lukemotion/batocera.pocket/output/sm8750/build/gamescope-3.16.20"
    "/src/Backends/WaylandBackend.cpp"
)
OUT_PATCH = Path(
    "/home/lukemotion/batocera.pocket/package/batocera/utils/gamescope"
    "/001-rocknix-wayland-touch.patch"
)


def must_replace(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing block: {label}")
    return text.replace(old, new, 1)


def main() -> int:
    if not SRC.is_file():
        raise SystemExit(f"missing source: {SRC}")

    orig = SRC.read_text()
    text = orig

    text = must_replace(
        text,
        "\t\twl_surface *m_pCurrentCursorSurface = nullptr;\n\n"
        "        std::optional<wl_fixed_t> m_ofPendingCursorX;",
        "\t\twl_surface *m_pCurrentCursorSurface = nullptr;\n"
        "\t\twl_surface *m_pCurrentTouchSurface = nullptr;\n\n"
        "        std::optional<wl_fixed_t> m_ofPendingCursorX;",
        "current touch surface member",
    )

    text = must_replace(
        text,
        "\t    void Wayland_RelativePointer_RelativeMotion( zwp_relative_pointer_v1 *pRelativePointer, "
        "uint32_t uTimeHi, uint32_t uTimeLo, wl_fixed_t fDx, wl_fixed_t fDy, "
        "wl_fixed_t fDxUnaccel, wl_fixed_t fDyUnaccel );\n"
        "        static const zwp_relative_pointer_v1_listener s_RelativePointerListener;\n"
        "    };",
        "\t    void Wayland_RelativePointer_RelativeMotion( zwp_relative_pointer_v1 *pRelativePointer, "
        "uint32_t uTimeHi, uint32_t uTimeLo, wl_fixed_t fDx, wl_fixed_t fDy, "
        "wl_fixed_t fDxUnaccel, wl_fixed_t fDyUnaccel );\n"
        "        static const zwp_relative_pointer_v1_listener s_RelativePointerListener;\n\n"
        "        void Wayland_Touch_Down( wl_touch *pTouch, uint32_t uSerial, uint32_t uTime, "
        "wl_surface *pSurface, int32_t nId, wl_fixed_t fX, wl_fixed_t fY );\n"
        "        void Wayland_Touch_Up( wl_touch *pTouch, uint32_t uSerial, uint32_t uTime, int32_t nId );\n"
        "        void Wayland_Touch_Motion( wl_touch *pTouch, uint32_t uTime, int32_t nId, "
        "wl_fixed_t fX, wl_fixed_t fY );\n"
        "        void Wayland_Touch_Frame( wl_touch *pTouch );\n"
        "        void Wayland_Touch_Cancel( wl_touch *pTouch );\n"
        "        void Wayland_Touch_Shape( wl_touch *pTouch, int32_t nId, wl_fixed_t fMajor, "
        "wl_fixed_t fMinor );\n"
        "        void Wayland_Touch_Orientation( wl_touch *pTouch, int32_t nId, "
        "wl_fixed_t fOrientation );\n"
        "        static const wl_touch_listener s_TouchListener;\n"
        "    };",
        "touch method decls",
    )

    text = must_replace(
        text,
        "    const zwp_relative_pointer_v1_listener CWaylandInputThread::s_RelativePointerListener =\n"
        "    {\n"
        "        .relative_motion = WAYLAND_USERDATA_TO_THIS( CWaylandInputThread, "
        "Wayland_RelativePointer_RelativeMotion ),\n"
        "    };\n\n"
        "    class CWaylandBackend",
        "    const zwp_relative_pointer_v1_listener CWaylandInputThread::s_RelativePointerListener =\n"
        "    {\n"
        "        .relative_motion = WAYLAND_USERDATA_TO_THIS( CWaylandInputThread, "
        "Wayland_RelativePointer_RelativeMotion ),\n"
        "    };\n"
        "    const wl_touch_listener CWaylandInputThread::s_TouchListener =\n"
        "    {\n"
        "        .down        = WAYLAND_USERDATA_TO_THIS( CWaylandInputThread, Wayland_Touch_Down ),\n"
        "        .up          = WAYLAND_USERDATA_TO_THIS( CWaylandInputThread, Wayland_Touch_Up ),\n"
        "        .motion      = WAYLAND_USERDATA_TO_THIS( CWaylandInputThread, Wayland_Touch_Motion ),\n"
        "        .frame       = WAYLAND_USERDATA_TO_THIS( CWaylandInputThread, Wayland_Touch_Frame ),\n"
        "        .cancel      = WAYLAND_USERDATA_TO_THIS( CWaylandInputThread, Wayland_Touch_Cancel ),\n"
        "        .shape       = WAYLAND_USERDATA_TO_THIS( CWaylandInputThread, Wayland_Touch_Shape ),\n"
        "        .orientation = WAYLAND_USERDATA_TO_THIS( CWaylandInputThread, "
        "Wayland_Touch_Orientation ),\n"
        "    };\n\n"
        "    class CWaylandBackend",
        "touch listener table",
    )

    text = must_replace(
        text,
        "        if ( !!( uCapabilities & WL_SEAT_CAPABILITY_KEYBOARD ) != !!m_pKeyboard )\n"
        "        {\n"
        "            if ( m_pKeyboard )\n"
        "            {\n"
        "                wl_keyboard_release( m_pKeyboard );\n"
        "                m_pKeyboard = nullptr;\n"
        "            }\n"
        "            else\n"
        "            {\n"
        "                m_pKeyboard = wl_seat_get_keyboard( m_pSeat );\n"
        "                wl_keyboard_add_listener( m_pKeyboard, &s_KeyboardListener, this );\n"
        "            }\n"
        "        }\n"
        "    }\n\n"
        "    void CWaylandInputThread::Wayland_Seat_Name( wl_seat *pSeat, const char *pName )",
        "        if ( !!( uCapabilities & WL_SEAT_CAPABILITY_KEYBOARD ) != !!m_pKeyboard )\n"
        "        {\n"
        "            if ( m_pKeyboard )\n"
        "            {\n"
        "                wl_keyboard_release( m_pKeyboard );\n"
        "                m_pKeyboard = nullptr;\n"
        "            }\n"
        "            else\n"
        "            {\n"
        "                m_pKeyboard = wl_seat_get_keyboard( m_pSeat );\n"
        "                wl_keyboard_add_listener( m_pKeyboard, &s_KeyboardListener, this );\n"
        "            }\n"
        "        }\n\n"
        "        if ( !!( uCapabilities & WL_SEAT_CAPABILITY_TOUCH ) != !!m_pTouch )\n"
        "        {\n"
        "            if ( m_pTouch )\n"
        "            {\n"
        "                wl_touch_release( m_pTouch );\n"
        "                m_pTouch = nullptr;\n"
        "            }\n"
        "            else\n"
        "            {\n"
        "                m_pTouch = wl_seat_get_touch( m_pSeat );\n"
        "                wl_touch_add_listener( m_pTouch, &s_TouchListener, this );\n"
        "            }\n"
        "        }\n"
        "    }\n\n"
        "    void CWaylandInputThread::Wayland_Seat_Name( wl_seat *pSeat, const char *pName )",
        "seat touch capability",
    )

    impl = """    // Touch

    void CWaylandInputThread::Wayland_Touch_Down( wl_touch *pTouch, uint32_t uSerial, uint32_t uTime, wl_surface *pSurface, int32_t nId, wl_fixed_t fX, wl_fixed_t fY )
    {
        if ( !IsGamescopeToplevel( pSurface ) )
            return;

        m_pCurrentTouchSurface = pSurface;

        CWaylandPlane *pPlane = (CWaylandPlane *)wl_surface_get_user_data( m_pCurrentTouchSurface );
        if ( !pPlane )
            return;

        auto oState = pPlane->GetCurrentState();
        if ( !oState )
            return;

        uint32_t uScale = oState->uFractionalScale;
        double flX = ( wl_fixed_to_double( fX ) * uScale / 120.0 + oState->nDestX ) / g_nOutputWidth;
        double flY = ( wl_fixed_to_double( fY ) * uScale / 120.0 + oState->nDestY ) / g_nOutputHeight;

        wlserver_lock();
        wlserver_touchdown( flX, flY, nId, ++m_uFakeTimestamp );
        wlserver_unlock();
    }
    void CWaylandInputThread::Wayland_Touch_Up( wl_touch *pTouch, uint32_t uSerial, uint32_t uTime, int32_t nId )
    {
        wlserver_lock();
        wlserver_touchup( nId, ++m_uFakeTimestamp );
        wlserver_unlock();
    }
    void CWaylandInputThread::Wayland_Touch_Motion( wl_touch *pTouch, uint32_t uTime, int32_t nId, wl_fixed_t fX, wl_fixed_t fY )
    {
        if ( !m_pCurrentTouchSurface )
            return;

        CWaylandPlane *pPlane = (CWaylandPlane *)wl_surface_get_user_data( m_pCurrentTouchSurface );
        if ( !pPlane )
            return;

        auto oState = pPlane->GetCurrentState();
        if ( !oState )
            return;

        uint32_t uScale = oState->uFractionalScale;
        double flX = ( wl_fixed_to_double( fX ) * uScale / 120.0 + oState->nDestX ) / g_nOutputWidth;
        double flY = ( wl_fixed_to_double( fY ) * uScale / 120.0 + oState->nDestY ) / g_nOutputHeight;

        wlserver_lock();
        wlserver_touchmotion( flX, flY, nId, ++m_uFakeTimestamp );
        wlserver_unlock();
    }
    void CWaylandInputThread::Wayland_Touch_Frame( wl_touch *pTouch )
    {
    }
    void CWaylandInputThread::Wayland_Touch_Cancel( wl_touch *pTouch )
    {
        wlserver_lock();
        std::set<uint32_t> touchIds = wlserver.touch_down_ids;
        for ( uint32_t nId : touchIds )
            wlserver_touchup( nId, ++m_uFakeTimestamp );
        wlserver_unlock();

        m_pCurrentTouchSurface = nullptr;
    }
    void CWaylandInputThread::Wayland_Touch_Shape( wl_touch *pTouch, int32_t nId, wl_fixed_t fMajor, wl_fixed_t fMinor )
    {
    }
    void CWaylandInputThread::Wayland_Touch_Orientation( wl_touch *pTouch, int32_t nId, wl_fixed_t fOrientation )
    {
    }

    /////////////////////////
    // Backend Instantiator
    /////////////////////////"""

    text = must_replace(
        text,
        "    /////////////////////////\n"
        "    // Backend Instantiator\n"
        "    /////////////////////////",
        impl,
        "touch implementations",
    )

    if "#include <set>" not in text:
        text = text.replace(
            "#include <unordered_set>",
            "#include <unordered_set>\n#include <set>",
            1,
        )

    SRC.write_text(text)

    diff = difflib.unified_diff(
        orig.splitlines(keepends=True),
        text.splitlines(keepends=True),
        fromfile="a/src/Backends/WaylandBackend.cpp",
        tofile="b/src/Backends/WaylandBackend.cpp",
    )
    OUT_PATCH.write_text("".join(diff))
    disabled = OUT_PATCH.with_suffix(OUT_PATCH.suffix + ".disabled")
    if disabled.exists():
        disabled.unlink()

    print(f"wrote {OUT_PATCH} ({OUT_PATCH.stat().st_size} bytes)")
    print(f"updated in-tree source {SRC}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
