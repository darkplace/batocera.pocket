################################################################################
#
# wine-ge-proton
#
################################################################################

WINE_GE_PROTON_VERSION = GE-Proton10-34
WINE_GE_PROTON_SOURCE = $(WINE_GE_PROTON_VERSION).tar.gz
WINE_GE_PROTON_SITE = https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$(WINE_GE_PROTON_VERSION)
WINE_GE_PROTON_LICENSE = GPL-3.0+
WINE_GE_PROTON_BIN_ARCH_EXCLUDE += /usr/wine/proton-ge


define WINE_GE_PROTON_INSTALL_TARGET_CMDS
	rm -rf $(TARGET_DIR)/usr/wine/proton-ge
	mkdir -p $(TARGET_DIR)/usr/wine/proton-ge
	rsync -a --exclude='.*' $(@D)/ $(TARGET_DIR)/usr/wine/proton-ge/
endef

$(eval $(generic-package))
