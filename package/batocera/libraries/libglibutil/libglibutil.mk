################################################################################
#
# libglibutil
#
################################################################################

LIBGLIBUTIL_VERSION = 1.0.55
LIBGLIBUTIL_SITE = $(call github,waydroid,libglibutil,$(LIBGLIBUTIL_VERSION))
LIBGLIBUTIL_LICENSE = BSD-3-Clause
LIBGLIBUTIL_LICENSE_FILES = LICENSE
LIBGLIBUTIL_DEPENDENCIES = libglib2
LIBGLIBUTIL_INSTALL_STAGING = YES

define LIBGLIBUTIL_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE1) -C $(@D) release pkgconfig
endef

define LIBGLIBUTIL_INSTALL_STAGING_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE1) -C $(@D) \
		DESTDIR=$(STAGING_DIR) LIBDIR=usr/lib install install-dev
endef

define LIBGLIBUTIL_INSTALL_TARGET_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE1) -C $(@D) \
		DESTDIR=$(TARGET_DIR) LIBDIR=usr/lib install
endef

$(eval $(generic-package))
