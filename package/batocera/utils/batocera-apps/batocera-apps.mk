# SPDX-FileCopyrightText: Added/modified by suckbluefrog
################################################################################
#
# batocera-apps
#
################################################################################

BATOCERA_APPS_VERSION = 1.0
BATOCERA_APPS_LICENSE = Various
BATOCERA_APPS_STRIP = NO
BATOCERA_APPS_TOOLCHAIN = manual

BATOCERA_APPS_SITE = https://github.com/shy1132/VacuumTube/releases/download/v1.5.6
BATOCERA_APPS_SOURCE = VacuumTube-x86_64.AppImage
BATOCERA_APPS_CHROME_TAG = 20260225-033748
BATOCERA_APPS_CHROME_SOURCE = Google-Chrome-stable-145.0.7632.116-1-x86_64.AppImage
BATOCERA_APPS_FIREFOX_TAG = 20260224-203738
BATOCERA_APPS_FIREFOX_SOURCE = Firefox-stable-148.0-x86_64.AppImage
BATOCERA_APPS_GEFORCE_INFINITY_SOURCE = GeForceInfinity-linux-1.2.1-x86_64.AppImage
BATOCERA_APPS_PARSEC_SOURCE = parsec-linux.deb
BATOCERA_APPS_PROTONUPQT_SOURCE = ProtonUp-Qt-2.15.0-x86_64.AppImage
BATOCERA_APPS_STEAM_ROM_MANAGER_SOURCE = Steam-ROM-Manager-2.5.33.AppImage
BATOCERA_APPS_STEAMLINK_SOURCE = steamlink-1.3.24.301.tgz
BATOCERA_APPS_EXTRA_DOWNLOADS = \
	https://github.com/ivan-hc/Chrome-appimage/releases/download/$(BATOCERA_APPS_CHROME_TAG)/$(BATOCERA_APPS_CHROME_SOURCE) \
	https://github.com/ivan-hc/Firefox-appimage/releases/download/$(BATOCERA_APPS_FIREFOX_TAG)/$(BATOCERA_APPS_FIREFOX_SOURCE) \
	https://github.com/AstralVixen/GeForce-Infinity/releases/download/1.2.1/$(BATOCERA_APPS_GEFORCE_INFINITY_SOURCE) \
	https://builds.parsec.app/package/$(BATOCERA_APPS_PARSEC_SOURCE) \
	https://github.com/DavidoTek/ProtonUp-Qt/releases/download/v2.15.0/$(BATOCERA_APPS_PROTONUPQT_SOURCE) \
	https://github.com/SteamGridDB/steam-rom-manager/releases/download/v2.5.33/$(BATOCERA_APPS_STEAM_ROM_MANAGER_SOURCE) \
	https://repo.steampowered.com/steamlink/latest/$(BATOCERA_APPS_STEAMLINK_SOURCE) \
	https://github.com/unknownskl/greenlight/releases/download/v2.4.1/Greenlight-2.4.1.AppImage \
	https://github.com/moonlight-stream/moonlight-qt/releases/download/v6.1.0/Moonlight-6.1.0-x86_64.AppImage \
	https://github.com/streetpea/chiaki-ng/releases/download/v1.9.9/chiaki-ng.AppImage_x86_64 \
	https://github.com/peazip/PeaZip/releases/download/10.9.0/peazip_portable-10.9.0.LINUX.Qt6.x86_64.tar.gz

