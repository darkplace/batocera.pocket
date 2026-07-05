################################################################################
#
# lutris-appimage (AppImage)
#
################################################################################

LUTRIS_APPIMAGE_VERSION = 0.5.19-9
LUTRIS_APPIMAGE_RELEASE = $(LUTRIS_APPIMAGE_VERSION)%402026-02-15_1771141817
LUTRIS_APPIMAGE_LICENSE = GPL-3.0
LUTRIS_APPIMAGE_STRIP = NO
LUTRIS_APPIMAGE_TOOLCHAIN = manual
LUTRIS_APPIMAGE_DEPENDENCIES = openal

LUTRIS_APPIMAGE_SITE = https://github.com/pkgforge-dev/Lutris-AppImage/releases/download/$(LUTRIS_APPIMAGE_RELEASE)
LUTRIS_APPIMAGE_SOURCE = Lutris+wine-$(LUTRIS_APPIMAGE_VERSION)-anylinux-x86_64.AppImage

define LUTRIS_APPIMAGE_EXTRACT_CMDS
	cp $(DL_DIR)/$(LUTRIS_APPIMAGE_DL_SUBDIR)/$(LUTRIS_APPIMAGE_SOURCE) \
		$(@D)/lutris.AppImage
endef

define LUTRIS_APPIMAGE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/lutris
	install -m 0644 $(@D)/lutris.AppImage \
		$(TARGET_DIR)/usr/share/lutris/lutris.AppImage

	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/lutris-appimage/lutris \
		$(TARGET_DIR)/usr/bin/lutris

	for d in lib usr/lib usr/lib64; do \
		if [ -e "$(TARGET_DIR)/$$d/libopenal.so.1" ] && [ ! -e "$(TARGET_DIR)/$$d/libal.so.1" ]; then \
			ln -sf libopenal.so.1 "$(TARGET_DIR)/$$d/libal.so.1"; \
		fi; \
	done
endef

$(eval $(generic-package))
