################################################################################
#
# shadps4-fex
#
################################################################################

SHADPS4_FEX_VERSION = 1
SHADPS4_FEX_SOURCE =
SHADPS4_FEX_LICENSE = GPLv3
SHADPS4_FEX_DEPENDENCIES = fex-emu

SHADPS4_FEX_PAYLOAD_PATH = $(call qstrip,$(BR2_PACKAGE_SHADPS4_FEX_PAYLOAD_PATH))

define SHADPS4_FEX_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/shadps4-fex/shadps4-fex \
		$(TARGET_DIR)/usr/bin/shadps4-fex
	if [ ! -e "$(TARGET_DIR)/usr/bin/shadps4-x86_64" ] && [ ! -L "$(TARGET_DIR)/usr/bin/shadps4-x86_64" ]; then \
		mkdir -p "$(TARGET_DIR)/usr/bin/shadps4-x86_64"; \
	fi
	if [ -n "$(SHADPS4_FEX_PAYLOAD_PATH)" ] && [ -d "$(SHADPS4_FEX_PAYLOAD_PATH)" ]; then \
		cp -a "$(SHADPS4_FEX_PAYLOAD_PATH)/." "$(TARGET_DIR)/usr/bin/shadps4-x86_64/"; \
	elif [ -n "$(SHADPS4_FEX_PAYLOAD_PATH)" ]; then \
		echo "shadps4-fex: x86_64 payload not found at $(SHADPS4_FEX_PAYLOAD_PATH); installing launcher only"; \
	fi
	if [ -x "$(TARGET_DIR)/usr/bin/shadps4-x86_64/shadps4" ]; then \
		chmod 0755 "$(TARGET_DIR)/usr/bin/shadps4-x86_64/shadps4"; \
	fi
	if [ -x "$(TARGET_DIR)/usr/bin/shadps4-x86_64/shadps4-qtlauncher" ]; then \
		chmod 0755 "$(TARGET_DIR)/usr/bin/shadps4-x86_64/shadps4-qtlauncher"; \
	fi
	if [ -x "$(TARGET_DIR)/usr/bin/shadps4-x86_64/shadPS4QtLauncher" ]; then \
		chmod 0755 "$(TARGET_DIR)/usr/bin/shadps4-x86_64/shadPS4QtLauncher"; \
	fi
endef

define SHADPS4_FEX_INSTALL_COMMUNITY_PATCHES
	PATH="$(HOST_DIR)/bin:$(HOST_DIR)/sbin:$(PATH)" \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/shadps4/install-community-patches.sh \
		"$(TARGET_DIR)/usr/share/shadps4/patches/shadPS4"
endef

SHADPS4_FEX_POST_INSTALL_TARGET_HOOKS += SHADPS4_FEX_INSTALL_COMMUNITY_PATCHES

$(eval $(generic-package))
