################################################################################
#
# citron (AppImage)
#
################################################################################

CITRON_VERSION = 0.10.0
CITRON_LICENSE = GPL-2.0
CITRON_STRIP = NO
CITRON_TOOLCHAIN = manual

# Only supported on aarch64
CITRON_SITE = https://github.com/pkgforge-dev/Citron-AppImage/releases/download/0.10.0%402025-11-03_1762140509
CITRON_SOURCE = Citron-0.10.0-anylinux-aarch64.AppImage

################################################################################
# Extract
################################################################################

define CITRON_EXTRACT_CMDS
	cp $(DL_DIR)/$(CITRON_DL_SUBDIR)/$(CITRON_SOURCE) \
		$(@D)/citron.AppImage
endef

################################################################################
# Install
################################################################################

define CITRON_INSTALL_TARGET_CMDS
	# Install AppImage to non-ELF-scanned location
	mkdir -p $(TARGET_DIR)/usr/share/citron
	cp $(@D)/citron.AppImage \
		$(TARGET_DIR)/usr/share/citron/citron.AppImage

	# Wrapper (exec-time chmod avoids fix-rpath)
	mkdir -p $(TARGET_DIR)/usr/bin
	printf '%s\n' \
		'#!/bin/sh' \
		'chmod +x /usr/share/citron/citron.AppImage 2>/dev/null' \
		'exec /usr/share/citron/citron.AppImage "$$@"' \
		> $(TARGET_DIR)/usr/bin/citron
	chmod 0755 $(TARGET_DIR)/usr/bin/citron
endef

$(eval $(generic-package))
