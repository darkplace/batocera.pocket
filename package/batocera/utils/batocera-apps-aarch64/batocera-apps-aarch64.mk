################################################################################
#
# batocera-apps-aarch64
#
################################################################################

BATOCERA_APPS_AARCH64_VERSION = 1.1
BATOCERA_APPS_AARCH64_LICENSE = Various
BATOCERA_APPS_AARCH64_STRIP = NO
BATOCERA_APPS_AARCH64_TOOLCHAIN = manual

BATOCERA_APPS_AARCH64_SITE = https://github.com/shy1132/VacuumTube/releases/download/v1.8.1
BATOCERA_APPS_AARCH64_SOURCE = VacuumTube-arm64.AppImage
BATOCERA_APPS_AARCH64_BRAVE_SOURCE = Brave-Web-Browser-stable-1.92.144-aarch64.AppImage
BATOCERA_APPS_AARCH64_CHROME_VERSION = 150.0.7871.186-1
BATOCERA_APPS_AARCH64_CHROME_SOURCE = google-chrome-stable_$(BATOCERA_APPS_AARCH64_CHROME_VERSION)_arm64.deb
BATOCERA_APPS_AARCH64_FIREFOX_SOURCE = firefox-152.0.5.tar.xz
BATOCERA_APPS_AARCH64_PEAZIP_SOURCE = peazip-flatpak-aarch64-11.2.0.tar.gz
BATOCERA_APPS_AARCH64_EXTRA_DOWNLOADS = \
	https://github.com/ivan-hc/Brave-appimage/releases/download/continuous-stable/$(BATOCERA_APPS_AARCH64_BRAVE_SOURCE) \
	https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/$(BATOCERA_APPS_AARCH64_CHROME_SOURCE) \
	https://download-installer.cdn.mozilla.net/pub/firefox/releases/152.0.5/linux-aarch64/en-US/$(BATOCERA_APPS_AARCH64_FIREFOX_SOURCE) \
	file+file://$(BATOCERA_APPS_AARCH64_PKGDIR)/dist/$(BATOCERA_APPS_AARCH64_PEAZIP_SOURCE)

BATOCERA_APPS_AARCH64_DEPENDENCIES = \
	alsa-lib \
	brotli \
	ca-certificates \
	cups \
	dbus \
	fontconfig \
	libcurl \
	liberation \
	libgbm \
	libgtk3 \
	libnss \
	libnspr \
	libxcb \
	libxkbcommon \
	p7zip \
	qt6base \
	vulkan-loader \
	wget \
	xlib_libX11 \
	xlib_libXcomposite \
	xlib_libXdamage \
	xlib_libXext \
	xlib_libXfixes \
	xlib_libXrandr \
	zstd

BATOCERA_APPS_AARCH64_PKGDIR = \
	$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-apps-aarch64

define BATOCERA_APPS_AARCH64_EXTRACT_CMDS
	cp $(DL_DIR)/$(BATOCERA_APPS_AARCH64_DL_SUBDIR)/$(BATOCERA_APPS_AARCH64_SOURCE) \
		$(@D)/vacuumtube.AppImage
	cp $(DL_DIR)/$(BATOCERA_APPS_AARCH64_DL_SUBDIR)/$(BATOCERA_APPS_AARCH64_BRAVE_SOURCE) \
		$(@D)/brave.AppImage
	mkdir -p $(@D)/google-chrome
	ar p $(DL_DIR)/$(BATOCERA_APPS_AARCH64_DL_SUBDIR)/$(BATOCERA_APPS_AARCH64_CHROME_SOURCE) \
		data.tar.xz | tar -xJf - -C $(@D)/google-chrome
	tar -xJf $(DL_DIR)/$(BATOCERA_APPS_AARCH64_DL_SUBDIR)/$(BATOCERA_APPS_AARCH64_FIREFOX_SOURCE) \
		-C $(@D)
	tar -xzf $(DL_DIR)/$(BATOCERA_APPS_AARCH64_DL_SUBDIR)/$(BATOCERA_APPS_AARCH64_PEAZIP_SOURCE) \
		-C $(@D)
endef

