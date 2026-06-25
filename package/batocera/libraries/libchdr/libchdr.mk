################################################################################
#
# libchdr
#
################################################################################

LIBCHDR_VERSION = 074ff1614f2a685f2b5a95b0e788bff6297d5680
LIBCHDR_SITE = $(call github,devmiyax,libchdr,$(LIBCHDR_VERSION))
LIBCHDR_LICENSE = BSD-3-Clause
LIBCHDR_LICENSE_FILES = LICENSE.txt
LIBCHDR_INSTALL_STAGING = YES
LIBCHDR_INSTALL_TARGET = NO
LIBCHDR_SUPPORTS_IN_SOURCE_BUILD = NO

define LIBCHDR_INSTALL_STAGING_CMDS
	$(INSTALL) -D -m 0644 $(@D)/src/chd.h $(STAGING_DIR)/usr/include/libchdr/chd.h
	$(INSTALL) -D -m 0644 $(@D)/src/cdrom.h $(STAGING_DIR)/usr/include/libchdr/cdrom.h
	$(INSTALL) -D -m 0644 $(@D)/src/coretypes.h $(STAGING_DIR)/usr/include/libchdr/coretypes.h
	$(INSTALL) -D -m 0644 $(@D)/src/flac.h $(STAGING_DIR)/usr/include/libchdr/flac.h
	$(INSTALL) -D -m 0644 $(@D)/src/huffman.h $(STAGING_DIR)/usr/include/libchdr/huffman.h
	$(INSTALL) -D -m 0644 $(@D)/src/bitstream.h $(STAGING_DIR)/usr/include/libchdr/bitstream.h
	$(INSTALL) -D -m 0644 $(@D)/buildroot-build/libchdr-static.a $(STAGING_DIR)/usr/lib/libchdr-static.a
	$(INSTALL) -D -m 0644 $(@D)/buildroot-build/libcrypto-static.a $(STAGING_DIR)/usr/lib/libcrypto-static.a
	$(INSTALL) -D -m 0644 $(@D)/buildroot-build/libflac-static.a $(STAGING_DIR)/usr/lib/libflac-static.a
	$(INSTALL) -D -m 0644 $(@D)/buildroot-build/liblzma-static.a $(STAGING_DIR)/usr/lib/liblzma-static.a
endef

$(eval $(cmake-package))
