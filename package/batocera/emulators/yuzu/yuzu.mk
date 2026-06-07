################################################################################
#
# yuzu
#
################################################################################

YUZU_VERSION = refs/tags/ea-4176
YUZU_SITE = https://github.com/exverge-0/yuzu-EA4176.git
YUZU_SITE_METHOD = git
YUZU_GIT_SUBMODULES = YES
YUZU_LICENSE = GPL-3.0
YUZU_LICENSE_FILES = LICENSE.txt
YUZU_SUPPORTS_IN_SOURCE_BUILD = NO

YUZU_DEPENDENCIES = host-pkgconf host-clang boost enet ffmpeg fmt json-for-modern-cpp \
	libopenssl lz4 opus qt6base sdl2 vulkan-headers vulkan-loader zlib zstd

YUZU_CMAKE_BACKEND = ninja
YUZU_CLANG_FLAGS = -Qunused-arguments

YUZU_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
YUZU_CONF_OPTS += -DCMAKE_C_COMPILER=$(HOST_DIR)/bin/clang
YUZU_CONF_OPTS += -DCMAKE_CXX_COMPILER=$(HOST_DIR)/bin/clang++
YUZU_CONF_OPTS += -DCMAKE_C_FLAGS="$(TARGET_CFLAGS) $(YUZU_CLANG_FLAGS)"
YUZU_CONF_OPTS += -DCMAKE_CXX_FLAGS="$(TARGET_CXXFLAGS) $(YUZU_CLANG_FLAGS)"
YUZU_CONF_OPTS += -DCMAKE_EXE_LINKER_FLAGS="-lm -lstdc++"
YUZU_CONF_OPTS += -DTZDB2NX_PATH=$(@D)/host-tools/tzdb2nx
YUZU_CONF_OPTS += -DBUILD_TESTING=OFF
YUZU_CONF_OPTS += -DYUZU_TESTS=OFF
YUZU_CONF_OPTS += -DYUZU_CHECK_SUBMODULES=ON
YUZU_CONF_OPTS += -DYUZU_USE_PRECOMPILED_HEADERS=OFF
YUZU_CONF_OPTS += -DYUZU_USE_FASTER_LD=OFF
YUZU_CONF_OPTS += -DYUZU_ENABLE_LTO=OFF
YUZU_CONF_OPTS += -DYUZU_ENABLE_PORTABLE=OFF
YUZU_CONF_OPTS += -DYUZU_DOWNLOAD_TIME_ZONE_DATA=OFF
YUZU_CONF_OPTS += -DENABLE_COMPATIBILITY_LIST_DOWNLOAD=OFF
YUZU_CONF_OPTS += -DENABLE_QT=ON
YUZU_CONF_OPTS += -DENABLE_QT6=ON
YUZU_CONF_OPTS += -DENABLE_QT_TRANSLATION=OFF
YUZU_CONF_OPTS += -DENABLE_SDL2=ON
YUZU_CONF_OPTS += -DENABLE_WEB_SERVICE=OFF
YUZU_CONF_OPTS += -DENABLE_LIBUSB=OFF
YUZU_CONF_OPTS += -DENABLE_CUBEB=OFF
YUZU_CONF_OPTS += -DENABLE_OPENSSL=ON
YUZU_CONF_OPTS += -DUSE_DISCORD_PRESENCE=OFF
YUZU_CONF_OPTS += -DYUZU_USE_BUNDLED_QT=OFF
YUZU_CONF_OPTS += -DYUZU_USE_BUNDLED_SDL2=OFF
YUZU_CONF_OPTS += -DYUZU_USE_EXTERNAL_SDL2=OFF
YUZU_CONF_OPTS += -DYUZU_USE_BUNDLED_FFMPEG=OFF
YUZU_CONF_OPTS += -DYUZU_USE_QT_MULTIMEDIA=OFF
YUZU_CONF_OPTS += -DYUZU_USE_QT_WEB_ENGINE=OFF

define YUZU_BUILD_HOST_TZDB2NX
	mkdir -p $(@D)/host-tools
	$(HOSTCXX) $(HOST_CXXFLAGS) -std=c++20 -O2 \
		-I$(@D)/externals/nx_tzdb/tzdb_to_nx/src/tzdb2nx \
		$(@D)/externals/nx_tzdb/tzdb_to_nx/src/tzdb2nx/main.cpp \
		$(@D)/externals/nx_tzdb/tzdb_to_nx/src/tzdb2nx/tzif.cpp \
		-o $(@D)/host-tools/tzdb2nx
endef
YUZU_PRE_CONFIGURE_HOOKS += YUZU_BUILD_HOST_TZDB2NX

define YUZU_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/libexec/yuzu
	find $(@D)/buildroot-build -name "yuzu" -type f -perm /111 \
		| head -1 \
		| xargs -I{} $(INSTALL) -D -m 0755 {} $(TARGET_DIR)/usr/libexec/yuzu/yuzu

	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/yuzu/yuzu \
		$(TARGET_DIR)/usr/bin/yuzu
endef

$(eval $(cmake-package))
