################################################################################
#
# batocera userdata init
#
################################################################################

BATOCERA_USERDATAINIT_VERSION = 1.0
BATOCERA_USERDATAINIT_LICENSE = GPL
BATOCERA_USERDATAINIT_SOURCE=

define BATOCERA_USERDATAINIT_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/batocera
	rsync -arv $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-userdatainit/datainit/ $(TARGET_DIR)/usr/share/batocera/datainit/
	rm -f $(TARGET_DIR)/usr/share/batocera/datainit/roms/ports/Steam_Gamescope_Smoke_Test.sh
endef

define BATOCERA_USERDATAINIT_REMOVE_ALLY_HOTKEYS
	rm -f $(TARGET_DIR)/usr/share/batocera/datainit/system/configs/hotkeygen/ASUS_ROG_Ally_*.mapping*
	rm -f $(TARGET_DIR)/usr/share/batocera/datainit/system/scripts/50-ally-steam-hotkeys.sh
endef

ifneq ($(BR2_PACKAGE_BATOCERA_TARGET_X86_64_ANY),y)
	BATOCERA_USERDATAINIT_POST_INSTALL_TARGET_HOOKS += BATOCERA_USERDATAINIT_REMOVE_ALLY_HOTKEYS
endif

$(eval $(generic-package))
