################################################################################
#
# libpng12-compat
#
################################################################################

LIBPNG12_COMPAT_VERSION = 1.2.59
LIBPNG12_COMPAT_SITE = https://download.sourceforge.net/libpng
LIBPNG12_COMPAT_SOURCE = libpng-$(LIBPNG12_COMPAT_VERSION).tar.xz
LIBPNG12_COMPAT_LICENSE = libpng license
LIBPNG12_COMPAT_LICENSE_FILES = LICENSE

# Runtime compatibility package only: avoid staging old headers/pkg-config.
LIBPNG12_COMPAT_INSTALL_STAGING = NO
LIBPNG12_COMPAT_DEPENDENCIES = zlib

LIBPNG12_COMPAT_CONF_OPTS = \
	--disable-static \
	--enable-shared

define LIBPNG12_COMPAT_INSTALL_TARGET_CMDS
	PNG12_SO="$$(ls $(@D)/.libs/libpng12.so.0.* | head -n1)"; \
	[ -n "$${PNG12_SO}" ]; \
	$(INSTALL) -D -m 0755 "$${PNG12_SO}" \
		$(TARGET_DIR)/usr/lib/$$(basename "$${PNG12_SO}"); \
	ln -snf "$$(basename "$${PNG12_SO}")" $(TARGET_DIR)/usr/lib/libpng12.so.0
endef

$(eval $(autotools-package))

