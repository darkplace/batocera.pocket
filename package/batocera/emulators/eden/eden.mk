################################################################################
#
# eden
#
################################################################################

EDEN_APPIMAGE_VERSION = v0.2.0
EDEN_APPIMAGE_SOURCE = Eden-Linux-$(EDEN_APPIMAGE_VERSION)-aarch64-clang-pgo.AppImage
EDEN_APPIMAGE_SITE = https://git.eden-emu.dev/eden-emu/eden/releases/download/$(EDEN_APPIMAGE_VERSION)

EDEN_LICENSE = GPL-3.0-or-later
EDEN_STRIP = NO

ifeq ($(BR2_PACKAGE_EDEN_NATIVE),y)

EDEN_VERSION = 58c1e20ee58efa3900ba616207d460886214480b
EDEN_SITE = https://github.com/UzuCore/eden.git
EDEN_SITE_METHOD = git
EDEN_LICENSE_FILES = LICENSE.txt
EDEN_EXTRA_DOWNLOADS = $(EDEN_APPIMAGE_SITE)/$(EDEN_APPIMAGE_SOURCE)
EDEN_SUPPORTS_IN_SOURCE_BUILD = NO
EDEN_CMAKE_BACKEND = ninja

EDEN_DEPENDENCIES = \
	host-clang \
	host-lld \
	host-ninja \
	host-pkgconf \
	boost \
	ffmpeg \
	fmt \
	json-for-modern-cpp \
	libdrm \
	libenet \
	libevdev \
	libopenssl \
	libusb \
	libzip \
	lz4 \
	opus \
	qt6base \
	qt6charts \
	quazip \
	sdl3 \
	spirv-headers \
	spirv-tools \
	vulkan-headers \
	vulkan-loader \
	vulkan-utility-libraries \
	zlib \
	zstd

ifeq ($(BR2_PACKAGE_HAS_LIBGL),y)
EDEN_DEPENDENCIES += libgl
EDEN_CONF_OPTS += -DENABLE_OPENGL=ON -DOpenGL_GL_PREFERENCE=GLVND
else
EDEN_CONF_OPTS += -DENABLE_OPENGL=OFF
endif

ifeq ($(BR2_PACKAGE_LIBGLVND),y)
EDEN_DEPENDENCIES += libglvnd
endif

EDEN_CONF_ENV += \
	PATH=$(HOST_DIR)/bin:$(PATH)

EDEN_OPT_FLAGS = -DARCHITECTURE_arm64=1
EDEN_LINK_FLAGS = $(TARGET_LDFLAGS)
EDEN_INTERPROCEDURAL_OPTIMIZATION = OFF

# Keep Eden's native code on the CPU features exposed by each BSP.  In
# particular, cortex-x3 enables SVE/SVE2, which neither target exposes.
ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_SM8750),y)
EDEN_CPU_FLAGS = -mcpu=oryon-1
else ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_SM8550),y)
EDEN_CPU_FLAGS = -mcpu=cortex-a715+nosve+nosve2
endif

ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_SM8X50),y)
EDEN_OPT_FLAGS += \
	-O3 \
	-DNDEBUG \
	-fno-semantic-interposition \
	-fomit-frame-pointer \
	-ffp-contract=fast \
	-flto=thin \
	$(EDEN_CPU_FLAGS)

EDEN_LINK_FLAGS += \
	-fuse-ld=lld \
	-flto=thin \
	-Wl,-O2 \
	-Wl,--as-needed

EDEN_INTERPROCEDURAL_OPTIMIZATION = ON

EDEN_SM8550_PROFDATA = $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/eden/eden-sm8550.profdata
ifneq ($(wildcard $(EDEN_SM8550_PROFDATA)),)
EDEN_OPT_FLAGS += -fprofile-use=$(EDEN_SM8550_PROFDATA)
endif
endif

