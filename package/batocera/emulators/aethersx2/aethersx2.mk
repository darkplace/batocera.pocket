################################################################################
#
# aethersx2 (AppImage)
#
################################################################################

AETHERSX2_VERSION = 1.5
AETHERSX2_LICENSE =  Proprietary
AETHERSX2_LICENSE_FILES = LICENSE
AETHERSX2_STRIP = NO
AETHERSX2_TOOLCHAIN = manual

# Only supported on aarch64

AETHERSX2_SITE = https://github.com/droole36/testbench/releases/download/test
AETHERSX2_SOURCE = AetherSX2.AppImage


################################################################################
# Extract
################################################################################

define AETHERSX2_EXTRACT_CMDS
	cp $(DL_DIR)/$(AETHERSX2_DL_SUBDIR)/$(AETHERSX2_SOURCE) \
		$(@D)/aethersx2.AppImage
endef

################################################################################
# Install
################################################################################

define AETHERSX2_INSTALL_TARGET_CMDS
	# Install AppImage to non-ELF-scanned location
	mkdir -p $(TARGET_DIR)/usr/share/aethersx2
	cp $(@D)/aethersx2.AppImage \
		$(TARGET_DIR)/usr/share/aethersx2/aethersx2.AppImage

	# Wrapper (exec-time chmod avoids fix-rpath)
	mkdir -p $(TARGET_DIR)/usr/bin
	printf '%s\n' \
		'#!/bin/sh' \
		'chmod +x /usr/share/aethersx2/aethersx2.AppImage 2>/dev/null' \
		'exec /usr/share/aethersx2/aethersx2.AppImage "$$@"' \
		> $(TARGET_DIR)/usr/bin/aethersx2
	chmod 0755 $(TARGET_DIR)/usr/bin/aethersx2
endef

$(eval $(generic-package))
