################################################################################
#
# batocera-wine
#
################################################################################

BATOCERA_WINE_VERSION = 1.4
BATOCERA_WINE_LICENSE = GPL
BATOCERA_WINE_SOURCE=

BATOCERA_WINE_SOURCE_PATH = \
    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-wine

define BATOCERA_WINE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/bin
	mkdir -p $(TARGET_DIR)/etc/X11/xorg.conf.d
	install -m 0755 $(BATOCERA_WINE_SOURCE_PATH)/batocera-wine \
	    $(TARGET_DIR)/usr/bin/batocera-wine
	install -m 0755 $(BATOCERA_WINE_SOURCE_PATH)/batocera-wine-runners \
	    $(TARGET_DIR)/usr/bin/batocera-wine-runners
	install -m 0755 $(BATOCERA_WINE_SOURCE_PATH)/batocera-wine-tools \
	    $(TARGET_DIR)/usr/bin/batocera-wine-tools
	install -m 0755 $(BATOCERA_WINE_SOURCE_PATH)/batocera-wine-tools-launcher \
	    $(TARGET_DIR)/usr/bin/batocera-wine-tools-launcher
	install -m 0755 $(BATOCERA_WINE_SOURCE_PATH)/bsod.py \
	    $(TARGET_DIR)/usr/bin/bsod-wine
	install -m 0755 \
	    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-steam/batocera-steam-shortcuts \
	    $(TARGET_DIR)/usr/bin/batocera-steam-shortcuts
	ln -fs /userdata/system/99-nvidia.conf $(TARGET_DIR)/etc/X11/xorg.conf.d/99-nvidia.conf

	$(INSTALL) -D -m 0755 $(BATOCERA_WINE_SOURCE_PATH)/datainit/roms/emulator/Wine_Tools.sh \
	    $(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Wine_Tools.sh
	$(INSTALL) -D -m 0644 $(BATOCERA_WINE_SOURCE_PATH)/datainit/roms/emulator/Wine_Tools.sh.keys \
	    $(TARGET_DIR)/usr/share/batocera/datainit/roms/emulator/Wine_Tools.sh.keys

	mkdir -p $(TARGET_DIR)/usr/share/evmapy
	cp $(BATOCERA_WINE_SOURCE_PATH)/mugen.keys \
	    $(TARGET_DIR)/usr/share/evmapy
endef

$(eval $(generic-package))
