################################################################################
#
# heroic (AppImage)
#
################################################################################

HEROIC_VERSION = 2.20.0
HEROIC_LICENSE = GPL-3.0
HEROIC_STRIP = NO
HEROIC_TOOLCHAIN = manual
HEROIC_DEPENDENCIES = openal

HEROIC_SITE = https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/download/v$(HEROIC_VERSION)
HEROIC_SOURCE = Heroic-$(HEROIC_VERSION)-linux-x86_64.AppImage

define HEROIC_EXTRACT_CMDS
	cp $(DL_DIR)/$(HEROIC_DL_SUBDIR)/$(HEROIC_SOURCE) \
		$(@D)/heroic.AppImage
endef

define HEROIC_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/heroic
	install -m 0644 $(@D)/heroic.AppImage \
		$(TARGET_DIR)/usr/share/heroic/heroic.AppImage
	mkdir -p $(TARGET_DIR)/usr/share/heroic/defaults/store
	install -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/heroic/config.json \
		$(TARGET_DIR)/usr/share/heroic/defaults/config.json
	install -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/heroic/store.config.json \
		$(TARGET_DIR)/usr/share/heroic/defaults/store/config.json

	mkdir -p $(TARGET_DIR)/usr/bin
	printf '%s\n' \
		'#!/bin/sh' \
		'src="$${BATOCERA_HEROIC_SYSTEM_APPIMAGE:-/usr/share/heroic/heroic.AppImage}"' \
		'home="$${BATOCERA_HEROIC_HOME:-/userdata/saves/heroic}"' \
		'local_app="$${BATOCERA_HEROIC_LOCAL_APPIMAGE:-$${home}/heroic.AppImage}"' \
		'py_overrides="$${BATOCERA_HEROIC_PYTHON_OVERRIDES:-/usr/share/heroic/python-overrides}"' \
		'app="$${src}"' \
		'export APPIMAGE_EXTRACT_AND_RUN="$${APPIMAGE_EXTRACT_AND_RUN:-1}"' \
		'export APPIMAGE_ALLOW_ROOT="$${APPIMAGE_ALLOW_ROOT:-1}"' \
		'export BATOCERA_HEROIC_PATCH_LEGENDARY_PERMS="$${BATOCERA_HEROIC_PATCH_LEGENDARY_PERMS:-1}"' \
		'export USE_FAKE_EPIC_EXE="$${BATOCERA_HEROIC_USE_FAKE_EPIC_EXE:-0}"' \
		'export HOME="$${home}"' \
		'export XDG_CONFIG_HOME="$${HOME}/.config"' \
		'export XDG_DATA_HOME="$${HOME}/.local/share"' \
		'export XDG_CACHE_HOME="$${HOME}/.cache"' \
		'export XDG_RUNTIME_DIR="$${XDG_RUNTIME_DIR:-/run/user/$$(id -u)}"' \
		'mkdir -p "$${XDG_CONFIG_HOME}" "$${XDG_DATA_HOME}" "$${XDG_CACHE_HOME}" "$${XDG_RUNTIME_DIR}"' \
		'mkdir -p "$${XDG_DATA_HOME}/applications" "$${HOME}/Desktop"' \
		'legacy_home="/userdata/save/heroic"' \
		'if [ "$${home}" = "/userdata/saves/heroic" ] && [ ! -e "$${legacy_home}" ]; then' \
		'  mkdir -p "/userdata/save"' \
		'  ln -s "$${home}" "$${legacy_home}" 2>/dev/null || true' \
		'fi' \
		'steam_userdata_link="$${HOME}/.steam/steam/userdata"' \
		'steam_userdata_src=""' \
		'for candidate in /userdata/system/steam/userdata /userdata/system/.steam/steam/userdata /userdata/system/.local/share/Steam/userdata; do' \
		'  if [ -d "$${candidate}" ]; then steam_userdata_src="$${candidate}"; break; fi' \
		'done' \
		'mkdir -p "$$(dirname "$${steam_userdata_link}")"' \
		'if [ -n "$${steam_userdata_src}" ]; then' \
		'  if [ -L "$${steam_userdata_link}" ]; then' \
		'    current_link="$$(readlink "$${steam_userdata_link}" 2>/dev/null || true)"' \
		'    [ "$${current_link}" = "$${steam_userdata_src}" ] || ln -snf "$${steam_userdata_src}" "$${steam_userdata_link}" 2>/dev/null || true' \
		'  elif [ ! -e "$${steam_userdata_link}" ]; then' \
		'    ln -s "$${steam_userdata_src}" "$${steam_userdata_link}" 2>/dev/null || true' \
		'  fi' \
		'else' \
		'  mkdir -p "$${steam_userdata_link}"' \
		'fi' \
		'defaults_dir="$${BATOCERA_HEROIC_DEFAULTS_DIR:-/usr/share/heroic/defaults}"' \
		'cfg_json="$${XDG_CONFIG_HOME}/heroic/config.json"' \
		'store_cfg="$${XDG_CONFIG_HOME}/heroic/store/config.json"' \
		'if [ ! -f "$${cfg_json}" ] && [ -f "$${defaults_dir}/config.json" ]; then mkdir -p "$$(dirname "$${cfg_json}")"; cp -f "$${defaults_dir}/config.json" "$${cfg_json}" 2>/dev/null || true; fi' \
		'if [ ! -f "$${store_cfg}" ] && [ -f "$${defaults_dir}/store/config.json" ]; then mkdir -p "$$(dirname "$${store_cfg}")"; cp -f "$${defaults_dir}/store/config.json" "$${store_cfg}" 2>/dev/null || true; fi' \
		'if [ -f "$${cfg_json}" ]; then' \
		'  sed -i -e '\''s/"checkForUpdatesOnStartup"[[:space:]]*:[[:space:]]*true/"checkForUpdatesOnStartup": false/g'\'' -e '\''s/"enableUpdates"[[:space:]]*:[[:space:]]*true/"enableUpdates": false/g'\'' -e '\''s/"autoUpdateGames"[[:space:]]*:[[:space:]]*true/"autoUpdateGames": false/g'\'' -e '\''s/"disableUMU"[[:space:]]*:[[:space:]]*false/"disableUMU": true/g'\'' "$${cfg_json}" 2>/dev/null || true' \
		'fi' \
		'if [ -f "$${store_cfg}" ]; then' \
		'  sed -i -e '\''s/"disableUMU"[[:space:]]*:[[:space:]]*false/"disableUMU": true/g'\'' "$${store_cfg}" 2>/dev/null || true' \
		'fi' \
		'if [ -d "$${py_overrides}" ]; then export PYTHONPATH="$${py_overrides}$${PYTHONPATH:+:$${PYTHONPATH}}"; fi' \
		'if [ ! -x "$${app}" ] && [ -f "$${src}" ]; then cp -f "$${src}" "$${local_app}" && chmod 0755 "$${local_app}" 2>/dev/null || true; app="$${local_app}"; fi' \
		'need_no_sandbox=0' \
		'if [ "$${BATOCERA_HEROIC_NO_SANDBOX:-0}" = "1" ] || [ "$${BATOCERA_HEROIC_NO_SANDBOX:-false}" = "true" ]; then need_no_sandbox=1; elif [ "$$(id -u)" = "0" ]; then need_no_sandbox=1; fi' \
		'run_uid="$${BATOCERA_HEROIC_UID:-1000}"' \
		'run_gid="$${BATOCERA_HEROIC_GID:-1000}"' \
		'if [ "$$(id -u)" = "0" ] && [ "$${run_uid}" != "0" ] && [ "$${BATOCERA_HEROIC_FAKE_USER:-0}" = "1" ] && command -v setpriv >/dev/null 2>&1; then' \
		'  [ -d "$${home}" ] || mkdir -p "$${home}"' \
		'  if [ "$${BATOCERA_HEROIC_CHOWN_HOME:-1}" = "1" ]; then owner="$$(stat -c %u:%g "$${home}" 2>/dev/null || echo "")"; [ "$${owner}" = "$${run_uid}:$${run_gid}" ] || chown -R "$${run_uid}:$${run_gid}" "$${home}" 2>/dev/null || true; fi' \
		'  if [ "$${need_no_sandbox}" = "1" ]; then setpriv --reuid "$${run_uid}" --regid "$${run_gid}" --clear-groups "$${app}" --no-sandbox "$$@" && exit $$?; else setpriv --reuid "$${run_uid}" --regid "$${run_gid}" --clear-groups "$${app}" "$$@" && exit $$?; fi' \
		'fi' \
		'if [ "$${need_no_sandbox}" = "1" ]; then exec "$${app}" --no-sandbox "$$@"; fi' \
		'exec "$${app}" "$$@"' \
		> $(TARGET_DIR)/usr/bin/heroic
	chmod 0755 $(TARGET_DIR)/usr/bin/heroic

	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/heroic/sitecustomize.py \
		$(TARGET_DIR)/usr/share/heroic/python-overrides/sitecustomize.py

	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/roms/heroic
	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/roms/heroic/images
	printf '%s\n' \
		'#!/bin/bash' \
		'set -euo pipefail' \
		'batocera-mouse show' \
		"trap 'batocera-mouse hide' EXIT" \
		'extra_args=()' \
		'if [[ -n "$${BATOCERA_HEROIC_EXTRA_ARGS:-}" ]]; then read -r -a extra_args <<< "$${BATOCERA_HEROIC_EXTRA_ARGS}"; fi' \
		'export HOME="/userdata/saves/heroic"' \
		'export XDG_CONFIG_HOME="$${HOME}/.config"' \
		'export XDG_DATA_HOME="$${HOME}/.local/share"' \
		'export XDG_CACHE_HOME="$${HOME}/.cache"' \
		'mkdir -p "$${XDG_CONFIG_HOME}" "$${XDG_DATA_HOME}" "$${XDG_CACHE_HOME}"' \
		'exec heroic "$${extra_args[@]}"' \
		> "$(TARGET_DIR)/usr/share/batocera/datainit/roms/heroic/Heroic Launcher.sh"
	chmod 0755 "$(TARGET_DIR)/usr/share/batocera/datainit/roms/heroic/Heroic Launcher.sh"
	printf '%s\n' \
		'<?xml version="1.0"?>' \
		'<gameList>' \
		'  <game>' \
		'    <path>./Heroic Launcher.sh</path>' \
		'    <name>Heroic Game Launcher</name>' \
		'    <image>./images/heroic.png</image>' \
		'  </game>' \
		'</gameList>' \
		> "$(TARGET_DIR)/usr/share/batocera/datainit/roms/heroic/gamelist.xml"
	ln -snf /usr/share/icons/batocera/heroic.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/heroic/images/heroic.png
	for d in lib usr/lib usr/lib64; do \
		if [ -e "$(TARGET_DIR)/$$d/libopenal.so.1" ] && [ ! -e "$(TARGET_DIR)/$$d/libal.so.1" ]; then \
			ln -sf libopenal.so.1 "$(TARGET_DIR)/$$d/libal.so.1"; \
		fi; \
	done
endef

$(eval $(generic-package))
