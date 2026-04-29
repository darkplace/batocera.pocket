################################################################################
#
# gamepadcalibration
#
################################################################################

GAMEPADCALIBRATION_VERSION = 2077e7af7e9a8c1df54af6f1959cb92daea03207
GAMEPADCALIBRATION_SITE = $(call github,cdeletre,GPcal,$(GAMEPADCALIBRATION_VERSION))
GAMEPADCALIBRATION_LICENSE = MIT
GAMEPADCALIBRATION_LICENSE_FILES = LICENSE
GAMEPADCALIBRATION_DEPENDENCIES = python3 python-pyxel

define GAMEPADCALIBRATION_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/gpcal
	cp -pr $(@D)/gpcal/gamedata/* $(TARGET_DIR)/usr/share/gpcal/
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/controllers/pads/gamepadcalibration/batocera-gamepad-calibrator \
		$(TARGET_DIR)/usr/bin/batocera-gamepad-calibrator
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/controllers/pads/gamepadcalibration/S32gamepadcalibration \
		$(TARGET_DIR)/etc/init.d/S32gamepadcalibration
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/controllers/pads/gamepadcalibration/datainit/roms/emulator/Gamepad_Calibration.sh \
		$(TARGET_DIR)/usr/share/gpcal/launcher/Gamepad_Calibration.sh
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/controllers/pads/gamepadcalibration/datainit/roms/emulator/images/gamepad-calibration.svg \
		$(TARGET_DIR)/usr/share/gpcal/launcher/images/gamepad-calibration.svg
endef

$(eval $(generic-package))
