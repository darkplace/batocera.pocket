################################################################################
#
# libretro-skyemu
#
################################################################################

LIBRETRO_SKYEMU_VERSION = 46efbcbdb3b902373a09f4724e6d3b1a5acc4af3
LIBRETRO_SKYEMU_SITE = $(call github,skylersaleh,SkyEmu,$(LIBRETRO_SKYEMU_VERSION))
LIBRETRO_SKYEMU_LICENSE = MIT
LIBRETRO_SKYEMU_LICENSE_FILES = LICENSE
LIBRETRO_SKYEMU_DEPENDENCIES = retroarch
LIBRETRO_SKYEMU_SUPPORTS_IN_SOURCE_BUILD = NO
LIBRETRO_SKYEMU_EMULATOR_INFO = skyemu.libretro.core.yml

LIBRETRO_SKYEMU_CONF_OPTS = -DCMAKE_BUILD_TYPE=Release
LIBRETRO_SKYEMU_CONF_OPTS += -DRETRO_CORE_ONLY=ON
LIBRETRO_SKYEMU_CONF_OPTS += -DENABLE_RETRO_ACHIEVEMENTS=ON
LIBRETRO_SKYEMU_BUILD_OPTS = --target skyemu_libretro

define LIBRETRO_SKYEMU_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/buildroot-build/skyemu_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/skyemu_libretro.so
	$(INSTALL) -D $(@D)/skyemu_libretro.info \
		$(TARGET_DIR)/usr/share/libretro/info/skyemu_libretro.info
endef

$(eval $(cmake-package))
$(eval $(emulator-info-package))
