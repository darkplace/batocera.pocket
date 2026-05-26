################################################################################
#
# batocera-usbgadget
#
################################################################################

BATOCERA_USBGADGET_VERSION = 1.0
BATOCERA_USBGADGET_LICENSE = GPL-2.0
BATOCERA_USBGADGET_SOURCE =
BATOCERA_USBGADGET_DEPENDENCIES = dnsmasq umtprd
BATOCERA_USBGADGET_PATH = $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-usbgadget

define BATOCERA_USBGADGET_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(BATOCERA_USBGADGET_PATH)/usbgadget \
		$(TARGET_DIR)/usr/bin/usbgadget
	$(INSTALL) -D -m 0755 $(BATOCERA_USBGADGET_PATH)/S20usbgadget \
		$(TARGET_DIR)/etc/init.d/S20usbgadget
	$(INSTALL) -D -m 0644 $(BATOCERA_USBGADGET_PATH)/80-usbgadget.rules \
		$(TARGET_DIR)/etc/udev/rules.d/80-usbgadget.rules
	$(INSTALL) -D -m 0644 $(BATOCERA_USBGADGET_PATH)/umtprd.conf \
		$(TARGET_DIR)/etc/umtprd/umtprd.conf
endef

$(eval $(generic-package))

