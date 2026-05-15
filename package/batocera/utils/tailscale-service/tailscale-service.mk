################################################################################
#
# tailscale-service
#
################################################################################

TAILSCALE_SERVICE_VERSION = 0.0.1
TAILSCALE_SERVICE_SOURCE =
TAILSCALE_SERVICE_SITE =
TAILSCALE_SERVICE_DEPENDENCIES = tailscale

define TAILSCALE_SERVICE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/batocera/services
	$(INSTALL) -Dm755 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/tailscale-service/tailscale \
	    $(TARGET_DIR)/usr/share/batocera/services/
endef

$(eval $(generic-package))
