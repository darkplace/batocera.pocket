################################################################################
#
# wine-staging-tkg (Kron4ek build)
#
################################################################################

WINE_TKG_VERSION = 11.2
WINE_TKG_SOURCE = wine-$(WINE_TKG_VERSION)-staging-tkg-amd64-wow64.tar.xz
WINE_TKG_SITE = https://github.com/Kron4ek/Wine-Builds/releases/download/$(WINE_TKG_VERSION)

WINE_TKG_LICENSE = MIT
WINE_TKG_LICENSE_FILE = LICENSE
WINE_TKG_BIN_ARCH_EXCLUDE += /usr/wine/wine-tkg

define WINE_TKG_INSTALL_TARGET_CMDS
	rm -rf $(TARGET_DIR)/usr/wine/wine-tkg
	mkdir -p $(TARGET_DIR)/usr/wine/wine-tkg
	rsync -a --exclude='.*' $(@D)/ $(TARGET_DIR)/usr/wine/wine-tkg/
endef

$(eval $(generic-package))
