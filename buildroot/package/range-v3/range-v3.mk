################################################################################
#
# range-v3
#
################################################################################

RANGE_V3_VERSION = 0.12.0
RANGE_V3_SITE = $(call github,ericniebler,range-v3,$(RANGE_V3_VERSION))
RANGE_V3_LICENSE = BSL-1.0
RANGE_V3_LICENSE_FILES = LICENSE.txt
RANGE_V3_INSTALL_STAGING = YES
RANGE_V3_INSTALL_TARGET = NO

RANGE_V3_CONF_OPTS = \
	-DRANGES_NATIVE=OFF \
	-DRANGES_VERBOSE_BUILD=OFF \
	-DRANGE_V3_DOCS=OFF \
	-DRANGE_V3_EXAMPLES=OFF \
	-DRANGE_V3_HEADER_CHECKS=OFF \
	-DRANGE_V3_PERF=OFF \
	-DRANGE_V3_TESTS=OFF

$(eval $(cmake-package))
