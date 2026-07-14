################################################################################
#
# sunshine
#
################################################################################

SUNSHINE_VERSION = v2026.713.170739
SUNSHINE_SITE = https://github.com/LizardByte/Sunshine.git
SUNSHINE_SITE_METHOD = git
SUNSHINE_LICENSE = GPL-3.0
SUNSHINE_LICENSE_FILES = LICENSE
SUNSHINE_SUPPORTS_IN_SOURCE_BUILD = NO
SUNSHINE_PROJECT_VERSION = $(patsubst v%,%,$(SUNSHINE_VERSION))

SUNSHINE_FFMPEG_VERSION = v2026.713.132551
SUNSHINE_FFMPEG_ARCHIVE = Linux-aarch64-ffmpeg.tar.gz

SUNSHINE_SIMPLE_WEB_SERVER_VERSION = 546895a93a29062bb178367b46c7afb72da9881e
SUNSHINE_GLAD_VERSION = 73db193f853e2ee079bf3ca8a64aa2eaf6459043
SUNSHINE_INPUTTINO_VERSION = b887f6a37a4f6babea66ee7b9a79bc8f520d7554
SUNSHINE_LIBDISPLAYDEVICE_VERSION = 6e9722f89103320c948dc1199066c9e17a69e88a
SUNSHINE_LIZARDBYTE_COMMON_VERSION = 06cd442b808f02f1674f3192a84d25b9a503c482
SUNSHINE_MOONLIGHT_COMMON_C_VERSION = 82e25148549d249a80aaf4afc68e2abb07072edf
SUNSHINE_MOONLIGHT_COMMON_C_ENET_VERSION = 0eb84dcca830dcee950a12a48f63062d950d03d0
SUNSHINE_NANORS_VERSION = 17fc7d61afb2fdd9a9aff38fbd7d4f2ff73a4508
SUNSHINE_NV_CODEC_HEADERS_VERSION = 33a9ede8d9914299d9262539c576a15bd0a19621
SUNSHINE_PLASMA_WAYLAND_PROTOCOLS_VERSION = 4c015e90ae6c88f2ffa766e899387ef431eade49
SUNSHINE_WAYLAND_PROTOCOLS_VERSION = ee78491a237eaff9389a0ccf8680521d074407d3
SUNSHINE_WLR_PROTOCOLS_VERSION = bf4fc79abc359eea5a0edec0ac6d4a2b2955f82a

SUNSHINE_EXTRA_DOWNLOADS = \
	https://github.com/LizardByte/build-deps/releases/download/$(SUNSHINE_FFMPEG_VERSION)/$(SUNSHINE_FFMPEG_ARCHIVE) \
	https://github.com/LizardByte-infrastructure/Simple-Web-Server/archive/$(SUNSHINE_SIMPLE_WEB_SERVER_VERSION)/Simple-Web-Server-$(SUNSHINE_SIMPLE_WEB_SERVER_VERSION).tar.gz \
	https://github.com/Dav1dde/glad/archive/$(SUNSHINE_GLAD_VERSION)/glad-$(SUNSHINE_GLAD_VERSION).tar.gz \
	https://github.com/games-on-whales/inputtino/archive/$(SUNSHINE_INPUTTINO_VERSION)/inputtino-$(SUNSHINE_INPUTTINO_VERSION).tar.gz \
	https://github.com/LizardByte/libdisplaydevice/archive/$(SUNSHINE_LIBDISPLAYDEVICE_VERSION)/libdisplaydevice-$(SUNSHINE_LIBDISPLAYDEVICE_VERSION).tar.gz \
	https://github.com/LizardByte/lizardbyte-common/archive/$(SUNSHINE_LIZARDBYTE_COMMON_VERSION)/lizardbyte-common-$(SUNSHINE_LIZARDBYTE_COMMON_VERSION).tar.gz \
	https://github.com/moonlight-stream/moonlight-common-c/archive/$(SUNSHINE_MOONLIGHT_COMMON_C_VERSION)/moonlight-common-c-$(SUNSHINE_MOONLIGHT_COMMON_C_VERSION).tar.gz \
	https://github.com/cgutman/enet/archive/$(SUNSHINE_MOONLIGHT_COMMON_C_ENET_VERSION)/enet-$(SUNSHINE_MOONLIGHT_COMMON_C_ENET_VERSION).tar.gz \
	https://github.com/sleepybishop/nanors/archive/$(SUNSHINE_NANORS_VERSION)/nanors-$(SUNSHINE_NANORS_VERSION).tar.gz \
	https://github.com/FFmpeg/nv-codec-headers/archive/$(SUNSHINE_NV_CODEC_HEADERS_VERSION)/nv-codec-headers-$(SUNSHINE_NV_CODEC_HEADERS_VERSION).tar.gz \
	https://github.com/KDE/plasma-wayland-protocols/archive/$(SUNSHINE_PLASMA_WAYLAND_PROTOCOLS_VERSION)/plasma-wayland-protocols-$(SUNSHINE_PLASMA_WAYLAND_PROTOCOLS_VERSION).tar.gz \
	https://github.com/LizardByte-infrastructure/wayland-protocols/archive/$(SUNSHINE_WAYLAND_PROTOCOLS_VERSION)/wayland-protocols-$(SUNSHINE_WAYLAND_PROTOCOLS_VERSION).tar.gz \
	https://github.com/LizardByte-infrastructure/wlr-protocols/archive/$(SUNSHINE_WLR_PROTOCOLS_VERSION)/wlr-protocols-$(SUNSHINE_WLR_PROTOCOLS_VERSION).tar.gz

