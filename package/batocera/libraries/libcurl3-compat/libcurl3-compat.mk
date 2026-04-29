################################################################################
#
# libcurl3-compat
#
################################################################################

LIBCURL3_COMPAT_VERSION = 1.0
LIBCURL3_COMPAT_SOURCE =
LIBCURL3_COMPAT_LICENSE = MIT

# Runtime compatibility package only.
LIBCURL3_COMPAT_INSTALL_STAGING = NO
LIBCURL3_COMPAT_DEPENDENCIES = libcurl

define LIBCURL3_COMPAT_INSTALL_TARGET_CMDS
	if [ -e "$(TARGET_DIR)/usr/lib/libcurl.so.4" ]; then \
		ln -snf libcurl.so.4 "$(TARGET_DIR)/usr/lib/libcurl.so.3"; \
	fi
endef

$(eval $(generic-package))

