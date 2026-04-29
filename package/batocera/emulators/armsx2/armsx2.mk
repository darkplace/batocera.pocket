################################################################################
#
# armsx2
#
################################################################################

ARMSX2_VERSION = refresh
ARMSX2_SITE = https://github.com/zeruth/ARMSX2.git
ARMSX2_SITE_METHOD = git
ARMSX2_LICENSE = GPL-3.0-or-later
ARMSX2_SUPPORTS_IN_SOURCE_BUILD = NO
ARMSX2_SUBDIR = ARMSX2/app/src/main/cpp

ARMSX2_DEPENDENCIES += alsa-lib libcurl dbus libpcap zlib

ifeq ($(BR2_PACKAGE_BATOCERA_VULKAN),y)
ARMSX2_DEPENDENCIES += vulkan-headers vulkan-loader
endif

ifeq ($(BR2_PACKAGE_HAS_LIBGL),y)
ARMSX2_DEPENDENCIES += libglvnd
endif

ARMSX2_CONF_OPTS += -DCMAKE_BUILD_TYPE=RelWithDebInfo
ARMSX2_CONF_OPTS += -DENABLE_QT_UI=OFF
ARMSX2_CONF_OPTS += -DUSE_BACKTRACE=OFF
ARMSX2_CONF_OPTS += -DUSE_VULKAN=OFF
ARMSX2_CONF_OPTS += -DUSE_OPENGL=ON
ARMSX2_CONF_OPTS += -DDISABLE_ADVANCE_SIMD=ON
ARMSX2_CONF_OPTS += -DHOST_PAGE_SIZE=0x1000
ARMSX2_CONF_OPTS += -DHOST_CACHE_LINE_SIZE=64

# ARMSX2/PCSX2 has several large C++ translation units; keep peak RAM below
# the sm8550 builder's limit instead of inheriting Buildroot's full -j value.
ARMSX2_BUILD_OPTS = -- -j4

define ARMSX2_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/$(ARMSX2_SUBDIR)/buildroot-build/bin/armsx2 \
		$(TARGET_DIR)/usr/bin/armsx2
	mkdir -p $(TARGET_DIR)/usr/share/armsx2/assets
	cp -rf $(@D)/ARMSX2/app/src/main/assets/* \
		$(TARGET_DIR)/usr/share/armsx2/assets/
	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/armsx2/scripts/start_armsx2.sh \
		$(TARGET_DIR)/usr/bin/start_armsx2.sh
	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/system/configs/armsx2
	cp -rf $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/armsx2/config/armsx2/. \
		$(TARGET_DIR)/usr/share/batocera/datainit/system/configs/armsx2/
endef

$(eval $(cmake-package))
