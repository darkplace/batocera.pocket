################################################################################
#
# python-libvirt
#
################################################################################

PYTHON_LIBVIRT_VERSION = 7.10.0
PYTHON_LIBVIRT_SITE = $(call github,libvirt,libvirt-python,v$(PYTHON_LIBVIRT_VERSION))
PYTHON_LIBVIRT_SETUP_TYPE = setuptools
PYTHON_LIBVIRT_LICENSE = LGPL-2.1+
PYTHON_LIBVIRT_LICENSE_FILES = COPYING COPYING.LESSER
PYTHON_LIBVIRT_DEPENDENCIES = libvirt python3
PYTHON_LIBVIRT_ENV = \
	PKG_CONFIG_PATH="$(BUILD_DIR)/libvirt-$(LIBVIRT_VERSION)/build/src:$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig"

$(eval $(python-package))
