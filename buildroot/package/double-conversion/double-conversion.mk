################################################################################
#
# double-conversion
#
################################################################################

DOUBLE_CONVERSION_VERSION = 3.3.0
DOUBLE_CONVERSION_SITE = $(call github,google,double-conversion,v$(DOUBLE_CONVERSION_VERSION))
DOUBLE_CONVERSION_LICENSE = BSD-3-Clause
DOUBLE_CONVERSION_LICENSE_FILES = COPYING
DOUBLE_CONVERSION_INSTALL_STAGING = YES
DOUBLE_CONVERSION_CONF_OPTS = -DCMAKE_POLICY_VERSION_MINIMUM=3.5
HOST_DOUBLE_CONVERSION_CONF_OPTS = -DCMAKE_POLICY_VERSION_MINIMUM=3.5

$(eval $(cmake-package))
$(eval $(host-cmake-package))
