################################################################################
#
# libretro-azahar
#
################################################################################

LIBRETRO_AZAHAR_VERSION = 2125.0
LIBRETRO_AZAHAR_SITE = https://github.com/azahar-emu/azahar
LIBRETRO_AZAHAR_SITE_METHOD = git
LIBRETRO_AZAHAR_GIT_SUBMODULES = YES
LIBRETRO_AZAHAR_LICENSE = GPLv2
LIBRETRO_AZAHAR_DEPENDENCIES = retroarch
LIBRETRO_AZAHAR_SUPPORTS_IN_SOURCE_BUILD = NO
LIBRETRO_AZAHAR_CMAKE_BACKEND = ninja

# Keep the frontend core identity on Batocera as "citra" so existing
# libretro options, RetroAchievements allowlists, and 3DS bezel handling
# continue to work unchanged while the actual core implementation moves to Azahar.
LIBRETRO_AZAHAR_EMULATOR_INFO = citra.libretro.core.yml

LIBRETRO_AZAHAR_CONF_OPTS = -DCMAKE_BUILD_TYPE=Release
LIBRETRO_AZAHAR_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
LIBRETRO_AZAHAR_CONF_OPTS += -DENABLE_LIBRETRO=ON
LIBRETRO_AZAHAR_CONF_OPTS += -DENABLE_OPENGL=ON
LIBRETRO_AZAHAR_CONF_OPTS += -DCITRA_WARNINGS_AS_ERRORS=OFF
LIBRETRO_AZAHAR_CONF_OPTS += -DCITRA_USE_PRECOMPILED_HEADERS=OFF
LIBRETRO_AZAHAR_CONF_OPTS += -DENABLE_LTO=OFF
LIBRETRO_AZAHAR_BUILD_OPTS = --target azahar_libretro

ifeq ($(BR2_PACKAGE_BATOCERA_VULKAN),y)
LIBRETRO_AZAHAR_CONF_OPTS += -DENABLE_VULKAN=ON
LIBRETRO_AZAHAR_DEPENDENCIES += vulkan-headers vulkan-loader
else
LIBRETRO_AZAHAR_CONF_OPTS += -DENABLE_VULKAN=OFF
endif

define LIBRETRO_AZAHAR_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/buildroot-build/bin/Release/azahar_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/azahar_libretro.so
	ln -sf azahar_libretro.so $(TARGET_DIR)/usr/lib/libretro/citra_libretro.so
	$(INSTALL) -D \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/retroarch/libretro/libretro-azahar/citra_libretro.info \
		$(TARGET_DIR)/usr/share/libretro/info/citra_libretro.info
	ln -sf citra_libretro.info $(TARGET_DIR)/usr/share/libretro/info/azahar_libretro.info
endef

$(eval $(cmake-package))
$(eval $(emulator-info-package))
