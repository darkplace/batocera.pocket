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

$(eval $(generic-package))