SUNSHINE_DEPENDENCIES = \
	host-glslang \
	host-nodejs \
	host-pkgconf \
	host-python-jinja2 \
	host-python-setuptools \
	boost \
	ffmpeg \
	json-for-modern-cpp \
	libcap \
	libcurl \
	libdrm \
	libevdev \
	libgbm \
	libva \
	libminiupnpc \
	numactl \
	openssl \
	opus \
	pipewire \
	pulseaudio \
	vulkan-headers \
	vulkan-loader \
	wayland \
	wayland-protocols \
	xdg-desktop-portal \
	xdg-desktop-portal-wlr

SUNSHINE_CONF_ENV += \
	BRANCH=master \
	BUILD_VERSION=$(SUNSHINE_PROJECT_VERSION) \
	COMMIT=$(SUNSHINE_VERSION) \
	npm_config_cache=$(@D)/.npm-cache \
	npm_config_loglevel=warn

SUNSHINE_MAKE_ENV += \
	npm_config_cache=$(@D)/.npm-cache \
	npm_config_loglevel=warn

SUNSHINE_CONF_OPTS += \
	-DBOOST_USE_STATIC=OFF \
	-DBUILD_DOCS=OFF \
	-DBUILD_TESTS=OFF \
	-DBUILD_WERROR=OFF \
	-DFFMPEG_PREPARED_BINARIES=$(@D)/batocera-ffmpeg/ffmpeg \
	-DGLAD_SKIP_PIP_INSTALL=ON \
	-DNPM_OFFLINE=OFF \
	-DOPUS_USE_STATIC=OFF \
	-DPython_EXECUTABLE=$(HOST_DIR)/bin/python3 \
	-DSUNSHINE_ASSETS_DIR=share/sunshine \
	-DSUNSHINE_ENABLE_CUDA=OFF \
	-DSUNSHINE_ENABLE_DRM=ON \
	-DSUNSHINE_ENABLE_KWIN=OFF \
	-DSUNSHINE_ENABLE_PORTAL=ON \
	-DSUNSHINE_ENABLE_TRAY=OFF \
	-DSUNSHINE_ENABLE_VAAPI=OFF \
	-DSUNSHINE_ENABLE_VULKAN=ON \
	-DSUNSHINE_ENABLE_WAYLAND=ON \
	-DSUNSHINE_ENABLE_X11=OFF \
	-DSUNSHINE_EXECUTABLE_PATH=/usr/bin/sunshine \
	-DSUNSHINE_PUBLISHER_NAME=Batocera \
	-DSUNSHINE_PUBLISHER_WEBSITE=https://batocera.org \
	-DSUNSHINE_SYSTEM_WAYLAND_PROTOCOLS=OFF \
	-DSUNSHINE_SYSTEM_VULKAN_HEADERS=ON

ifeq ($(BR2_TOOLCHAIN_HAS_LIBQUADMATH),y)
SUNSHINE_CONF_OPTS += -DEXTRA_LIBS=quadmath
endif

define SUNSHINE_EXTRACT_SUBMODULE
	mkdir -p $(@D)/$(2)
	tar -xzf $(DL_DIR)/$(SUNSHINE_DL_SUBDIR)/$(1) \
		--strip-components=1 -C $(@D)/$(2)
endef

