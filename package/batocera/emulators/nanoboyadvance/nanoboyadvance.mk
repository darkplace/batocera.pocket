################################################################################
#
# nanoboyadvance
#
################################################################################

NANOBOYADVANCE_VERSION = 3bb6f478f977dbfd3106508536e5fbce90d1898b
NANOBOYADVANCE_SITE = https://github.com/nba-emu/NanoBoyAdvance.git
NANOBOYADVANCE_SITE_METHOD = git
NANOBOYADVANCE_GIT_SUBMODULES = YES
NANOBOYADVANCE_LICENSE = GPL-3.0+
NANOBOYADVANCE_LICENSE_FILES = LICENSE
NANOBOYADVANCE_DEPENDENCIES = sdl2 libglew libglu
NANOBOYADVANCE_SUPPORTS_IN_SOURCE_BUILD = NO

NANOBOYADVANCE_CONF_OPTS = -DPLATFORM_SDL2=ON
NANOBOYADVANCE_CONF_OPTS += -DPLATFORM_QT=OFF
NANOBOYADVANCE_CONF_OPTS += -DCMAKE_POLICY_VERSION_MINIMUM=3.5

define NANOBOYADVANCE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/bin/sdl/NanoBoyAdvance \
		$(TARGET_DIR)/usr/bin/NanoBoyAdvance
	if test -e $(@D)/buildroot-build/external/unarr/libunarr.so.1; then \
		$(INSTALL) -D -m 0755 $(@D)/buildroot-build/external/unarr/libunarr.so.1 \
			$(TARGET_DIR)/usr/lib/libunarr.so.1; \
	fi
	if test -e $(@D)/buildroot-build/external/fmtlib/libfmt.so.6; then \
		$(INSTALL) -D -m 0755 $(@D)/buildroot-build/external/fmtlib/libfmt.so.6 \
			$(TARGET_DIR)/usr/lib/libfmt.so.6; \
	fi
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/nanoboyadvance/config.toml \
		$(TARGET_DIR)/usr/share/nanoboyadvance/config.toml
	$(INSTALL) -D -m 0644 $(@D)/src/platform/sdl/resource/keymap.toml \
		$(TARGET_DIR)/usr/share/nanoboyadvance/keymap.toml
endef

$(eval $(cmake-package))
