################################################################################
#
# skyemu
#
################################################################################

SKYEMU_VERSION = 46efbcbdb3b902373a09f4724e6d3b1a5acc4af3
SKYEMU_SITE = $(call github,skylersaleh,SkyEmu,$(SKYEMU_VERSION))
SKYEMU_LICENSE = MIT
SKYEMU_LICENSE_FILES = LICENSE
SKYEMU_DEPENDENCIES = sdl2 openssl libcurl alsa-lib xlib_libX11 xlib_libXi xlib_libXcursor
SKYEMU_SUPPORTS_IN_SOURCE_BUILD = NO

SKYEMU_CONF_OPTS = -DCMAKE_BUILD_TYPE=Release
SKYEMU_CONF_OPTS += -DENABLE_RETRO_ACHIEVEMENTS=ON
SKYEMU_CONF_OPTS += -DUSE_SYSTEM_CURL=ON
SKYEMU_CONF_OPTS += -DUSE_SYSTEM_OPENSSL=ON
SKYEMU_CONF_OPTS += -DUSE_SYSTEM_SDL2=ON
SKYEMU_CONF_OPTS += -DRETRO_CORE_ONLY=OFF

define SKYEMU_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/bin/SkyEmu \
		$(TARGET_DIR)/usr/bin/SkyEmu
endef

$(eval $(cmake-package))
