################################################################################
#
# libgbinder
#
################################################################################

LIBGBINDER_VERSION = 1.1.44
LIBGBINDER_SITE = $(call github,mer-hybris,libgbinder,$(LIBGBINDER_VERSION))
LIBGBINDER_LICENSE = BSD-3-Clause
LIBGBINDER_LICENSE_FILES = LICENSE
LIBGBINDER_DEPENDENCIES = libglib2 libglibutil
LIBGBINDER_INSTALL_STAGING = YES

define LIBGBINDER_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE1) -C $(@D) release pkgconfig
endef

define LIBGBINDER_INSTALL_STAGING_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE1) -C $(@D) \
		DESTDIR=$(STAGING_DIR) LIBDIR=usr/lib install install-dev
endef

define LIBGBINDER_INSTALL_TARGET_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE1) -C $(@D) \
		DESTDIR=$(TARGET_DIR) LIBDIR=usr/lib install
endef

$(eval $(generic-package))
