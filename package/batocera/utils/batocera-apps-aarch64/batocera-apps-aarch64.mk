################################################################################
#
# batocera-apps-aarch64
#
################################################################################

BATOCERA_APPS_AARCH64_VERSION = 1.0
BATOCERA_APPS_AARCH64_LICENSE = Various
BATOCERA_APPS_AARCH64_STRIP = NO
BATOCERA_APPS_AARCH64_TOOLCHAIN = manual
BATOCERA_APPS_AARCH64_SOURCE =

BATOCERA_APPS_AARCH64_VACUUMTUBE_SOURCE = VacuumTube-x86_64.AppImage
BATOCERA_APPS_AARCH64_BRAVE_SOURCE = Brave-Web-Browser-stable-1.89.143-aarch64.AppImage
BATOCERA_APPS_AARCH64_FIREFOX_SOURCE = firefox-149.0.tar.xz

BATOCERA_APPS_AARCH64_EXTRA_DOWNLOADS = \
	https://github.com/shy1132/VacuumTube/releases/download/v1.5.6/$(BATOCERA_APPS_AARCH64_VACUUMTUBE_SOURCE) \
	https://github.com/ivan-hc/Brave-appimage/releases/download/continuous-stable/$(BATOCERA_APPS_AARCH64_BRAVE_SOURCE) \
	https://download-installer.cdn.mozilla.net/pub/firefox/releases/149.0/linux-aarch64/en-US/$(BATOCERA_APPS_AARCH64_FIREFOX_SOURCE)

BATOCERA_APPS_AARCH64_PKGDIR = \
	$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-apps-aarch64

define BATOCERA_APPS_AARCH64_EXTRACT_CMDS
	cp $(DL_DIR)/$(BATOCERA_APPS_AARCH64_DL_SUBDIR)/$(BATOCERA_APPS_AARCH64_VACUUMTUBE_SOURCE) \
		$(@D)/vacuumtube.AppImage
	cp $(DL_DIR)/$(BATOCERA_APPS_AARCH64_DL_SUBDIR)/$(BATOCERA_APPS_AARCH64_BRAVE_SOURCE) \
		$(@D)/brave.AppImage
	tar -xJf $(DL_DIR)/$(BATOCERA_APPS_AARCH64_DL_SUBDIR)/$(BATOCERA_APPS_AARCH64_FIREFOX_SOURCE) \
		-C $(@D)
endef

define BATOCERA_APPS_AARCH64_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/batocera/apps
	install -m 0644 $(@D)/vacuumtube.AppImage $(TARGET_DIR)/usr/share/batocera/apps/vacuumtube.AppImage
	install -m 0644 $(@D)/brave.AppImage $(TARGET_DIR)/usr/share/batocera/apps/brave.AppImage
	cp -a $(@D)/firefox $(TARGET_DIR)/usr/share/batocera/apps/
	rm -f \
		$(TARGET_DIR)/usr/share/batocera/apps/opennow.AppImage \
		$(TARGET_DIR)/usr/bin/batocera-app-geforcenow \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/OpenNOW.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/geforcenow.png \
		$(TARGET_DIR)/usr/share/batocera/apps/steamlink.AppImage \
		$(TARGET_DIR)/usr/bin/batocera-app-steamlink \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/SteamLink.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/steamlink.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/VacuumTube.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/VacuumTube.sh.keys \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/vacuumtube.png

	install -D -m 0755 \
		$(BATOCERA_APPS_AARCH64_PKGDIR)/batocera-appimage-launcher \
		$(TARGET_DIR)/usr/libexec/batocera-appimage-launcher
	printf '%s\n' '#!/bin/sh' 'exec /usr/libexec/batocera-appimage-launcher /usr/share/batocera/apps/vacuumtube.AppImage vacuumtube 1 "$$@"' > $(TARGET_DIR)/usr/bin/batocera-app-vacuumtube
	install -D -m 0755 \
		$(BATOCERA_APPS_AARCH64_PKGDIR)/batocera-app-brave \
		$(TARGET_DIR)/usr/bin/batocera-app-brave
	install -D -m 0755 \
		$(BATOCERA_APPS_AARCH64_PKGDIR)/batocera-app-firefox \
		$(TARGET_DIR)/usr/bin/batocera-app-firefox

	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images
	install -D -m 0644 $(BATOCERA_APPS_AARCH64_PKGDIR)/gamelist.xml \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/gamelist.xml
	install -D -m 0755 $(BATOCERA_APPS_AARCH64_PKGDIR)/roms/Brave.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Brave.sh
	install -D -m 0755 $(BATOCERA_APPS_AARCH64_PKGDIR)/roms/Firefox.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Firefox.sh
	install -D -m 0644 $(BATOCERA_APPS_AARCH64_PKGDIR)/images/brave.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/brave.png
	install -D -m 0644 $(BATOCERA_APPS_AARCH64_PKGDIR)/images/firefox.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/firefox.png
	chmod 0755 $(TARGET_DIR)/usr/bin/batocera-app-vacuumtube
endef

$(eval $(generic-package))
