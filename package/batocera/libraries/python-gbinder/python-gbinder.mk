################################################################################
#
# python-gbinder
#
################################################################################

PYTHON_GBINDER_VERSION = 1.3.1
PYTHON_GBINDER_SITE = $(call github,waydroid,gbinder-python,$(PYTHON_GBINDER_VERSION))
PYTHON_GBINDER_SETUP_TYPE = setuptools
PYTHON_GBINDER_LICENSE = GPL-3.0-or-later
PYTHON_GBINDER_LICENSE_FILES = LICENSE
PYTHON_GBINDER_DEPENDENCIES = host-python-cython libgbinder python3

$(eval $(python-package))
