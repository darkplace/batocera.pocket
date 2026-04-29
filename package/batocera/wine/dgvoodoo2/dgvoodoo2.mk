################################################################################
#
# dgVoodoo2
#
################################################################################

DGVOODOO2_VERSION = 2.86.5
DGVOODOO2_SOURCE = dgVoodoo2_86_5.zip
DGVOODOO2_SITE = https://github.com/dege-diosg/dgVoodoo2/releases/download/v$(DGVOODOO2_VERSION)
DGVOODOO2_LICENSE = Freeware
DGVOODOO2_BIN_ARCH_EXCLUDE += /usr/wine/dgvoodoo2


define DGVOODOO2_EXTRACT_CMDS
	mkdir -p $(@D)/target
	unzip -q $(DL_DIR)/$(DGVOODOO2_DL_SUBDIR)/$(DGVOODOO2_SOURCE) -d $(@D)/target
endef


define DGVOODOO2_INSTALL_TARGET_CMDS
	rm -rf $(TARGET_DIR)/usr/wine/dgvoodoo2
	mkdir -p $(TARGET_DIR)/usr/wine/dgvoodoo2
	cp -pr $(@D)/target/* $(TARGET_DIR)/usr/wine/dgvoodoo2/
endef

$(eval $(generic-package))
