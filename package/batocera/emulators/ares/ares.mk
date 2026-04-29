################################################################################
#
# ares
#
################################################################################

ARES_VERSION = f533120df6506390635a99ad58495834a69036e0
ARES_SITE = $(call github,ares-emulator,ares,$(ARES_VERSION))
ARES_LICENSE = GPL-3.0-or-later
ARES_LICENSE_FILES = LICENSE
ARES_SUPPORTS_IN_SOURCE_BUILD = NO

HOST_ARES_SUPPORTS_IN_SOURCE_BUILD = NO
HOST_ARES_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
HOST_ARES_CONF_OPTS += -DBUILD_SHARED_LIBS=FALSE
HOST_ARES_CONF_OPTS += -DWITH_SYSTEM_ZLIB=ON
HOST_ARES_CONF_OPTS += -DARES_BUILD_LOCAL=OFF
HOST_ARES_CONF_OPTS += -DARES_ENABLE_MINIMUM_CPU=OFF
HOST_ARES_CONF_OPTS += -DARES_BUILD_SOURCERY_ONLY=ON
HOST_ARES_CONF_OPTS += -DCMAKE_CROSSCOMPILING=OFF
HOST_ARES_CONF_OPTS += -DARES_CROSSCOMPILING=OFF

define HOST_ARES_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/tools/sourcery/sourcery \
		$(HOST_DIR)/bin/sourcery
	$(INSTALL) -D -m 0644 $(@D)/buildroot-build/sourceryConfig.cmake \
		$(HOST_DIR)/lib/cmake/sourcery/sourceryConfig.cmake
endef

ARES_DEPENDENCIES += host-ares libao libgtk3 openal sdl3 zlib

ARES_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
ARES_CONF_OPTS += -DBUILD_SHARED_LIBS=FALSE
ARES_CONF_OPTS += -DWITH_SYSTEM_ZLIB=ON
ARES_CONF_OPTS += -DARES_BUILD_LOCAL=OFF
ARES_CONF_OPTS += -DARES_ENABLE_MINIMUM_CPU=OFF
ARES_CONF_OPTS += -DARES_ENABLE_LIBRASHADER=OFF
ARES_CONF_OPTS += -Dsourcery_DIR=$(HOST_DIR)/lib/cmake/sourcery

define ARES_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/desktop-ui/ares \
		$(TARGET_DIR)/usr/bin/ares
	mkdir -p $(TARGET_DIR)/usr/share/ares
	cp -rf $(@D)/buildroot-build/rundir/share/ares/Database \
		$(TARGET_DIR)/usr/share/ares/
	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/system/configs/ares
	cp -rf $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/ares/config/ares/. \
		$(TARGET_DIR)/usr/share/batocera/datainit/system/configs/ares/
endef

$(eval $(cmake-package))
$(eval $(host-cmake-package))
