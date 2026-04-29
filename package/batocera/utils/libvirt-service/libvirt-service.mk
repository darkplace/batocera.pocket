################################################################################
#
# libvirt-service
#
################################################################################

LIBVIRT_SERVICE_VERSION = 1.0
LIBVIRT_SERVICE_SOURCE =
LIBVIRT_SERVICE_SITE =

LIBVIRT_SERVICE_DEPENDENCIES = libvirt

define LIBVIRT_SERVICE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/batocera/services
	$(INSTALL) -Dm755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/libvirt-service/libvirt \
		$(TARGET_DIR)/usr/share/batocera/services/libvirt
	$(INSTALL) -Dm644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/libvirt-service/default.xml \
		$(TARGET_DIR)/usr/share/batocera/libvirt/default.xml
	ln -snf /usr/sbin/dnsmasq $(TARGET_DIR)/dnsmasq
	ln -snf /usr/sbin/dnsmasq $(TARGET_DIR)/usr/bin/dnsmasq
endef

$(eval $(generic-package))