define BATOCERA_APPS_AARCH64_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/batocera/apps
	install -m 0644 $(@D)/vacuumtube.AppImage $(TARGET_DIR)/usr/share/batocera/apps/vacuumtube.AppImage
	install -m 0644 $(@D)/brave.AppImage $(TARGET_DIR)/usr/share/batocera/apps/brave.AppImage
	rm -rf $(TARGET_DIR)/usr/share/batocera/apps/google-chrome
	mkdir -p $(TARGET_DIR)/usr/share/batocera/apps/google-chrome
	cp -a $(@D)/google-chrome/opt/google/chrome/. \
		$(TARGET_DIR)/usr/share/batocera/apps/google-chrome/
	chmod 0755 $(TARGET_DIR)/usr/share/batocera/apps/google-chrome/chrome-sandbox
	cp -a $(@D)/firefox $(TARGET_DIR)/usr/share/batocera/apps/
	rm -rf $(TARGET_DIR)/usr/share/batocera/apps/peazip
	mkdir -p $(TARGET_DIR)/usr/share/batocera/apps/peazip
	cp -a $(@D)/peazip-flatpak-aarch64-11.2.0/. \
		$(TARGET_DIR)/usr/share/batocera/apps/peazip/

	install -D -m 0755 \
		$(BATOCERA_APPS_AARCH64_PKGDIR)/batocera-appimage-launcher \
		$(TARGET_DIR)/usr/libexec/batocera-appimage-launcher
	install -D -m 0755 \
		$(BATOCERA_APPS_AARCH64_PKGDIR)/batocera-app-vacuumtube \
		$(TARGET_DIR)/usr/bin/batocera-app-vacuumtube
	install -D -m 0755 \
		$(BATOCERA_APPS_AARCH64_PKGDIR)/batocera-app-brave \
		$(TARGET_DIR)/usr/bin/batocera-app-brave
	install -D -m 0755 \
		$(BATOCERA_APPS_AARCH64_PKGDIR)/batocera-app-chrome \
		$(TARGET_DIR)/usr/bin/batocera-app-chrome
	install -D -m 0755 \
		$(BATOCERA_APPS_AARCH64_PKGDIR)/batocera-app-firefox \
		$(TARGET_DIR)/usr/bin/batocera-app-firefox
	install -D -m 0755 \
		$(BATOCERA_APPS_AARCH64_PKGDIR)/batocera-app-peazip \
		$(TARGET_DIR)/usr/bin/batocera-app-peazip

	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images
	install -D -m 0644 $(BATOCERA_APPS_AARCH64_PKGDIR)/gamelist.xml \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/gamelist.xml
	install -D -m 0755 $(BATOCERA_APPS_AARCH64_PKGDIR)/roms/VacuumTube.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/VacuumTube.sh
	install -D -m 0644 $(BATOCERA_APPS_AARCH64_PKGDIR)/roms/VacuumTube.sh.keys \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/VacuumTube.sh.keys
	install -D -m 0755 $(BATOCERA_APPS_AARCH64_PKGDIR)/roms/Brave.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Brave.sh
	install -D -m 0755 $(BATOCERA_APPS_AARCH64_PKGDIR)/roms/Chrome.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Chrome.sh
	install -D -m 0755 $(BATOCERA_APPS_AARCH64_PKGDIR)/roms/Firefox.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Firefox.sh
	install -D -m 0755 $(BATOCERA_APPS_AARCH64_PKGDIR)/roms/PeaZip.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/PeaZip.sh
	install -D -m 0644 $(BATOCERA_APPS_AARCH64_PKGDIR)/images/vacuumtube.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/vacuumtube.png
	install -D -m 0644 $(BATOCERA_APPS_AARCH64_PKGDIR)/images/brave.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/brave.png
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/chrome.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/chrome.png
	install -D -m 0644 $(BATOCERA_APPS_AARCH64_PKGDIR)/images/firefox.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/firefox.png
	install -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/peazip.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/peazip.png
	if [ "$(BR2_PACKAGE_WAYDROID)" = "y" ]; then \
		install -D -m 0755 $(BATOCERA_APPS_AARCH64_PKGDIR)/roms/Waydroid.sh \
			$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/Waydroid.sh; \
		sed -i '/<\/gameList>/i\  <game>\n    <path>./Waydroid.sh</path>\n    <name>Waydroid</name>\n    <image>./images/waydroid.png</image>\n  </game>' \
			$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/gamelist.xml; \
		install -D -m 0644 $(BATOCERA_APPS_AARCH64_PKGDIR)/images/waydroid.png \
			$(TARGET_DIR)/usr/share/batocera/datainit/roms/apps/images/waydroid.png; \
	fi
endef

$(eval $(generic-package))
