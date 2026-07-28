################################################################################
#
# batocera-es-system
#
################################################################################

BATOCERA_ES_SYSTEM_VERSION=1.04a
BATOCERA_ES_SYSTEM_SOURCE=

BATOCERA_ES_SYSTEM_DEPENDENCIES = host-python3 host-python-pyyaml batocera-configgen host-gettext

BATOCERA_ES_SYSTEM_LOCALES_DIR=$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/locales

ifeq ($(BR2_PACKAGE_BATOCERA_WINE),y)
BATOCERA_ES_SYSTEM_DEPENDENCIES += batocera-wine

define BATOCERA_ES_SYSTEM_INSTALL_WINE_TOOLS
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-wine/datainit/roms/emulator/Wine_Tools.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Wine_Tools.sh
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-wine/datainit/roms/emulator/Wine_Tools.sh.keys \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Wine_Tools.sh.keys
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/wine-tools.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/images/wine-tools.png
	gamelist="$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/gamelist.xml"; \
	if [ -f "$${gamelist}" ] && ! grep -q './Wine_Tools.sh' "$${gamelist}"; then \
		awk '/<\/gameList>/ { \
			print "  <game>"; \
			print "    <path>./Wine_Tools.sh</path>"; \
			print "    <name>Wine Tools</name>"; \
			print "    <image>./images/wine-tools.png</image>"; \
			print "  </game>"; \
		} { print }' "$${gamelist}" > "$${gamelist}.tmp" && \
		mv "$${gamelist}.tmp" "$${gamelist}"; \
	fi
endef
endif

ifneq ($(filter y,$(BR2_PACKAGE_BATOCERA_STEAM) $(BR2_PACKAGE_BATOCERA_STEAM_AARCH64)),)
define BATOCERA_ES_SYSTEM_INSTALL_STEAM_TOOLS
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/datainit/roms/emulator/Steam_Tools.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Steam_Tools.sh
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/datainit/roms/emulator/Steam_Tools.sh.keys \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Steam_Tools.sh.keys
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/steam.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/images/steam.png
	gamelist="$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/gamelist.xml"; \
	if [ -f "$${gamelist}" ] && ! grep -q './Steam_Tools.sh' "$${gamelist}"; then \
		awk '/<\/gameList>/ { \
			print "  <game>"; \
			print "    <path>./Steam_Tools.sh</path>"; \
			print "    <name>Steam Tools</name>"; \
			print "    <image>./images/steam.png</image>"; \
			print "  </game>"; \
		} { print }' "$${gamelist}" > "$${gamelist}.tmp" && \
		mv "$${gamelist}.tmp" "$${gamelist}"; \
	fi
endef
endif

ifeq ($(BR2_PACKAGE_GAMEPADCALIBRATION),y)
define BATOCERA_ES_SYSTEM_INSTALL_GAMEPAD_CALIBRATION_TOOL
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/controllers/pads/gamepadcalibration/datainit/roms/emulator/Gamepad_Calibration.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Gamepad_Calibration.sh
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/controllers/pads/gamepadcalibration/datainit/roms/emulator/images/gamepad-calibration.svg \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/images/gamepad-calibration.svg
	gamelist="$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/gamelist.xml"; \
	if [ -f "$${gamelist}" ] && ! grep -q './Gamepad_Calibration.sh' "$${gamelist}"; then \
		awk '/<\/gameList>/ { \
			print "  <game>"; \
			print "    <path>./Gamepad_Calibration.sh</path>"; \
			print "    <name>Gamepad Calibration</name>"; \
			print "    <image>./images/gamepad-calibration.svg</image>"; \
			print "  </game>"; \
		} { print }' "$${gamelist}" > "$${gamelist}.tmp" && \
		mv "$${gamelist}.tmp" "$${gamelist}"; \
	fi
endef
endif

ifeq ($(BR2_PACKAGE_BATOCERA_QCOM_MOTION),y)
define BATOCERA_ES_SYSTEM_INSTALL_MOTION_SENSOR_CALIBRATION_TOOL
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-qcom-motion/src/Motion_Sensor_Calibration.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Motion_Sensor_Calibration.sh
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-qcom-motion/src/motion-sensor-calibration.svg \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/images/motion-sensor-calibration.svg
	gamelist="$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/gamelist.xml"; \
	if [ -f "$${gamelist}" ] && ! grep -q './Motion_Sensor_Calibration.sh' "$${gamelist}"; then \
		awk '/<\/gameList>/ { \
			print "  <game>"; \
			print "    <path>./Motion_Sensor_Calibration.sh</path>"; \
			print "    <name>Motion Sensor Calibration</name>"; \
			print "    <desc>Calibrate the built-in gyroscope and accelerometer for motion controls.</desc>"; \
			print "    <image>./images/motion-sensor-calibration.svg</image>"; \
			print "    <thumbnail>./images/motion-sensor-calibration.svg</thumbnail>"; \
			print "  </game>"; \
		} { print }' "$${gamelist}" > "$${gamelist}.tmp" && \
		mv "$${gamelist}.tmp" "$${gamelist}"; \
	fi
endef
endif

ifeq ($(BR2_PACKAGE_BATOCERA_INSTALL_INTERNAL),y)
BATOCERA_ES_SYSTEM_DEPENDENCIES += batocera-install-internal