define BATOCERA_APPS_EXTRACT_CMDS
	set -e; \
	validate_appimage() { \
		local f="$$1"; \
		local off magic; \
		[ -f "$$f" ] || return 1; \
		chmod 0755 "$$f" 2>/dev/null || true; \
		off="$$( "$$f" --appimage-offset 2>/dev/null || true )"; \
		[ -n "$$off" ] || return 1; \
		[ "$$off" -gt 0 ] 2>/dev/null || return 1; \
		magic="$$(dd if="$$f" bs=1 skip="$$off" count=4 2>/dev/null || true)"; \
		[ "$$magic" = "hsqs" ]; \
	}; \
	fetch_appimage() { \
		local src="$$1"; \
		local url="$$2"; \
		local dst="$$3"; \
		if [ -f "$$src" ]; then \
			cp "$$src" "$$dst"; \
		else \
			wget -O "$$dst" "$$url"; \
		fi; \
		if ! validate_appimage "$$dst"; then \
			echo "batocera-apps: invalid cached AppImage for $${dst##*/}, re-downloading" >&2; \
			rm -f "$$dst"; \
			wget -O "$$dst" "$$url"; \
			validate_appimage "$$dst" || { echo "batocera-apps: failed to fetch valid AppImage from $$url" >&2; exit 1; }; \
		fi; \
	}; \
	validate_deb() { \
		local f="$$1"; \
		[ -f "$$f" ] || return 1; \
		ar t "$$f" 2>/dev/null | grep -Eq '^data\.tar\.'; \
	}; \
	fetch_deb() { \
		local src="$$1"; \
		local url="$$2"; \
		local dst="$$3"; \
		if [ -f "$$src" ]; then \
			cp "$$src" "$$dst"; \
		else \
			wget -O "$$dst" "$$url"; \
		fi; \
		if ! validate_deb "$$dst"; then \
			echo "batocera-apps: invalid cached deb for $${dst##*/}, re-downloading" >&2; \
			rm -f "$$dst"; \
			wget -O "$$dst" "$$url"; \
			validate_deb "$$dst" || { echo "batocera-apps: failed to fetch valid deb from $$url" >&2; exit 1; }; \
		fi; \
	}; \
	fetch_appimage "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/VacuumTube-x86_64.AppImage" \
		"https://github.com/shy1132/VacuumTube/releases/download/v1.5.6/VacuumTube-x86_64.AppImage" \
		"$(@D)/vacuumtube.AppImage"; \
	fetch_appimage "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/$(BATOCERA_APPS_CHROME_SOURCE)" \
		"https://github.com/ivan-hc/Chrome-appimage/releases/download/$(BATOCERA_APPS_CHROME_TAG)/$(BATOCERA_APPS_CHROME_SOURCE)" \
		"$(@D)/chrome.AppImage"; \
	fetch_appimage "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/$(BATOCERA_APPS_FIREFOX_SOURCE)" \
		"https://github.com/ivan-hc/Firefox-appimage/releases/download/$(BATOCERA_APPS_FIREFOX_TAG)/$(BATOCERA_APPS_FIREFOX_SOURCE)" \
		"$(@D)/firefox.AppImage"; \
	fetch_appimage "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/$(BATOCERA_APPS_GEFORCE_INFINITY_SOURCE)" \
		"https://github.com/AstralVixen/GeForce-Infinity/releases/download/1.2.1/$(BATOCERA_APPS_GEFORCE_INFINITY_SOURCE)" \
		"$(@D)/geforceinfinity.AppImage"; \
	fetch_deb "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/$(BATOCERA_APPS_PARSEC_SOURCE)" \
		"https://builds.parsec.app/package/$(BATOCERA_APPS_PARSEC_SOURCE)" \
		"$(@D)/parsec.deb"; \
	fetch_appimage "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/$(BATOCERA_APPS_PROTONUPQT_SOURCE)" \
		"https://github.com/DavidoTek/ProtonUp-Qt/releases/download/v2.15.0/$(BATOCERA_APPS_PROTONUPQT_SOURCE)" \
		"$(@D)/protonupqt.AppImage"; \
	fetch_appimage "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/$(BATOCERA_APPS_STEAM_ROM_MANAGER_SOURCE)" \
		"https://github.com/SteamGridDB/steam-rom-manager/releases/download/v2.5.33/$(BATOCERA_APPS_STEAM_ROM_MANAGER_SOURCE)" \
		"$(@D)/steamrommanager.AppImage"; \
	if [ -f "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/$(BATOCERA_APPS_STEAMLINK_SOURCE)" ]; then \
		cp "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/$(BATOCERA_APPS_STEAMLINK_SOURCE)" "$(@D)/steamlink.tar.gz"; \
	else \
		wget -O "$(@D)/steamlink.tar.gz" "https://repo.steampowered.com/steamlink/latest/$(BATOCERA_APPS_STEAMLINK_SOURCE)"; \
	fi; \
	tar -tzf "$(@D)/steamlink.tar.gz" >/dev/null 2>&1 || { \
		echo "batocera-apps: invalid steamlink archive, re-downloading" >&2; \
		rm -f "$(@D)/steamlink.tar.gz"; \
		wget -O "$(@D)/steamlink.tar.gz" "https://repo.steampowered.com/steamlink/latest/$(BATOCERA_APPS_STEAMLINK_SOURCE)"; \
		tar -tzf "$(@D)/steamlink.tar.gz" >/dev/null 2>&1 || exit 1; \
	}; \
	fetch_appimage "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/Greenlight-2.4.1.AppImage" \
		"https://github.com/unknownskl/greenlight/releases/download/v2.4.1/Greenlight-2.4.1.AppImage" \
		"$(@D)/greenlight.AppImage"; \
	fetch_appimage "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/Moonlight-6.1.0-x86_64.AppImage" \
		"https://github.com/moonlight-stream/moonlight-qt/releases/download/v6.1.0/Moonlight-6.1.0-x86_64.AppImage" \
		"$(@D)/moonlight.AppImage"; \
	fetch_appimage "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/chiaki-ng.AppImage_x86_64" \
		"https://github.com/streetpea/chiaki-ng/releases/download/v1.9.9/chiaki-ng.AppImage_x86_64" \
		"$(@D)/chiaki.AppImage"; \
	if [ -f "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/peazip_portable-10.9.0.LINUX.Qt6.x86_64.tar.gz" ]; then \
		cp "$(DL_DIR)/$(BATOCERA_APPS_DL_SUBDIR)/peazip_portable-10.9.0.LINUX.Qt6.x86_64.tar.gz" "$(@D)/peazip-qt6.tar.gz"; \
	else \
		wget -O "$(@D)/peazip-qt6.tar.gz" "https://github.com/peazip/PeaZip/releases/download/10.9.0/peazip_portable-10.9.0.LINUX.Qt6.x86_64.tar.gz"; \
	fi; \
	tar -tzf "$(@D)/peazip-qt6.tar.gz" >/dev/null 2>&1 || { \
		echo "batocera-apps: invalid peazip archive, re-downloading" >&2; \
		rm -f "$(@D)/peazip-qt6.tar.gz"; \
		wget -O "$(@D)/peazip-qt6.tar.gz" "https://github.com/peazip/PeaZip/releases/download/10.9.0/peazip_portable-10.9.0.LINUX.Qt6.x86_64.tar.gz"; \
		tar -tzf "$(@D)/peazip-qt6.tar.gz" >/dev/null 2>&1 || exit 1; \
	}
