################################################################################
#
# armsx2
#
################################################################################

ARMSX2_VERSION = 2d73c39f03e8ab515c36f4a9b0f91f0db79ca0e7
ARMSX2_SITE = https://github.com/ARMSX2/ARMSX2.git
ARMSX2_SITE_METHOD = git
ARMSX2_LICENSE = GPL-3.0-or-later
ARMSX2_LICENSE_FILE = COPYING.GPLv3
ARMSX2_SUPPORTS_IN_SOURCE_BUILD = NO

ARMSX2_DEPENDENCIES += alsa-lib dbus ecm fmt fontconfig freetype host-clang host-libcurl kddockwidgets
ARMSX2_DEPENDENCIES += libaio libbacktrace libcurl libgtk3 libpcap libpng libsamplerate
ARMSX2_DEPENDENCIES += jpeg libsoundtouch lz4 plutosvg portaudio qt6base qt6svg qt6tools
ARMSX2_DEPENDENCIES += rapidyaml sdl3 webp wxwidgets xorgproto yaml-cpp zlib zstd

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

# ARMSX2/PCSX2 has several large C++ translation units; keep peak RAM below
# the sm8550 builder's limit instead of inheriting Buildroot's full -j value.
ARMSX2_BUILD_OPTS = -- -j4

define ARMSX2_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/bin/armsx2-qt \
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
