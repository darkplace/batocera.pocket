#!/bin/bash
set -euo pipefail

batocera-mouse show
trap 'batocera-mouse hide' EXIT

if ! python3 -c 'import libxml2' >/dev/null 2>&1; then
    if command -v batocera-flash-screen >/dev/null 2>&1; then
        batocera-flash-screen 8 "#ffffff" "virt-manager missing python libxml2 module." 20 >/dev/null 2>&1 || true
        batocera-flash-screen 8 "#ffffff" "Image needs python libxml2 package in build." 18 >/dev/null 2>&1 || true
    fi
    exit 1
fi

if ! batocera-services start libvirt >/dev/null 2>&1; then
    if command -v batocera-flash-screen >/dev/null 2>&1; then
        batocera-flash-screen 8 "#ffffff" "libvirt failed to start." 20 >/dev/null 2>&1 || true
        batocera-flash-screen 8 "#ffffff" "Check /userdata/system/logs/libvirt-service.log" 16 >/dev/null 2>&1 || true
    fi
    exit 1
fi

export GSETTINGS_SCHEMA_DIR="${GSETTINGS_SCHEMA_DIR:-/usr/share/glib-2.0/schemas}"
VIRT_MANAGER_URI="${VIRT_MANAGER_URI:-qemu:///system}"

exec /usr/bin/virt-manager --no-fork --connect "${VIRT_MANAGER_URI}"
