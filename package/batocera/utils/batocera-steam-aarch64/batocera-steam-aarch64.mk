################################################################################
#
# batocera-steam-aarch64
#
################################################################################

BATOCERA_STEAM_AARCH64_VERSION = 1.2
BATOCERA_STEAM_AARCH64_SITE = $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam-aarch64
BATOCERA_STEAM_AARCH64_SITE_METHOD = local

define BATOCERA_STEAM_AARCH64_INSTALL_TARGET_CMDS
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam-aarch64/batocera-steam \
		$(TARGET_DIR)/usr/bin/batocera-steam
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam-aarch64/taskset \
		$(TARGET_DIR)/usr/bin/taskset
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam-aarch64/compatibilitytool.vdf \
		$(TARGET_DIR)/usr/share/steam/compatibilitytool.vdf
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam-aarch64/toolmanifest.vdf \
		$(TARGET_DIR)/usr/share/steam/toolmanifest.vdf
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam-aarch64/registry.vdf \
		$(TARGET_DIR)/usr/share/steam/registry.vdf
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam-aarch64/steamwebhelper.json \
		$(TARGET_DIR)/usr/share/fex-emu/AppConfig/steamwebhelper.json
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam-aarch64/batocera-steam-update \
		$(TARGET_DIR)/usr/bin/batocera-steam-update
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-decky-install \
		$(TARGET_DIR)/usr/bin/batocera-steam-decky-install
	ln -sf batocera-steam-decky-install \
		$(TARGET_DIR)/usr/bin/batocera-decky-install
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-users \
		$(TARGET_DIR)/usr/bin/batocera-steam-users
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-session \
		$(TARGET_DIR)/usr/bin/batocera-steam-session
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-gamescope-child \
		$(TARGET_DIR)/usr/bin/batocera-steam-gamescope-child
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-update-terminal \
		$(TARGET_DIR)/usr/bin/batocera-steam-update-terminal
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-update-preflight \
		$(TARGET_DIR)/usr/bin/batocera-steam-update-preflight
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/steam-direct-session.sh \
		$(TARGET_DIR)/usr/bin/steam-direct-session.sh
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-qam \
		$(TARGET_DIR)/usr/bin/batocera-steam-qam
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-back-qam \
		$(TARGET_DIR)/usr/bin/batocera-steam-back-qam
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/steamos-session-select \
		$(TARGET_DIR)/usr/bin/steamos-session-select
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-desktop-switch \
		$(TARGET_DIR)/usr/bin/batocera-steam-desktop-switch
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-desktop-launcher \
		$(TARGET_DIR)/usr/bin/batocera-steam-desktop-launcher
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-uimode-watch \
		$(TARGET_DIR)/usr/bin/batocera-steam-uimode-watch
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-frontend-recover \
		$(TARGET_DIR)/usr/bin/batocera-steam-frontend-recover
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-session-supervisor \
		$(TARGET_DIR)/usr/bin/batocera-steam-session-supervisor
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-nightmode-watch \
		$(TARGET_DIR)/usr/bin/batocera-steam-nightmode-watch
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-displaymanager-stub \
		$(TARGET_DIR)/usr/bin/batocera-displaymanager-stub
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-networkmanager-stub \
		$(TARGET_DIR)/usr/bin/batocera-networkmanager-stub
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-login1-stub \
		$(TARGET_DIR)/usr/bin/batocera-login1-stub
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-consolekit-stub \
		$(TARGET_DIR)/usr/bin/batocera-consolekit-stub
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-shortcuts \
		$(TARGET_DIR)/usr/bin/batocera-steam-shortcuts
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-sync \
		$(TARGET_DIR)/usr/bin/batocera-steam-sync
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-rom-launch \
		$(TARGET_DIR)/usr/bin/batocera-steam-rom-launch
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-emu-launch \
		$(TARGET_DIR)/usr/bin/batocera-steam-emu-launch
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-wine/batocera-wine-tools \
		$(TARGET_DIR)/usr/bin/batocera-steam-tools
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-tools-launcher \
		$(TARGET_DIR)/usr/bin/batocera-steam-tools-launcher
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/protontricks \
		$(TARGET_DIR)/usr/bin/protontricks
	install -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/xdg-user-dir \
		$(TARGET_DIR)/usr/bin/xdg-user-dir

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

	mkdir -p $(TARGET_DIR)/usr/share/batocera/steam/looks
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/night-mode-warm.cube \
		$(TARGET_DIR)/usr/share/batocera/steam/looks/night-mode-warm.cube

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
	printf '%s\n' 'mode=steamos' 'gamepadui=1' 'gamescope=1' 'visible_update_preflight=1' 'update_preflight_no_update_secs=15' > "$(TARGET_DIR)/usr/share/batocera/datainit/roms/steam/Steam GamepadUI Gamescope.steam"
	printf '%s\n' 'mode=gamepadui' 'gamepadui=1' 'gamescope=0' > "$(TARGET_DIR)/usr/share/batocera/datainit/roms/steam/Steam GamepadUI.steam"
	printf '%s\n' 'mode=desktop' 'gamepadui=0' 'gamescope=0' > "$(TARGET_DIR)/usr/share/batocera/datainit/roms/steam/Steam Desktop.steam"
	printf '%s\n' '<?xml version="1.0"?>' '<gameList>' '  <game>' '    <path>./Steam GamepadUI Gamescope.steam</path>' '    <name>Steam (GamepadUI Gamescope)</name>' '    <image>./images/Steam.png</image>' '  </game>' '  <game>' '    <path>./Steam GamepadUI.steam</path>' '    <name>Steam (GamepadUI)</name>' '    <image>./images/Steam.png</image>' '  </game>' '  <game>' '    <path>./Steam Desktop.steam</path>' '    <name>Steam (Desktop)</name>' '    <image>./images/Steam.png</image>' '  </game>' '</gameList>' > "$(TARGET_DIR)/usr/share/batocera/datainit/roms/steam/gamelist.xml"
endef

$(eval $(generic-package))