EDEN_CONF_OPTS += \
	-DARCHITECTURE=arm64 \
	-DARCHITECTURE_arm64=ON \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_COMPILER=$(HOST_DIR)/bin/clang \
	-DCMAKE_CXX_COMPILER=$(HOST_DIR)/bin/clang++ \
	-DCMAKE_C_FLAGS="$(TARGET_CFLAGS) $(EDEN_OPT_FLAGS)" \
	-DCMAKE_CXX_FLAGS="$(TARGET_CXXFLAGS) $(EDEN_OPT_FLAGS)" \
	-DCMAKE_EXE_LINKER_FLAGS="$(EDEN_LINK_FLAGS)" \
	-DCMAKE_SHARED_LINKER_FLAGS="$(EDEN_LINK_FLAGS)" \
	-DCMAKE_CXX_STANDARD_LIBRARIES="-lstdc++ -lm -lpthread" \
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=$(EDEN_INTERPROCEDURAL_OPTIMIZATION) \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-DENABLE_CUBEB=OFF \
	-DENABLE_LIBUSB=ON \
	-DENABLE_QT=ON \
	-DENABLE_QT_TRANSLATION=OFF \
	-DENABLE_UPDATE_CHECKER=OFF \
	-DENABLE_WEB_SERVICE=OFF \
	-DENABLE_WIFI_SCAN=OFF \
	-DUSE_DISCORD_PRESENCE=OFF \
	-DUSE_FASTER_LINKER=OFF \
	-DYUZU_BUILD_PRESET=custom \
	-DYUZU_CMD=OFF \
	-DYUZU_CRASH_DUMPS=OFF \
	-DYUZU_DOWNLOAD_TIME_ZONE_DATA=ON \
	-DYUZU_INSTALL_UDEV_RULES=OFF \
	-DYUZU_LEGACY=OFF \
	-DYUZU_ROOM=OFF \
	-DYUZU_ROOM_STANDALONE=OFF \
	-DYUZU_STATIC_BUILD=OFF \
	-DYUZU_TESTS=OFF \
	-DYUZU_USE_BUNDLED_FFMPEG=OFF \
	-DYUZU_USE_BUNDLED_OPENSSL=OFF \
	-DYUZU_USE_BUNDLED_QT=OFF \
	-DYUZU_USE_BUNDLED_SDL3=OFF \
	-DYUZU_USE_BUNDLED_SIRIT=ON \
	-DYUZU_USE_EXTERNAL_FFMPEG=OFF \
	-DYUZU_USE_QT_MULTIMEDIA=OFF \
	-DYUZU_USE_QT_WEB_ENGINE=OFF \
	-DCPMUTIL_FORCE_BUNDLED=OFF \
	-DCPMUTIL_FORCE_SYSTEM=OFF \
	-DBoost_FORCE_SYSTEM=ON \
	-Denet_FORCE_SYSTEM=ON \
	-Dfmt_FORCE_SYSTEM=ON \
	-Dlibusb_FORCE_SYSTEM=ON \
	-Dlz4_FORCE_SYSTEM=ON \
	-Dnlohmann_json_FORCE_SYSTEM=ON \
	-DOpus_FORCE_SYSTEM=ON \
	-DQuaZip-Qt6_FORCE_SYSTEM=ON \
	-DSDL3_FORCE_SYSTEM=ON \
	-DSPIRV-Headers_FORCE_SYSTEM=ON \
	-DVulkanHeaders_FORCE_SYSTEM=ON \
	-DVulkanUtilityLibraries_FORCE_SYSTEM=ON \
	-DZLIB_FORCE_SYSTEM=ON \
	-Dzstd_FORCE_SYSTEM=ON

define EDEN_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/eden/native
	$(INSTALL) -m 0755 $(@D)/buildroot-build/bin/eden \
		$(TARGET_DIR)/usr/share/eden/native/eden

	mkdir -p $(TARGET_DIR)/usr/share/eden
	$(INSTALL) -m 0644 $(EDEN_DL_DIR)/$(EDEN_APPIMAGE_SOURCE) \
		$(TARGET_DIR)/usr/share/eden/eden.AppImage

	mkdir -p $(TARGET_DIR)/usr/bin
	$(INSTALL) -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/eden/eden \
		$(TARGET_DIR)/usr/bin/eden
	ln -sf ../share/eden/native/eden $(TARGET_DIR)/usr/bin/eden-native

	mkdir -p $(TARGET_DIR)/usr/share/evmapy
	cp -prn $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/eden/switch.eden.keys \
		$(TARGET_DIR)/usr/share/evmapy/
endef

$(eval $(cmake-package))

else

EDEN_VERSION = $(EDEN_APPIMAGE_VERSION)
EDEN_TOOLCHAIN = manual
EDEN_SITE = $(EDEN_APPIMAGE_SITE)
EDEN_SOURCE = $(EDEN_APPIMAGE_SOURCE)

define EDEN_EXTRACT_CMDS
	cp $(DL_DIR)/$(EDEN_DL_SUBDIR)/$(EDEN_SOURCE) \
		$(@D)/eden.AppImage
endef

define EDEN_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/eden
	$(INSTALL) -m 0644 $(@D)/eden.AppImage \
		$(TARGET_DIR)/usr/share/eden/eden.AppImage

	mkdir -p $(TARGET_DIR)/usr/bin
	$(INSTALL) -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/eden/eden \
		$(TARGET_DIR)/usr/bin/eden

	mkdir -p $(TARGET_DIR)/usr/share/evmapy
	cp -prn $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/eden/switch.eden.keys \
		$(TARGET_DIR)/usr/share/evmapy/
endef

$(eval $(generic-package))

endif
