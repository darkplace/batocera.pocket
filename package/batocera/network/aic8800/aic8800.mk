################################################################################
#
# aic8800
#
################################################################################

AIC8800_VERSION = 4.0+git20250410.b99ca8b6-5
AIC8800_SITE = $(call github,radxa-pkg,aic8800,$(AIC8800_VERSION))
AIC8800_LICENSE = GPL-3.0
AIC8800_LICENSE_FILES = LICENSE

# set configs to be sure
AIC8800_MODULE_MAKE_OPTS += \
	CONFIG_AIC_WLAN_SUPPORT=y \
	CONFIG_AIC8800_WLAN_SUPPORT=m \
	CONFIG_AIC8800_BTLPM_SUPPORT=m \
	DEPMOD=true \
	USER_EXTRA_CFLAGS="-DCONFIG_$(call qstrip,$(BR2_ENDIAN))_ENDIAN \
		-Wno-error"

ifeq ($(BR2_PACKAGE_AIC8800_SDIO),y)
AIC8800_MODULE_SUBDIRS = src/SDIO/driver_fw/driver/aic8800
AIC8800_MODULE_MAKE_OPTS += CONFIG_AIC_FW_PATH="/lib/firmware/aic8800_fw/SDIO"
endif

ifeq ($(BR2_PACKAGE_AIC8800_USB),y)
AIC8800_MODULE_SUBDIRS += src/USB/driver_fw/drivers/aic8800 src/USB/driver_fw/drivers/aic_btusb
AIC8800_MODULE_MAKE_OPTS += CONFIG_AIC_FW_PATH="/lib/firmware/aic8800_fw/USB"
endif

define AIC8800_DEBIAN_PATCHES
	@$(call MESSAGE,"Patching AIC8800 with debian patches")
	$(APPLY_PATCHES) $(@D) $(dir $(@D)/debian/patches/series)
endef

# Rock 5c uses aic8800D80 & CoolPi 4b uses aic8800
define AIC8800_FIRMWARE_ETC_SDIO
    mkdir -p $(TARGET_DIR)/lib/firmware/aic8800_fw/SDIO
	cp -f $(@D)/src/SDIO/driver_fw/fw/aic8800/* \
	    $(TARGET_DIR)/lib/firmware/aic8800_fw/SDIO/
	cp -f $(@D)/src/SDIO/driver_fw/fw/aic8800D80/* \
	    $(TARGET_DIR)/lib/firmware/aic8800_fw/SDIO/
	cp -f $(@D)/src/SDIO/driver_fw/fw/aic8800D80X2/* \
	    $(TARGET_DIR)/lib/firmware/aic8800_fw/SDIO/
	cp -f $(@D)/src/SDIO/driver_fw/fw/aic8800DC/* \
	    $(TARGET_DIR)/lib/firmware/aic8800_fw/SDIO/
	# remove orangepi firmware duplication here...
	rm -rf $(TARGET_DIR)/lib/firmware/aic8800d80
endef

define AIC8800_FIRMWARE_ETC_USB
    mkdir -p $(TARGET_DIR)/lib/firmware/aic8800_fw/USB
	cp -rf $(@D)/src/USB/driver_fw/fw/aic8800/ \
	    $(TARGET_DIR)/lib/firmware/aic8800_fw/USB/
	cp -rf $(@D)/src/USB/driver_fw/fw/aic8800D80/ \
	    $(TARGET_DIR)/lib/firmware/aic8800_fw/USB/
	cp -rf $(@D)/src/USB/driver_fw/fw/aic8800D80X2/ \
	    $(TARGET_DIR)/lib/firmware/aic8800_fw/USB/
	cp -rf $(@D)/src/USB/driver_fw/fw/aic8800DC/ \
	    $(TARGET_DIR)/lib/firmware/aic8800_fw/USB/
endef

AIC8800_POST_PATCH_HOOKS = AIC8800_DEBIAN_PATCHES

ifeq ($(BR2_PACKAGE_AIC8800_SDIO),y)
AIC8800_POST_INSTALL_TARGET_HOOKS = AIC8800_FIRMWARE_ETC_SDIO
endif
ifeq ($(BR2_PACKAGE_AIC8800_USB),y)
AIC8800_POST_INSTALL_TARGET_HOOKS += AIC8800_FIRMWARE_ETC_USB
endif

$(eval $(kernel-module))

# The out-of-tree AIC modules_install step regenerates module indexes with
# only the AIC updates/ modules on qcs6490. Rebuild them against the full
# module tree so normal modalias autoloading still works.
define AIC8800_REBUILD_MODULE_INDEXES
	KVER="$(LINUX_VERSION_PROBED)"; \
	if test -d $(TARGET_DIR)/lib/modules/$${KVER}/kernel; then \
		$(HOST_DIR)/sbin/depmod -a -b $(TARGET_DIR) $${KVER}; \
	fi
endef
AIC8800_POST_INSTALL_TARGET_HOOKS += AIC8800_REBUILD_MODULE_INDEXES

# Batocera's post-build step moves /lib into $(TARGET_DIR)2 for large images.
# Package-only rebuilds run after that split, so keep the split tree in sync.
define AIC8800_SYNC_SPLIT_TARGET
	KVER="$(LINUX_VERSION_PROBED)"; \
	if test -d $(TARGET_DIR)2/lib/modules/$${KVER} -a -d $(TARGET_DIR)/lib/modules/$${KVER}/updates; then \
		mkdir -p $(TARGET_DIR)2/lib/modules/$${KVER}/updates; \
		cp -a $(TARGET_DIR)/lib/modules/$${KVER}/updates/. $(TARGET_DIR)2/lib/modules/$${KVER}/updates/; \
		$(HOST_DIR)/sbin/depmod -a -b $(TARGET_DIR)2 $${KVER}; \
	fi
	if test -d $(TARGET_DIR)2/lib/firmware -a -d $(TARGET_DIR)/lib/firmware/aic8800_fw; then \
		cp -a $(TARGET_DIR)/lib/firmware/aic8800_fw $(TARGET_DIR)2/lib/firmware/; \
	fi
endef
AIC8800_POST_INSTALL_TARGET_HOOKS += AIC8800_SYNC_SPLIT_TARGET

$(eval $(generic-package))
