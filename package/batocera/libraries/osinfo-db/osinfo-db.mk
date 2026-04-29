################################################################################
#
# osinfo-db
#
################################################################################

OSINFO_DB_VERSION = 20250606
OSINFO_DB_SOURCE = osinfo-db-$(OSINFO_DB_VERSION).tar.xz
OSINFO_DB_SITE = https://releases.pagure.org/libosinfo
OSINFO_DB_LICENSE = LGPL-2.1+
OSINFO_DB_LICENSE_FILES = LICENSE
OSINFO_DB_INSTALL_STAGING = YES

OSINFO_DB_DIRS = datamap device install-script os platform schema

define OSINFO_DB_BUILD_CMDS
	true
endef

define OSINFO_DB_INSTALL_STAGING_CMDS
	mkdir -p $(STAGING_DIR)/usr/share/osinfo
	for d in $(OSINFO_DB_DIRS); do \
		cp -a $(@D)/$$d $(STAGING_DIR)/usr/share/osinfo/; \
	done
	cp -a $(@D)/LICENSE $(STAGING_DIR)/usr/share/osinfo/
endef

define OSINFO_DB_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/osinfo
	for d in $(OSINFO_DB_DIRS); do \
		cp -a $(@D)/$$d $(TARGET_DIR)/usr/share/osinfo/; \
	done
	cp -a $(@D)/LICENSE $(TARGET_DIR)/usr/share/osinfo/
endef

$(eval $(generic-package))
