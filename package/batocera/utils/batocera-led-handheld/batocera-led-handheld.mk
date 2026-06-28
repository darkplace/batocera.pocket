################################################################################
#
# batocera-led-handheld
#
################################################################################

BATOCERA_LED_HANDHELD_VERSION = 0.9
BATOCERA_LED_HANDHELD_LICENSE = LGPL
BATOCERA_LED_HANDHELD_SOURCE=

BATOCERA_LED_HANDHELD_PATH = \
    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-led-handheld

define BATOCERA_LED_HANDHELD_INSTALL_TARGET_CMDS
    mkdir -p $(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)
    mkdir -p $(TARGET_DIR)/usr/bin
    mkdir -p $(TARGET_DIR)/etc/init.d
    mkdir -p $(TARGET_DIR)/usr/share/batocera-led-handheld/scripts
    install -m 0755 $(BATOCERA_LED_HANDHELD_PATH)/batoled.py \
        $(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/
    install -m 0755 $(BATOCERA_LED_HANDHELD_PATH)/batocera-led-handheld.py \
        $(TARGET_DIR)/usr/bin/batocera-led-handheld
    install -m 0755 $(BATOCERA_LED_HANDHELD_PATH)/S51led-handheld \
        $(TARGET_DIR)/etc/init.d/
    install -m 0755 $(BATOCERA_LED_HANDHELD_PATH)/achievements.sh \
        $(TARGET_DIR)/usr/share/batocera-led-handheld/scripts/achievements.sh
endef

$(eval $(generic-package))