define BATOCERA_ES_SYSTEM_INSTALL_INTERNAL_TOOL
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-install-internal/datainit/roms/emulator/Install_Batocera_Internal.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Install_Batocera_Internal.sh
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-install-internal/datainit/roms/emulator/Install_Batocera_Internal.sh.keys \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Install_Batocera_Internal.sh.keys
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-install-internal/datainit/roms/emulator/images/install-internal.svg \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/images/install-internal.svg
	gamelist="$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/gamelist.xml"; \
	if [ -f "$${gamelist}" ] && ! grep -q './Install_Batocera_Internal.sh' "$${gamelist}"; then \
		awk '/<\/gameList>/ { \
			print "  <game>"; \
			print "    <path>./Install_Batocera_Internal.sh</path>"; \
			print "    <name>Install Batocera Internal</name>"; \
			print "    <desc>Install Batocera beside Android on supported Qualcomm handheld internal storage.</desc>"; \
			print "    <image>./images/install-internal.svg</image>"; \
			print "    <thumbnail>./images/install-internal.svg</thumbnail>"; \
			print "  </game>"; \
		} { print }' "$${gamelist}" > "$${gamelist}.tmp" && \
		mv "$${gamelist}.tmp" "$${gamelist}"; \
	fi
endef
endif

ifeq ($(BR2_PACKAGE_WAYDROID),y)
define BATOCERA_ES_SYSTEM_INSTALL_WAYDROID_TOOLS
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/waydroid.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/android/images/waydroid.png
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/waydroid.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/images/waydroid.png
	gamelist="$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/gamelist.xml"; \
	if [ -f "$${gamelist}" ] && ! grep -q './Waydroid_Tools.sh' "$${gamelist}"; then \
		awk '/<\/gameList>/ { \
			print "  <game>"; \
			print "    <path>./Waydroid_Tools.sh</path>"; \
			print "    <name>Waydroid Tools</name>"; \
			print "    <image>./images/waydroid.png</image>"; \
			print "  </game>"; \
		} { print }' "$${gamelist}" > "$${gamelist}.tmp" && \
		mv "$${gamelist}.tmp" "$${gamelist}"; \
	fi
endef
else
define BATOCERA_ES_SYSTEM_INSTALL_WAYDROID_TOOLS
	rm -f \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Waydroid_Tools.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Waydroid_Tools.sh.keys \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/images/waydroid.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/android/Waydroid.waydroid \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/android/gamelist.xml \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/android/images/waydroid.png
endef
endif

define BATOCERA_ES_SYSTEM_BUILD_CMDS
	$(HOST_DIR)/bin/python \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/batocera-es-system.py \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/es_systems.yml        \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/es_features.yml       \
		$(@D)/es_external_translations.h \
		$(@D)/es_keys_translations.h \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/locales/blacklisted-words.txt \
		$(CONFIG_DIR)/.config \
		$(@D)/es_systems.cfg \
		$(@D)/es_features.cfg \
		$(STAGING_DIR)/usr/share/batocera/configgen/configgen-defaults.yml \
		$(STAGING_DIR)/usr/share/batocera/configgen/configgen-defaults-arch.yml \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/roms \
		$(@D)/roms $(BATOCERA_SYSTEM_ARCH)

	# Translation files are maintained in-tree; /build/package is read-only.
	# Validate existing translations without regenerating or merging them.
	for PO in $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulationstation/batocera-es-system/locales/*/batocera-es-system.po; do \
		printf "%s " $$(basename $$(dirname $${PO})) && \
		LANG=C msgfmt -o /dev/null $${PO} --statistics || exit 1; \
	done

	# install staging
	mkdir -p $(STAGING_DIR)/usr/share/batocera-es-system/locales
	cp $(@D)/es_external_translations.h $(STAGING_DIR)/usr/share/batocera-es-system/
	cp $(@D)/es_keys_translations.h $(STAGING_DIR)/usr/share/batocera-es-system/
	cp -pr $(BATOCERA_ES_SYSTEM_LOCALES_DIR) $(STAGING_DIR)/usr/share/batocera-es-system/
endef

define BATOCERA_ES_SYSTEM_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit
	$(INSTALL) -m 0644 -D $(@D)/es_systems.cfg $(TARGET_DIR)/usr/share/emulationstation/es_systems.cfg
	$(INSTALL) -m 0644 -D $(@D)/es_features.cfg $(TARGET_DIR)/usr/share/emulationstation/es_features.cfg
	mkdir -p $(@D)/roms # in case there is no rom
	# Drop stale emulator-launcher datainit files from incremental target trees.
	rm -rf $(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator
	# Drop stale Steam datainit files from incremental target trees.
	rm -rf $(TARGET_DIR)/usr/share/batocera/datainit/roms/steam
	cp -pr $(@D)/roms $(TARGET_DIR)/usr/share/batocera/datainit/
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps/icons/shadps4.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/images/shadps4.png
	$(BATOCERA_ES_SYSTEM_INSTALL_WINE_TOOLS)
	$(BATOCERA_ES_SYSTEM_INSTALL_STEAM_TOOLS)
	$(BATOCERA_ES_SYSTEM_INSTALL_GAMEPAD_CALIBRATION_TOOL)
	$(BATOCERA_ES_SYSTEM_INSTALL_MOTION_SENSOR_CALIBRATION_TOOL)
	$(BATOCERA_ES_SYSTEM_INSTALL_INTERNAL_TOOL)
	$(BATOCERA_ES_SYSTEM_INSTALL_WAYDROID_TOOLS)
endef

$(eval $(generic-package))
