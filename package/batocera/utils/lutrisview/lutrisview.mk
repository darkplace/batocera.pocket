################################################################################
#
# lutrisview
#
################################################################################

LUTRISVIEW_VERSION = e3466f28710a2bea9c00eb779baedd32f4d31fa1
LUTRISVIEW_SITE = $(call github,redmie,lutrisview,$(LUTRISVIEW_VERSION))
LUTRISVIEW_LICENSE = MIT

define LUTRISVIEW_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/bin
	mkdir -p $(TARGET_DIR)/usr/share/applications
	mkdir -p $(TARGET_DIR)/usr/share/pixmaps
	$(INSTALL) -D -m 0755 $(@D)/lutrisview \
		$(TARGET_DIR)/usr/bin/lutrisview
	$(INSTALL) -D -m 0644 $(@D)/lutrisview.desktop \
		$(TARGET_DIR)/usr/share/applications/lutrisview.desktop
	$(INSTALL) -D -m 0644 $(@D)/lutrisview.svg \
		$(TARGET_DIR)/usr/share/pixmaps/lutrisview.svg
endef

$(eval $(generic-package))
