################################################################################
#
# eden
#
################################################################################

EDEN_VERSION = v0.2.0
EDEN_LICENSE = GPL-3.0-or-later
EDEN_STRIP = NO
EDEN_TOOLCHAIN = manual

EDEN_SITE = https://git.eden-emu.dev/eden-emu/eden/releases/download/$(EDEN_VERSION)
EDEN_SOURCE = Eden-Linux-$(EDEN_VERSION)-aarch64-clang-pgo.AppImage

define EDEN_EXTRACT_CMDS
	cp $(DL_DIR)/$(EDEN_DL_SUBDIR)/$(EDEN_SOURCE) \
		$(@D)/eden.AppImage
endef

define EDEN_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/eden
	install -m 0644 $(@D)/eden.AppImage \
		$(TARGET_DIR)/usr/share/eden/eden.AppImage

	mkdir -p $(TARGET_DIR)/usr/bin
	install -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/eden/eden \
		$(TARGET_DIR)/usr/bin/eden

	mkdir -p $(TARGET_DIR)/usr/share/evmapy
	cp -prn $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/eden/switch.eden.keys \
		$(TARGET_DIR)/usr/share/evmapy/
endef

$(eval $(generic-package))