define SUNSHINE_EXTRACT_SUBMODULES
	$(call SUNSHINE_EXTRACT_SUBMODULE,Simple-Web-Server-$(SUNSHINE_SIMPLE_WEB_SERVER_VERSION).tar.gz,third-party/Simple-Web-Server)
	$(call SUNSHINE_EXTRACT_SUBMODULE,glad-$(SUNSHINE_GLAD_VERSION).tar.gz,third-party/glad)
	$(call SUNSHINE_EXTRACT_SUBMODULE,inputtino-$(SUNSHINE_INPUTTINO_VERSION).tar.gz,third-party/inputtino)
	$(call SUNSHINE_EXTRACT_SUBMODULE,libdisplaydevice-$(SUNSHINE_LIBDISPLAYDEVICE_VERSION).tar.gz,third-party/libdisplaydevice)
	$(call SUNSHINE_EXTRACT_SUBMODULE,lizardbyte-common-$(SUNSHINE_LIZARDBYTE_COMMON_VERSION).tar.gz,third-party/lizardbyte-common)
	$(call SUNSHINE_EXTRACT_SUBMODULE,moonlight-common-c-$(SUNSHINE_MOONLIGHT_COMMON_C_VERSION).tar.gz,third-party/moonlight-common-c)
	$(call SUNSHINE_EXTRACT_SUBMODULE,enet-$(SUNSHINE_MOONLIGHT_COMMON_C_ENET_VERSION).tar.gz,third-party/moonlight-common-c/enet)
	$(call SUNSHINE_EXTRACT_SUBMODULE,nanors-$(SUNSHINE_NANORS_VERSION).tar.gz,third-party/moonlight-common-c/nanors)
	$(call SUNSHINE_EXTRACT_SUBMODULE,nv-codec-headers-$(SUNSHINE_NV_CODEC_HEADERS_VERSION).tar.gz,third-party/nv-codec-headers)
	$(call SUNSHINE_EXTRACT_SUBMODULE,plasma-wayland-protocols-$(SUNSHINE_PLASMA_WAYLAND_PROTOCOLS_VERSION).tar.gz,third-party/plasma-wayland-protocols)
	$(call SUNSHINE_EXTRACT_SUBMODULE,wayland-protocols-$(SUNSHINE_WAYLAND_PROTOCOLS_VERSION).tar.gz,third-party/wayland-protocols)
	$(call SUNSHINE_EXTRACT_SUBMODULE,wlr-protocols-$(SUNSHINE_WLR_PROTOCOLS_VERSION).tar.gz,third-party/wlr-protocols)
endef
SUNSHINE_POST_EXTRACT_HOOKS += SUNSHINE_EXTRACT_SUBMODULES

define SUNSHINE_EXTRACT_FFMPEG
	mkdir -p $(@D)/batocera-ffmpeg
	tar -xzf $(DL_DIR)/$(SUNSHINE_DL_SUBDIR)/$(SUNSHINE_FFMPEG_ARCHIVE) \
		-C $(@D)/batocera-ffmpeg
endef
SUNSHINE_PRE_CONFIGURE_HOOKS += SUNSHINE_EXTRACT_FFMPEG

define SUNSHINE_INSTALL_BATOCERA_FILES
	$(INSTALL) -D -m 0755 \
		$(@D)/buildroot-build/libglad_egl.so \
		$(TARGET_DIR)/usr/lib/libglad_egl.so
	$(INSTALL) -D -m 0755 \
		$(@D)/buildroot-build/libglad_gl.so \
		$(TARGET_DIR)/usr/lib/libglad_gl.so
	$(INSTALL) -D -m 0755 \
		$(@D)/buildroot-build/third-party/libdisplaydevice/src/common/liblibdisplaydevice_common.so \
		$(TARGET_DIR)/usr/lib/liblibdisplaydevice_common.so
	$(INSTALL) -D -m 0755 \
		$(@D)/buildroot-build/third-party/inputtino/liblibinputtino.so.0.1 \
		$(TARGET_DIR)/usr/lib/liblibinputtino.so.0.1
	ln -sf liblibinputtino.so.0.1 $(TARGET_DIR)/usr/lib/liblibinputtino.so
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/sunshine/batocera-sunshine \
		$(TARGET_DIR)/usr/bin/batocera-sunshine
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/sunshine/sunshine \
		$(TARGET_DIR)/usr/share/batocera/services/sunshine
endef
SUNSHINE_POST_INSTALL_TARGET_HOOKS += SUNSHINE_INSTALL_BATOCERA_FILES

$(eval $(cmake-package))
