################################################################################
#
# libretro-mame2010
#
################################################################################
# Version: Commits on Oct 15, 2024 (latest from libretro/mame2010-libretro)
LIBRETRO_MAME2010_VERSION = c5b413b71e0a290c57fc351562cd47ba75bac105
LIBRETRO_MAME2010_SITE = $(call github,libretro,mame2010-libretro,$(LIBRETRO_MAME2010_VERSION))
LIBRETRO_MAME2010_LICENSE = MAME

LIBRETRO_MAME2010_PLATFORM = $(LIBRETRO_PLATFORM)

ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_BCM2836),y)
LIBRETRO_MAME2010_PLATFORM = rpi2
else ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_BCM2837),y)
LIBRETRO_MAME2010_PLATFORM = rpi3_64
else ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_BCM2711),y)
LIBRETRO_MAME2010_PLATFORM = rpi4
else ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_BCM2712),y)
LIBRETRO_MAME2010_PLATFORM = rpi5
else ifeq ($(BR2_aarch64),y)
LIBRETRO_MAME2010_PLATFORM = unix
else ifeq ($(BR2_arm),y)
LIBRETRO_MAME2010_PLATFORM = armv
endif

ifeq ($(BR2_x86_64),y)
LIBRETRO_MAME2010_EXTRA_ARGS = PTR64=1 AMD64=1
endif

define LIBRETRO_MAME2010_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" \
		-C $(@D)/ -f Makefile platform="$(LIBRETRO_MAME2010_PLATFORM)" \
		$(LIBRETRO_MAME2010_EXTRA_ARGS)
endef

define LIBRETRO_MAME2010_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/mame2010_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/mame0139_libretro.so
endef

$(eval $(generic-package))
