################################################################################
#
# aethersx2
#
################################################################################

AETHERSX2_VERSION = 1.0.0
AETHERSX2_SITE = https://github.com/ROCKNIX/packages/raw/refs/heads/main
AETHERSX2_SOURCE = aethersx2.tar.gz
AETHERSX2_LICENSE = Proprietary
AETHERSX2_STRIP = NO
AETHERSX2_TOOLCHAIN = manual

AETHERSX2_DEPENDENCIES = qt6base sdl2 libaio libcurl libpcap libpng xz zlib

define AETHERSX2_CONFIGURE_CMDS
	true
endef

define AETHERSX2_BUILD_CMDS
	true
endef

define AETHERSX2_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/aethersx2
	cp -pr $(@D)/usr/share/* $(TARGET_DIR)/usr/share/aethersx2/
	chmod 0755 $(TARGET_DIR)/usr/share/aethersx2/aethersx2

	mkdir -p $(TARGET_DIR)/usr/share/aethersx2/lib
	if [ -e "$(TARGET_DIR)/usr/lib/libpcap.so.1" ]; then \
		ln -snf /usr/lib/libpcap.so.1 \
			$(TARGET_DIR)/usr/share/aethersx2/lib/libpcap.so.0.8; \
	else \
		libpcap="$$(find $(TARGET_DIR)/usr/lib -name 'libpcap.so.1*' | head -n 1)"; \
		if [ -n "$${libpcap}" ]; then \
			ln -snf "$${libpcap#$(TARGET_DIR)}" \
				$(TARGET_DIR)/usr/share/aethersx2/lib/libpcap.so.0.8; \
		fi; \
	fi
	if [ ! -e "$(TARGET_DIR)/usr/lib/libGLX.so.0" ] && [ -e "$(TARGET_DIR)/usr/lib/libmali.so.1" ]; then \
		ln -snf /usr/lib/libmali.so.1 \
			$(TARGET_DIR)/usr/share/aethersx2/lib/libGLX.so.0; \
	fi

	mkdir -p $(TARGET_DIR)/usr/bin
	printf '%s\n' \
		'#!/bin/sh' \
		'AETHERSX2_DIR=/usr/share/aethersx2' \
		'export QT_PLUGIN_PATH="$${QT_PLUGIN_PATH:-/usr/lib/qt6/plugins:/usr/lib64/qt6/plugins:/usr/lib/qt/plugins}"' \
		'export QT_QPA_PLATFORM_PLUGIN_PATH="$${QT_QPA_PLATFORM_PLUGIN_PATH:-/usr/lib/qt6/plugins/platforms:/usr/lib64/qt6/plugins/platforms:/usr/lib/qt/plugins/platforms}"' \
		'export QT_QPA_PLATFORM_PLUGINS_PATH="$${QT_QPA_PLATFORM_PLUGINS_PATH:-$${QT_QPA_PLATFORM_PLUGIN_PATH}}"' \
		'export QT_QPA_PLATFORM="$${QT_QPA_PLATFORM:-wayland}"' \
		'export LD_LIBRARY_PATH="$${AETHERSX2_DIR}/lib$${LD_LIBRARY_PATH:+:$${LD_LIBRARY_PATH}}"' \
		'exec "$${AETHERSX2_DIR}/aethersx2" "$$@"' \
		> $(TARGET_DIR)/usr/bin/aethersx2
	chmod 0755 $(TARGET_DIR)/usr/bin/aethersx2

	mkdir -p $(TARGET_DIR)/usr/share/evmapy
	$(INSTALL) -D -m 0644 $(AETHERSX2_PKGDIR)/ps2.aethersx2.keys \
		$(TARGET_DIR)/usr/share/evmapy/ps2.aethersx2.keys

	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/bios/ps2
	wget -O \
		$(TARGET_DIR)/usr/share/batocera/datainit/bios/ps2/patches.zip \
		https://github.com/PCSX2/pcsx2_patches/releases/download/latest/patches.zip
endef

$(eval $(generic-package))
