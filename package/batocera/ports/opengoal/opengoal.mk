################################################################################
#
# opengoal
#
################################################################################

OPENGOAL_VERSION = c4bc4d3ff4691902ff023319cb33df71c0040501
OPENGOAL_SITE = https://github.com/open-goal/jak-project.git
OPENGOAL_SITE_METHOD = git
OPENGOAL_GIT_SUBMODULES = YES
OPENGOAL_LICENSE = ISC
OPENGOAL_SUPPORTS_IN_SOURCE_BUILD = NO

ifeq ($(BR2_aarch64),y)

OPENGOAL_DEPENDENCIES += host-cmake host-nasm host-ninja host-openssl host-pkgconf host-zlib box64 alsa-lib pulseaudio
OPENGOAL_BIN_ARCH_EXCLUDE += /usr/lib/opengoal

OPENGOAL_HOST_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
OPENGOAL_HOST_CONF_OPTS += -DSTATICALLY_LINK=ON
OPENGOAL_HOST_CONF_OPTS += -DASAN_BUILD=OFF
OPENGOAL_HOST_CONF_OPTS += -DCODE_COVERAGE=OFF
OPENGOAL_HOST_CONF_OPTS += -DZYDIS_BUILD_SHARED_LIB=OFF
OPENGOAL_HOST_CONF_OPTS += -DINSTALL_GTEST=OFF
OPENGOAL_HOST_CONF_OPTS += -DCMAKE_C_FLAGS="-I$(@D)/host-audio-include"
OPENGOAL_HOST_CONF_OPTS += -DCMAKE_CXX_FLAGS="-I$(@D)/host-audio-include -msse4.2 -mno-avx -mno-avx2 -mno-avx512f"
OPENGOAL_HOST_CONF_OPTS += -DCMAKE_MAKE_PROGRAM=$(HOST_DIR)/bin/ninja
OPENGOAL_HOST_CONF_OPTS += -DCMAKE_PREFIX_PATH=$(HOST_DIR)
OPENGOAL_HOST_CONF_OPTS += -DOPENSSL_ROOT_DIR=$(HOST_DIR)
OPENGOAL_HOST_CONF_OPTS += -DZLIB_ROOT=$(HOST_DIR)
OPENGOAL_HOST_CONF_OPTS += -DSDL_AVX=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_AVX2=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_AVX512F=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_DBUS=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_FRIBIDI=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_KMSDRM=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_LIBTHAI=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_LIBUDEV=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_HIDAPI_LIBUSB=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_X11_XCURSOR=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_X11_XDBE=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_X11_XINPUT=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_X11_XFIXES=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_X11_XRANDR=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_X11_XSCRNSAVER=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_X11_XSHAPE=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_X11_XSYNC=OFF
OPENGOAL_HOST_CONF_OPTS += -DSDL_X11_XTEST=OFF

define OPENGOAL_CONFIGURE_CMDS
	rm -rf $(@D)/host-audio-include
	mkdir -p $(@D)/host-audio-include
	ln -sfn $(STAGING_DIR)/usr/include/pulse $(@D)/host-audio-include/pulse
	ln -sfn $(STAGING_DIR)/usr/include/alsa $(@D)/host-audio-include/alsa
	mkdir -p $(@D)/buildroot-build
	cd $(@D)/buildroot-build && \
		PATH="$(HOST_DIR)/bin:$$PATH" \
		PKG_CONFIG="/usr/bin/pkg-config" \
		PKG_CONFIG_LIBDIR="$(HOST_DIR)/lib/pkgconfig:$(HOST_DIR)/share/pkgconfig" \
		PKG_CONFIG_PATH="$(HOST_DIR)/lib/pkgconfig:$(HOST_DIR)/share/pkgconfig" \
		PKG_CONFIG_SYSROOT_DIR= \
		$(HOST_DIR)/bin/cmake $(@D) -G Ninja \
			-DCMAKE_C_COMPILER=/usr/bin/gcc \
			-DCMAKE_CXX_COMPILER=/usr/bin/g++ \
			$(OPENGOAL_HOST_CONF_OPTS)
endef

define OPENGOAL_BUILD_CMDS
	PATH="$(HOST_DIR)/bin:$$PATH" \
	$(HOST_DIR)/bin/cmake --build $(@D)/buildroot-build --parallel $(PARALLEL_JOBS) --target gk goalc extractor
endef

else

OPENGOAL_DEPENDENCIES += host-pkgconf openssl zlib

OPENGOAL_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
OPENGOAL_CONF_OPTS += -DSTATICALLY_LINK=ON
OPENGOAL_CONF_OPTS += -DASAN_BUILD=OFF
OPENGOAL_CONF_OPTS += -DCODE_COVERAGE=OFF
OPENGOAL_CONF_OPTS += -DZYDIS_BUILD_SHARED_LIB=OFF
OPENGOAL_CONF_OPTS += -DINSTALL_GTEST=OFF

endif

define OPENGOAL_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/opengoal/data
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/game/gk \
		$(TARGET_DIR)/usr/lib/opengoal/gk
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/goalc/goalc \
		$(TARGET_DIR)/usr/lib/opengoal/goalc
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/decompiler/extractor \
		$(TARGET_DIR)/usr/lib/opengoal/extractor
	cp -a $(@D)/goal_src $(@D)/custom_assets $(@D)/decompiler $(@D)/game \
		$(TARGET_DIR)/usr/lib/opengoal/data/
	$(INSTALL) -D -m 0755 $(OPENGOAL_PKGDIR)/opengoal-wrapper \
		$(TARGET_DIR)/usr/bin/opengoal
	$(INSTALL) -D -m 0644 $(OPENGOAL_PKGDIR)/_info.txt \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/opengoal/_info.txt
	$(INSTALL) -D -m 0644 $(OPENGOAL_PKGDIR)/gamelist.xml \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/opengoal/gamelist.xml
endef

ifeq ($(BR2_aarch64),y)
$(eval $(generic-package))
else
$(eval $(cmake-package))
endif
