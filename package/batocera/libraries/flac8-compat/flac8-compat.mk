################################################################################
#
# flac8-compat
#
################################################################################

FLAC8_COMPAT_VERSION = 1.3.4
FLAC8_COMPAT_SITE = https://downloads.xiph.org/releases/flac
FLAC8_COMPAT_SOURCE = flac-$(FLAC8_COMPAT_VERSION).tar.xz
FLAC8_COMPAT_LICENSE = Xiph BSD-like (libFLAC), GPL-2.0+ (tools), LGPL-2.1+ (other libraries)
FLAC8_COMPAT_LICENSE_FILES = COPYING.Xiph COPYING.GPL COPYING.LGPL

# Runtime compatibility package only: avoid polluting staging with old headers/pkg-config.
FLAC8_COMPAT_INSTALL_STAGING = NO
FLAC8_COMPAT_DEPENDENCIES = libogg

FLAC8_COMPAT_CONF_OPTS = \
	--disable-static \
	--enable-shared \
	--disable-doxygen-docs \
	--disable-thorough-tests \
	--disable-cpplibs \
	--disable-oggtest \
	--with-ogg=$(STAGING_DIR)/usr \
	--with-gnu-ld

define FLAC8_COMPAT_INSTALL_TARGET_CMDS
	FLAC_SO="$$(ls $(@D)/src/libFLAC/.libs/libFLAC.so.8.* | head -n1)"; \
	[ -n "$$FLAC_SO" ]; \
	$(INSTALL) -D -m 0755 "$$FLAC_SO" \
		$(TARGET_DIR)/usr/lib/$$(basename "$$FLAC_SO"); \
	ln -snf "$$(basename "$$FLAC_SO")" $(TARGET_DIR)/usr/lib/libFLAC.so.8
endef

$(eval $(autotools-package))

