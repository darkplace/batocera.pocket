################################################################################
#
# sunshine-appimage (AppImage)
#
################################################################################

SUNSHINE_APPIMAGE_VERSION = v2025.924.154138
SUNSHINE_APPIMAGE_LICENSE = GPL-3.0
SUNSHINE_APPIMAGE_STRIP = NO
SUNSHINE_APPIMAGE_TOOLCHAIN = manual

SUNSHINE_APPIMAGE_SITE = https://github.com/LizardByte/Sunshine/releases/download/$(SUNSHINE_APPIMAGE_VERSION)
SUNSHINE_APPIMAGE_SOURCE = sunshine.AppImage

define SUNSHINE_APPIMAGE_EXTRACT_CMDS
	cp $(DL_DIR)/$(SUNSHINE_APPIMAGE_DL_SUBDIR)/$(SUNSHINE_APPIMAGE_SOURCE) \
		$(@D)/sunshine.AppImage
endef

define SUNSHINE_APPIMAGE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/sunshine
	install -m 0644 $(@D)/sunshine.AppImage \
		$(TARGET_DIR)/usr/share/sunshine/sunshine.AppImage

	# Drop legacy launcher from old incremental target trees.
	rm -f $(TARGET_DIR)/usr/share/batocera/datainit/roms/ports/Sunshine.Web.UI.sh

	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/sunshine-appimage/batocera-sunshine \
		$(TARGET_DIR)/usr/bin/batocera-sunshine
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/sunshine-appimage/sunshine \
		$(TARGET_DIR)/usr/share/batocera/services/sunshine
endef

$(eval $(generic-package))
