################################################################################
#
# batocera-distrobox
#
################################################################################

BATOCERA_DISTROBOX_VERSION = 1.8.2.4
BATOCERA_DISTROBOX_SITE = $(call github,89luca89,distrobox,$(BATOCERA_DISTROBOX_VERSION))
BATOCERA_DISTROBOX_LICENSE = GPL-3.0-only
BATOCERA_DISTROBOX_LICENSE_FILES = COPYING.md

BATOCERA_DISTROBOX_SCRIPTS = \
	distrobox \
	distrobox-assemble \
	distrobox-create \
	distrobox-enter \
	distrobox-ephemeral \
	distrobox-export \
	distrobox-generate-entry \
	distrobox-host-exec \
	distrobox-init \
	distrobox-list \
	distrobox-rm \
	distrobox-stop \
	distrobox-upgrade

define BATOCERA_DISTROBOX_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/usr/bin
	for f in $(BATOCERA_DISTROBOX_SCRIPTS); do \
		$(INSTALL) -m 0755 $(@D)/$$f $(TARGET_DIR)/usr/bin/$$f; \
	done
	if [ ! -e $(TARGET_DIR)/usr/bin/getent ]; then \
		$(INSTALL) -m 0755 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-distrobox/getent \
			$(TARGET_DIR)/usr/bin/getent; \
	fi
endef

$(eval $(generic-package))
