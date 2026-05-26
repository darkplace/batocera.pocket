################################################################################
#
# armsx2
#
################################################################################

ARMSX2_VERSION = come.nanodata.armsx2-nightly-1.0.8-20260504-1621
ARMSX2_SITE = https://github.com/ARMSX2/ARMSX2.git
ARMSX2_SITE_METHOD = git
ARMSX2_GIT_SUBMODULES = YES
ARMSX2_LICENSE = GPL-3.0-or-later
ARMSX2_LICENSE_FILE = COPYING.GPLv3
ARMSX2_SUPPORTS_IN_SOURCE_BUILD = NO

ARMSX2_PC_VERSION = cdb920792b275a24637be1ddde31bafce659aa05
ARMSX2_PC_SOURCE = armsx2-pc-$(ARMSX2_PC_VERSION).tar.gz
ARMSX2_EXTRA_DOWNLOADS = $(call github,SetiQyu,ARMSX2-PC,$(ARMSX2_PC_VERSION))/$(ARMSX2_PC_SOURCE)

ARMSX2_DEPENDENCIES += alsa-lib dbus ecm fmt freetype host-clang host-libcurl kddockwidgets
ARMSX2_DEPENDENCIES += libaio libbacktrace libcurl libgtk3 libpcap libpng libsamplerate
ARMSX2_DEPENDENCIES += libsoundtouch plutosvg portaudio qt6base qt6svg qt6tools
ARMSX2_DEPENDENCIES += sdl3 webp wxwidgets xorgproto yaml-cpp zlib

ARMSX2_CONF_OPTS += -DCMAKE_C_COMPILER=$(HOST_DIR)/bin/clang
ARMSX2_CONF_OPTS += -DCMAKE_CXX_COMPILER=$(HOST_DIR)/bin/clang++
ARMSX2_CONF_OPTS += -DCMAKE_EXE_LINKER_FLAGS="-lm -lstdc++"

ifeq ($(BR2_PACKAGE_BATOCERA_VULKAN),y)
ARMSX2_DEPENDENCIES += shaderc vulkan-headers vulkan-loader
ARMSX2_CONF_OPTS += -DUSE_VULKAN=ON
else
ARMSX2_CONF_OPTS += -DUSE_VULKAN=OFF
endif

ifeq ($(BR2_PACKAGE_HAS_LIBGL),y)
ARMSX2_CONF_OPTS += -DUSE_OPENGL=ON
else
ARMSX2_CONF_OPTS += -DUSE_OPENGL=OFF
endif

ifeq ($(BR2_PACKAGE_XORG7),y)
ARMSX2_DEPENDENCIES += xlib_libX11 xlib_libXext xlib_libXi xlib_libXrandr xlib_libXrender
ARMSX2_CONF_OPTS += -DX11_API=ON
else
ARMSX2_CONF_OPTS += -DX11_API=OFF
endif

ifeq ($(BR2_PACKAGE_BATOCERA_WAYLAND),y)
ARMSX2_DEPENDENCIES += wayland wayland-protocols
ARMSX2_CONF_OPTS += -DWAYLAND_API=ON
else
ARMSX2_CONF_OPTS += -DWAYLAND_API=OFF
endif

ARMSX2_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
ARMSX2_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
ARMSX2_CONF_OPTS += -DENABLE_QT_UI=ON
ARMSX2_CONF_OPTS += -DENABLE_TESTS=OFF
ARMSX2_CONF_OPTS += -DUSE_SYSTEM_LIBS=AUTO
ARMSX2_CONF_OPTS += -DDISABLE_ADVANCE_SIMD=OFF
ARMSX2_CONF_OPTS += -DHOST_PAGE_SIZE=0x1000
ARMSX2_CONF_OPTS += -DHOST_CACHE_LINE_SIZE=64

define ARMSX2_OVERLAY_PC_SOURCE
	mkdir -p $(@D)/.armsx2-pc
	$(call suitable-extractor,$(ARMSX2_PC_SOURCE)) $(ARMSX2_DL_DIR)/$(ARMSX2_PC_SOURCE) | \
		$(TAR) --strip-components=1 -C $(@D)/.armsx2-pc $(TAR_OPTIONS) -
	rsync -a \
		--exclude='.git' \
		--exclude='CMakeCache.txt' \
		--exclude='CMakeFiles' \
		--exclude='build' \
		--exclude='buildroot-build' \
		$(@D)/.armsx2-pc/ $(@D)/
	rm -rf $(@D)/.armsx2-pc
endef

ARMSX2_POST_EXTRACT_HOOKS += ARMSX2_OVERLAY_PC_SOURCE

# ARMSX2/PCSX2 has several large C++ translation units; keep peak RAM below
# the sm8550 builder's limit instead of inheriting Buildroot's full -j value.
ARMSX2_BUILD_OPTS = -- -j4

define ARMSX2_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/bin/pcsx2-qt \
		$(TARGET_DIR)/usr/armsx2/bin/pcsx2-qt
	cp -pr $(@D)/bin/resources $(TARGET_DIR)/usr/armsx2/bin/
	if [ -d $(@D)/buildroot-build/bin/translations ]; then \
		cp -pr $(@D)/buildroot-build/bin/translations $(TARGET_DIR)/usr/armsx2/bin/; \
	fi
	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/armsx2/scripts/start_armsx2.sh \
		$(TARGET_DIR)/usr/bin/start_armsx2.sh
	ln -sf /usr/armsx2/bin/pcsx2-qt $(TARGET_DIR)/usr/bin/armsx2
endef

$(eval $(cmake-package))
