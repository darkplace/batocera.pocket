################################################################################
#
# umu-launcher
#
################################################################################

UMU_LAUNCHER_VERSION = 1.3.0
UMU_LAUNCHER_SOURCE = umu-launcher-$(UMU_LAUNCHER_VERSION)-zipapp.tar
UMU_LAUNCHER_SITE = https://github.com/Open-Wine-Components/umu-launcher/releases/download/$(UMU_LAUNCHER_VERSION)
UMU_LAUNCHER_LICENSE = GPL-3.0+
UMU_LAUNCHER_BIN_ARCH_EXCLUDE += /usr/libexec/umu


define UMU_LAUNCHER_EXTRACT_CMDS
	mkdir -p $(@D)/target && cd $(@D)/target && \
		tar xf $(DL_DIR)/$(UMU_LAUNCHER_DL_SUBDIR)/$(UMU_LAUNCHER_SOURCE)
endef


define UMU_LAUNCHER_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/libexec/umu
	mkdir -p $(TARGET_DIR)/usr/share/batocera/wine/umu
	install -m 0755 $(@D)/target/umu/umu-run $(TARGET_DIR)/usr/libexec/umu/umu-run
	install -m 0644 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/wine/umu-launcher/sitecustomize.py \
		$(TARGET_DIR)/usr/share/batocera/wine/umu/sitecustomize.py
	install -m 0755 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/wine/umu-launcher/umu-run-wrapper \
		$(TARGET_DIR)/usr/bin/umu-run
endef

$(eval $(generic-package))
