################################################################################
#
# yaps2
#
################################################################################

PCSX2_VERSION = dbb7eade69c1befc6410fe636811010d340ef886
PCSX2_SITE = https://github.com/yaps2/yaps2.git
PCSX2_SITE_METHOD = git
PCSX2_LICENSE = GPLv3
PCSX2_LICENSE_FILE = COPYING.GPLv3
PCSX2_EMULATOR_INFO = yaps2.emulator.yml

PCSX2_SUPPORTS_IN_SOURCE_BUILD = NO

PCSX2_DEPENDENCIES += alsa-lib ecm ffmpeg fmt freetype host-clang host-libcurl kddockwidgets
PCSX2_DEPENDENCIES += libaio libbacktrace libcurl libgtk3 libpcap libpng libsamplerate
PCSX2_DEPENDENCIES += jpeg libsoundtouch lz4 plutosvg portaudio qt6base qt6svg qt6tools
PCSX2_DEPENDENCIES += shaderc sdl3 webp wxwidgets xorgproto yaml-cpp zlib zstd

# Use clang for performance
PCSX2_CONF_OPTS += -DCMAKE_C_COMPILER=$(HOST_DIR)/bin/clang
PCSX2_CONF_OPTS += -DCMAKE_CXX_COMPILER=$(HOST_DIR)/bin/clang++
PCSX2_CONF_OPTS += -DCMAKE_EXE_LINKER_FLAGS="-lm -lstdc++"

PCSX2_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
PCSX2_CONF_OPTS += -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF
PCSX2_CONF_OPTS += -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON
PCSX2_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
PCSX2_CONF_OPTS += -DENABLE_QT_UI=ON
PCSX2_CONF_OPTS += -DENABLE_TESTS=OFF
PCSX2_CONF_OPTS += -DUSE_BACKTRACE=OFF
PCSX2_CONF_OPTS += -DUSE_SYSTEM_LIBS=AUTO

ifeq ($(BR2_PACKAGE_XORG7),y)
    PCSX2_DEPENDENCIES += xlib_libX11 xlib_libXext
    PCSX2_CONF_OPTS += -DX11_API=ON
else
    PCSX2_CONF_OPTS += -DX11_API=OFF
endif

ifeq ($(BR2_PACKAGE_BATOCERA_WAYLAND),y)
    PCSX2_DEPENDENCIES += wayland wayland-protocols
    PCSX2_CONF_OPTS += -DWAYLAND_API=ON
else
    PCSX2_CONF_OPTS += -DWAYLAND_API=OFF
endif

ifeq ($(BR2_PACKAGE_HAS_LIBGL),y)
    PCSX2_CONF_OPTS += -DUSE_OPENGL=ON
else
    PCSX2_CONF_OPTS += -DUSE_OPENGL=OFF
endif

ifeq ($(BR2_PACKAGE_BATOCERA_VULKAN),y)
    PCSX2_CONF_OPTS += -DUSE_VULKAN=ON
else
    PCSX2_CONF_OPTS += -DUSE_VULKAN=OFF
endif

# PCSX2 has several large C++ translation units; keep peak RAM below the
# sm8x50 builders' limit instead of inheriting Buildroot's full -j value.
PCSX2_BUILD_OPTS = -- -j4

define PCSX2_INSTALL_TARGET_CMDS
	$(INSTALL) -m 0755 -D $(@D)/buildroot-build/bin/yaps2-qt \
        $(TARGET_DIR)/usr/pcsx2/bin/pcsx2-qt
	cp -pr  $(@D)/bin/resources $(TARGET_DIR)/usr/pcsx2/bin/
    if [ -d $(@D)/buildroot-build/bin/translations ]; then \
        cp -pr $(@D)/buildroot-build/bin/translations $(TARGET_DIR)/usr/pcsx2/bin/; \
    fi
    # use our SDL config
    rm -f $(TARGET_DIR)/usr/pcsx2/bin/resources/game_controller_db.txt
endef

define PCSX2_TEXTURES
	mkdir -p $(TARGET_DIR)/usr/pcsx2/bin/resources/textures
	cp -pr $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/pcsx2/textures/ \
        $(TARGET_DIR)/usr/pcsx2/bin/resources/
endef

# Download and copy PCSX2 patches.zip to BIOS folder
define PCSX2_PATCHES
    mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/bios/ps2
    $(HOST_DIR)/bin/curl -L \
        https://github.com/PCSX2/pcsx2_patches/releases/download/latest/patches.zip -o \
        $(TARGET_DIR)/usr/share/batocera/datainit/bios/ps2/patches.zip
endef

PCSX2_POST_INSTALL_TARGET_HOOKS += PCSX2_TEXTURES
PCSX2_POST_INSTALL_TARGET_HOOKS += PCSX2_PATCHES

define PCSX2_CROSSHAIRS
	mkdir -p $(TARGET_DIR)/usr/pcsx2/bin/resources/crosshairs
	cp -pr $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/pcsx2/crosshairs/ \
        $(TARGET_DIR)/usr/pcsx2/bin/resources/
endef

PCSX2_POST_INSTALL_TARGET_HOOKS += PCSX2_CROSSHAIRS

$(eval $(cmake-package))
$(eval $(emulator-info-package))
