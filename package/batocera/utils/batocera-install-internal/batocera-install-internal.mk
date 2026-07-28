################################################################################
#
# batocera-install-internal
#
################################################################################

BATOCERA_INSTALL_INTERNAL_VERSION = 1.0
BATOCERA_INSTALL_INTERNAL_LICENSE = GPL
BATOCERA_INSTALL_INTERNAL_SOURCE =
BATOCERA_INSTALL_INTERNAL_DEPENDENCIES = \
	bash \
	batocera-scripts \
	dialog \
	dosfstools \
	e2fsprogs \
	parted \
	xterm

BATOCERA_INSTALL_INTERNAL_PATH = \
	$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-install-internal

define BATOCERA_INSTALL_INTERNAL_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 \
		$(BATOCERA_INSTALL_INTERNAL_PATH)/scripts/batocera-install-internal \
		$(TARGET_DIR)/usr/bin/batocera-install-internal
	$(INSTALL) -D -m 0755 \
		$(BATOCERA_INSTALL_INTERNAL_PATH)/scripts/batocera-install-internal-launcher \
		$(TARGET_DIR)/usr/bin/batocera-install-internal-launcher
endef

$(eval $(generic-package))
