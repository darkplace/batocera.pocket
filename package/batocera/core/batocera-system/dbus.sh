#!/bin/sh

DBUS_SYSTEM_BUS="unix:path=/run/dbus/system_bus_socket"

# Keep a stable handle to the system bus, but do not clobber an existing
# session bus address (e.g. one created by dbus-launch in ES).
export DBUS_SYSTEM_BUS_ADDRESS="${DBUS_SYSTEM_BUS}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-${DBUS_SYSTEM_BUS}}"