endef

define BATOCERA_APPS_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/batocera/apps
	install -m 0644 $(@D)/vacuumtube.AppImage $(TARGET_DIR)/usr/share/batocera/apps/vacuumtube.AppImage
	install -m 0644 $(@D)/chrome.AppImage $(TARGET_DIR)/usr/share/batocera/apps/chrome.AppImage
	install -m 0644 $(@D)/firefox.AppImage $(TARGET_DIR)/usr/share/batocera/apps/firefox.AppImage
	install -m 0644 $(@D)/geforceinfinity.AppImage $(TARGET_DIR)/usr/share/batocera/apps/geforceinfinity.AppImage
	if ar t $(@D)/parsec.deb | grep -q '^data.tar.xz$$'; then \
		ar p $(@D)/parsec.deb data.tar.xz | tar -xJ -C $(TARGET_DIR); \
	elif ar t $(@D)/parsec.deb | grep -q '^data.tar.gz$$'; then \
		ar p $(@D)/parsec.deb data.tar.gz | tar -xz -C $(TARGET_DIR); \
	elif ar t $(@D)/parsec.deb | grep -q '^data.tar.zst$$'; then \
		ar p $(@D)/parsec.deb data.tar.zst | tar --zstd -x -C $(TARGET_DIR); \
	else \
		echo "batocera-apps: unsupported parsec deb payload format" >&2; \
		exit 1; \
	fi
	rm -f $(TARGET_DIR)/usr/share/applications/parsecd.desktop
	install -m 0644 $(@D)/protonupqt.AppImage $(TARGET_DIR)/usr/share/batocera/apps/protonupqt.AppImage
	install -m 0644 $(@D)/steamrommanager.AppImage $(TARGET_DIR)/usr/share/batocera/apps/steamrommanager.AppImage
	mkdir -p $(TARGET_DIR)/usr/share/batocera/apps/steamlink
	tar -xzf $(@D)/steamlink.tar.gz -C $(TARGET_DIR)/usr/share/batocera/apps/steamlink
	install -m 0644 $(@D)/greenlight.AppImage $(TARGET_DIR)/usr/share/batocera/apps/greenlight.AppImage
	install -m 0644 $(@D)/moonlight.AppImage $(TARGET_DIR)/usr/share/batocera/apps/moonlight.AppImage
	install -m 0644 $(@D)/chiaki.AppImage $(TARGET_DIR)/usr/share/batocera/apps/chiaki.AppImage
	mkdir -p $(TARGET_DIR)/usr/share/batocera/apps/peazip
	if [ ! -f "$(@D)/peazip-qt6.tar.gz" ]; then \
		wget -O "$(@D)/peazip-qt6.tar.gz" "https://github.com/peazip/PeaZip/releases/download/10.9.0/peazip_portable-10.9.0.LINUX.Qt6.x86_64.tar.gz"; \
	fi
	tar -xzf $(@D)/peazip-qt6.tar.gz -C $(TARGET_DIR)/usr/share/batocera/apps/peazip

	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-apps/batocera-appimage-launcher \
		$(TARGET_DIR)/usr/libexec/batocera-appimage-launcher
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-apps/batocera-app-parsec \
		$(TARGET_DIR)/usr/bin/batocera-app-parsec
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-apps/batocera-app-geforcenow \
		$(TARGET_DIR)/usr/bin/batocera-app-geforcenow

	mkdir -p $(TARGET_DIR)/usr/bin
	printf '%s\n' '#!/bin/sh' 'exec /usr/libexec/batocera-appimage-launcher /usr/share/batocera/apps/vacuumtube.AppImage vacuumtube 1 "$$@"' > $(TARGET_DIR)/usr/bin/batocera-app-vacuumtube
	printf '%s\n' '#!/bin/sh' 'exec /usr/libexec/batocera-appimage-launcher /usr/share/batocera/apps/chrome.AppImage chrome 1 "$$@"' > $(TARGET_DIR)/usr/bin/batocera-app-chrome
	printf '%s\n' '#!/bin/sh' 'exec /usr/libexec/batocera-appimage-launcher /usr/share/batocera/apps/firefox.AppImage firefox 0 "$$@"' > $(TARGET_DIR)/usr/bin/batocera-app-firefox
	printf '%s\n' '#!/bin/sh' 'set -e' 'batocera-mouse show' "trap 'batocera-mouse hide' EXIT" 'exec /usr/libexec/batocera-appimage-launcher /usr/share/batocera/apps/protonupqt.AppImage protonupqt 1 "$$@"' > $(TARGET_DIR)/usr/bin/batocera-app-protonupqt
	printf '%s\n' '#!/bin/sh' 'set -e' 'batocera-mouse show' "trap 'batocera-mouse hide' EXIT" 'exec /usr/libexec/batocera-appimage-launcher /usr/share/batocera/apps/steamrommanager.AppImage steamrommanager 1 "$$@"' > $(TARGET_DIR)/usr/bin/batocera-app-steamrommanager
	printf '%s\n' '#!/bin/sh' \
		'export HOME="$${HOME:-/userdata/saves/apps/steamlink}"' \
		'export XDG_CONFIG_HOME="$${XDG_CONFIG_HOME:-$${HOME}/.config}"' \
		'export XDG_DATA_HOME="$${XDG_DATA_HOME:-$${HOME}/.local/share}"' \
		'export XDG_CACHE_HOME="$${XDG_CACHE_HOME:-$${HOME}/.cache}"' \
		'mkdir -p "$${XDG_CONFIG_HOME}" "$${XDG_DATA_HOME}" "$${XDG_CACHE_HOME}"' \
		'bin="/usr/share/batocera/apps/steamlink/package/bin/steamlink"' \
		'export LD_LIBRARY_PATH="/usr/share/batocera/apps/steamlink/package/lib:$${LD_LIBRARY_PATH:-}"' \
		'if [ "$$(uname -m)" != "x86_64" ] && command -v box64 >/dev/null 2>&1; then exec box64 "$${bin}" "$$@"; fi' \
		'exec "$${bin}" "$$@"' \
		> $(TARGET_DIR)/usr/bin/batocera-app-steamlink
	printf '%s\n' '#!/bin/sh' 'exec /usr/libexec/batocera-appimage-launcher /usr/share/batocera/apps/greenlight.AppImage greenlight 1 "$$@"' > $(TARGET_DIR)/usr/bin/batocera-app-greenlight
	printf '%s\n' '#!/bin/sh' 'exec /usr/libexec/batocera-appimage-launcher /usr/share/batocera/apps/moonlight.AppImage moonlight 0 "$$@"' > $(TARGET_DIR)/usr/bin/batocera-app-moonlight
	printf '%s\n' '#!/bin/sh' 'exec /usr/libexec/batocera-appimage-launcher /usr/share/batocera/apps/chiaki.AppImage chiaki 0 "$$@"' > $(TARGET_DIR)/usr/bin/batocera-app-chiaki
	printf '%s\n' '#!/bin/sh' \
		'export HOME="$${HOME:-/userdata/saves/apps/peazip}"' \
		'export XDG_CONFIG_HOME="$${XDG_CONFIG_HOME:-$${HOME}/.config}"' \
		'export XDG_DATA_HOME="$${XDG_DATA_HOME:-$${HOME}/.local/share}"' \
		'export XDG_CACHE_HOME="$${XDG_CACHE_HOME:-$${HOME}/.cache}"' \
		'mkdir -p "$${XDG_CONFIG_HOME}" "$${XDG_DATA_HOME}" "$${XDG_CACHE_HOME}"' \
		'bin="$$(find /usr/share/batocera/apps/peazip -type f -name peazip | head -n 1)"' \
		'[ -n "$${bin}" ] || exit 127' \
		'bindir="$$(dirname "$${bin}")"' \
		'export LD_LIBRARY_PATH="$${bindir}:$${LD_LIBRARY_PATH:-}"' \
		'if [ -d "$${bindir}/plugins" ]; then export QT_PLUGIN_PATH="$${QT_PLUGIN_PATH:-$${bindir}/plugins}"; fi' \
		'exec "$${bin}" "$$@"' \
		> $(TARGET_DIR)/usr/bin/batocera-app-peazip
	chmod 0755 \
		$(TARGET_DIR)/usr/bin/batocera-app-vacuumtube \
		$(TARGET_DIR)/usr/bin/batocera-app-chrome \
		$(TARGET_DIR)/usr/bin/batocera-app-firefox \
		$(TARGET_DIR)/usr/bin/batocera-app-parsec \
		$(TARGET_DIR)/usr/bin/batocera-app-geforcenow \
		$(TARGET_DIR)/usr/bin/batocera-app-protonupqt \
		$(TARGET_DIR)/usr/bin/batocera-app-steamrommanager \
		$(TARGET_DIR)/usr/bin/batocera-app-steamlink \
		$(TARGET_DIR)/usr/bin/batocera-app-greenlight \
		$(TARGET_DIR)/usr/bin/batocera-app-moonlight \
		$(TARGET_DIR)/usr/bin/batocera-app-chiaki \
		$(TARGET_DIR)/usr/bin/batocera-app-peazip

	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps
	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images
	printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'batocera-mouse show' "trap 'batocera-mouse hide' EXIT" 'exec batocera-app-vacuumtube' > $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/VacuumTube.sh
	printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'batocera-mouse show' "trap 'batocera-mouse hide' EXIT" 'exec batocera-app-chrome' > $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Chrome.sh
	printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'batocera-mouse show' "trap 'batocera-mouse hide' EXIT" 'exec batocera-app-firefox' > $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Firefox.sh
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-apps/SteamLink.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/SteamLink.sh
	printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'batocera-mouse show' "trap 'batocera-mouse hide' EXIT" 'exec batocera-app-parsec' > $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Parsec.sh
	printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'batocera-mouse show' "trap 'batocera-mouse hide' EXIT" 'exec batocera-app-geforcenow' > $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/GeForceNOW.sh
	printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'batocera-mouse show' "trap 'batocera-mouse hide' EXIT" 'exec batocera-app-greenlight' > $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Greenlight.sh
	printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'batocera-mouse show' "trap 'batocera-mouse hide' EXIT" 'exec batocera-app-moonlight' > $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Moonlight.sh
	printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'batocera-mouse show' "trap 'batocera-mouse hide' EXIT" 'exec batocera-app-chiaki' > $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Chiaki.sh
	printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'batocera-mouse show' "trap 'batocera-mouse hide' EXIT" 'exec batocera-app-peazip' > $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/PeaZip.sh
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-apps/vacuumtube.keys \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/VacuumTube.sh.keys
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-apps/gamelist.xml \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/gamelist.xml
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/vacuumtube.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/vacuumtube.png
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/chrome.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/chrome.png
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/firefox.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/firefox.png
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/steam.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/steamlink.png
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/parsec.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/parsec.png
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/geforcenow.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/geforcenow.png
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/greenlight.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/greenlight.png
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/moonlight.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/moonlight.png
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/chiaki.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/chiaki.png
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/peazip.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/peazip.png
	chmod 0755 $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/*.sh
endef

$(eval $(generic-package))
