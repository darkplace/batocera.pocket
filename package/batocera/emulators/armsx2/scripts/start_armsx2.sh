#!/bin/sh

set -eu

ROM="$1"
CONFIG_HOME="${XDG_CONFIG_HOME:-/userdata/system/configs}"
DATA_ROOT="${CONFIG_HOME}/PCSX2"
INI="${DATA_ROOT}/inis/PCSX2.ini"

mkdir -p \
	"${DATA_ROOT}/cache" \
	"${DATA_ROOT}/covers" \
	"${DATA_ROOT}/inis" \
	"${DATA_ROOT}/inputprofiles" \
	"${DATA_ROOT}/logs" \
	"${DATA_ROOT}/textures" \
	"/userdata/bios/ps2" \
	"/userdata/cheats/ps2/cheats_ni" \
	"/userdata/cheats/ps2/cheats_ws" \
	"/userdata/saves/ps2/pcsx2/sstates" \
	"/userdata/saves/ps2/pcsx2/videos" \
	"/userdata/screenshots" \
	"/userdata/system/logs"

if [ ! -f "${INI}" ]; then
	cat > "${INI}" <<'EOF'
[UI]
SettingsVersion = 1
SetupWizardIncomplete = false
ConfirmShutdown = false
InhibitScreensaver = true
StartPaused = false
PauseOnFocusLoss = false
StartFullscreen = true
HideMouseCursor = true
RenderToSeparateWindow = false
HideMainWindowWhenRunning = true
DoubleClickTogglesFullscreen = false

[Achievements]
Enabled = false

[EmuCore/GS]
Renderer = 14
DisableFramebufferFetch = false
OverrideTextureBarriers = -1
DisableMailboxPresentation = false

[Folders]
Bios = ../../../bios/ps2
Snapshots = ../../../screenshots
Savestates = ../../../saves/ps2/pcsx2/sstates
MemoryCards = ../../../saves/ps2/pcsx2
Logs = ../../logs
Cheats = ../../../cheats/ps2
CheatsWS = ../../../cheats/ps2/cheats_ws
CheatsNI = ../../../cheats/ps2/cheats_ni
Cache = ../../cache/ps2
Textures = textures
InputProfiles = inputprofiles
Videos = ../../../saves/ps2/pcsx2/videos
EOF
fi

if [ ! -f "${DATA_ROOT}/game_controller_db.txt" ]; then
	if [ -f /usr/share/evmapy/gamecontrollerdb.txt ]; then
		cp -f /usr/share/evmapy/gamecontrollerdb.txt "${DATA_ROOT}/game_controller_db.txt"
	elif [ -f /usr/share/SDL-GameControllerDB/gamecontrollerdb.txt ]; then
		cp -f /usr/share/SDL-GameControllerDB/gamecontrollerdb.txt "${DATA_ROOT}/game_controller_db.txt"
	elif [ -f /usr/armsx2/bin/resources/game_controller_db.txt ]; then
		cp -f /usr/armsx2/bin/resources/game_controller_db.txt "${DATA_ROOT}/game_controller_db.txt"
	else
		: > "${DATA_ROOT}/game_controller_db.txt"
	fi
fi

ODIN2_GUID="03000000202000000130000001000000"
ODIN2_MAPPING="${ODIN2_GUID},AYN Odin2 Gamepad,a:b1,b:b2,x:b4,y:b3,back:b7,guide:b9,start:b8,leftstick:b10,rightstick:b11,leftshoulder:b5,rightshoulder:b6,dpup:b12,dpdown:b13,dpleft:b14,dpright:b15,leftx:a0,lefty:a1,rightx:a3,righty:a4,lefttrigger:a2,righttrigger:a5,platform:Linux,"
if ! grep -qxF "${ODIN2_MAPPING}" "${DATA_ROOT}/game_controller_db.txt"; then
	tmp_db="${DATA_ROOT}/game_controller_db.txt.tmp"
	grep -v "^${ODIN2_GUID}," "${DATA_ROOT}/game_controller_db.txt" > "${tmp_db}" || true
	printf '%s\n' "${ODIN2_MAPPING}" >> "${tmp_db}"
	mv -f "${tmp_db}" "${DATA_ROOT}/game_controller_db.txt"
fi

export XDG_CONFIG_HOME="${CONFIG_HOME}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/userdata/system}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/userdata/system/cache}"
export QT_PLUGIN_PATH="${QT_PLUGIN_PATH:-/usr/lib/qt6/plugins:/usr/lib/qt/plugins}"
export QT_QPA_PLATFORM_PLUGIN_PATH="${QT_QPA_PLATFORM_PLUGIN_PATH:-/usr/lib/qt6/plugins/platforms:/usr/lib/qt/plugins/platforms}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-x11}"
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY=
export DISABLE_MANGOHUD="${DISABLE_MANGOHUD:-1}"
export DISABLE_LSFG="${DISABLE_LSFG:-1}"
export VK_LOADER_LAYERS_DISABLE="${VK_LOADER_LAYERS_DISABLE:-~implicit~}"

cd /usr/armsx2/bin

exec /usr/armsx2/bin/pcsx2-qt \
	-nogui \
	-fullscreen \
	-logfile /userdata/system/logs/armsx2.log \
	-- "${ROM}"
