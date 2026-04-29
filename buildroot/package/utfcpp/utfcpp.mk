################################################################################
#
# utfcpp
#
################################################################################

UTFCPP_VERSION = 4.0.6
UTFCPP_SITE = $(call github,nemtrif,utfcpp,v$(UTFCPP_VERSION))
UTFCPP_LICENSE = BSL-1.0
UTFCPP_LICENSE_FILES = LICENSE
UTFCPP_INSTALL_STAGING = YES
UTFCPP_INSTALL_TARGET = NO

$(eval $(cmake-package))
