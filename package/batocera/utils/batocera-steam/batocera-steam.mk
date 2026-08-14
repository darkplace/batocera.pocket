# SPDX-FileCopyrightText: Added/modified by suckbluefrog
################################################################################
#
# batocera-steam
#
################################################################################

BATOCERA_STEAM_VERSION = latest
BATOCERA_STEAM_SOURCE = steam.deb
BATOCERA_STEAM_SITE = https://cdn.cloudflare.steamstatic.com/client/installer

define BATOCERA_STEAM_EXTRACT_CMDS
	mkdir -p $(@D)/steam-bootstrap
	cd $(@D)/steam-bootstrap && \
		ar p $(DL_DIR)/$(BATOCERA_STEAM_DL_SUBDIR)/$(BATOCERA_STEAM_SOURCE) data.tar.xz | \
		tar -xJ ./usr/lib/steam/bootstraplinux_ubuntu12_32.tar.xz ./usr/lib/steam/bin_steam.sh
endef

define BATOCERA_STEAM_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/bin
	mkdir -p $(TARGET_DIR)/usr/share/steam/bootstrap

	tar -xJf $(@D)/steam-bootstrap/usr/lib/steam/bootstraplinux_ubuntu12_32.tar.xz \
	    -C $(TARGET_DIR)/usr/share/steam/bootstrap
	install -m 0644 $(@D)/steam-bootstrap/usr/lib/steam/bin_steam.sh \
	    $(TARGET_DIR)/usr/share/steam/bin_steam.sh
	if grep -q "# Don't allow running as root" "$(TARGET_DIR)/usr/share/steam/bin_steam.sh"; then \
		awk 'BEGIN{skip=0} /# Don'\''t allow running as root/{skip=5} {if(skip>0){skip--;next} print}' \
		    "$(TARGET_DIR)/usr/share/steam/bin_steam.sh" > "$(TARGET_DIR)/usr/share/steam/bin_steam.sh.tmp"; \
		mv "$(TARGET_DIR)/usr/share/steam/bin_steam.sh.tmp" "$(TARGET_DIR)/usr/share/steam/bin_steam.sh"; \
	fi
	chmod 0755 "$(TARGET_DIR)/usr/share/steam/bin_steam.sh"
	ln -sf ../share/steam/bin_steam.sh $(TARGET_DIR)/usr/bin/bin_steam.sh
	ln -sf ../share/steam/bin_steam.sh $(TARGET_DIR)/usr/bin/bin_steam

	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-session \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-gamescope-child \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-update-terminal \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-update-preflight \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-displaymanager-stub \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-networkmanager-stub \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-login1-stub \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-consolekit-stub \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-desktop-switch \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-desktop-launcher \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-uimode-watch \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-frontend-recover \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-session-supervisor \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/steamos-session-select \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-decky-install \
	    $(TARGET_DIR)/usr/bin/
	ln -sf batocera-steam-decky-install \
	    $(TARGET_DIR)/usr/bin/batocera-decky-install
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-update \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-shortcuts \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-sync \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-rom-launch \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-emu-launch \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-gamescope-test \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-wine/batocera-wine-tools \
	    $(TARGET_DIR)/usr/bin/batocera-steam-tools
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-tools-launcher \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/protontricks \
	    $(TARGET_DIR)/usr/bin/
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/xdg-user-dir \
	    $(TARGET_DIR)/usr/bin/

	mkdir -p $(TARGET_DIR)/etc/dbus-1/system.d
	install -m 0644 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/org.freedesktop.DisplayManager.conf \
	    $(TARGET_DIR)/etc/dbus-1/system.d/
	install -m 0644 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/org.freedesktop.NetworkManager.conf \
	    $(TARGET_DIR)/etc/dbus-1/system.d/
	install -m 0644 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/org.freedesktop.login1.conf \
	    $(TARGET_DIR)/etc/dbus-1/system.d/
	install -m 0644 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/org.freedesktop.ConsoleKit.conf \
	    $(TARGET_DIR)/etc/dbus-1/system.d/

	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/hooks
	ln -sf /usr/bin/batocera-steam-update \
	    $(TARGET_DIR)/usr/share/emulationstation/hooks/preupdate-gamelists-steam

	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/roms/steam
	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/roms/steam/images
	rm -f \
	    "$(TARGET_DIR)/usr/share/batocera/datainit/roms/steam/Steam GamepadUI No Gamescope.steam" \
	    "$(TARGET_DIR)/usr/share/batocera/datainit/roms/steam/_info.txt" \
	    $(TARGET_DIR)/usr/share/batocera/datainit/roms/steam/images/protonupqt.png \
	    $(TARGET_DIR)/usr/share/batocera/datainit/roms/steam/images/steam-rom-manager.png
	install -m 0644 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/steam.png \
	    $(TARGET_DIR)/usr/share/batocera/datainit/roms/steam/images/Steam.png
	printf '%s\n' 'mode=steamos' 'gamepadui=1' > "$(TARGET_DIR)/usr/share/batocera/datainit/roms/steam/Steam GamepadUI.steam"
	printf '%s\n' 'mode=desktop' 'gamepadui=0' > "$(TARGET_DIR)/usr/share/batocera/datainit/roms/steam/Steam Desktop.steam"
	printf '%s\n' '<?xml version="1.0"?>' '<gameList>' '  <game>' '    <path>./Steam GamepadUI.steam</path>' '    <name>Steam (GamepadUI)</name>' '    <image>./images/Steam.png</image>' '  </game>' '  <game>' '    <path>./Steam Desktop.steam</path>' '    <name>Steam (Desktop)</name>' '    <image>./images/Steam.png</image>' '  </game>' '</gameList>' > "$(TARGET_DIR)/usr/share/batocera/datainit/roms/steam/gamelist.xml"
endef

$(eval $(generic-package))
