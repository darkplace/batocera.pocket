################################################################################
#
# zerotier-one
#
################################################################################

ZEROTIER_ONE_VERSION = 1.16.0
ZEROTIER_ONE_SITE = $(call github,zerotier,ZeroTierOne,$(ZEROTIER_ONE_VERSION))
ZEROTIER_ONE_LICENSE = BSL-1.1, MPL-2.0
ZEROTIER_ONE_LICENSE_FILES = LICENSE.txt LICENSE-MPL.txt

define ZEROTIER_ONE_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D) -f make-linux.mk \
	    ZT_SSO_SUPPORTED=0 MINIUPNPC_IS_NEW_ENOUGH=0 one
endef

define ZEROTIER_ONE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/zerotier-one $(TARGET_DIR)/usr/sbin/zerotier-one
	ln -sf zerotier-one $(TARGET_DIR)/usr/sbin/zerotier-cli
	ln -sf zerotier-one $(TARGET_DIR)/usr/sbin/zerotier-idtool
	mkdir -p $(TARGET_DIR)/usr/bin
	ln -sf ../sbin/zerotier-one $(TARGET_DIR)/usr/bin/zerotier-cli
	ln -sf ../sbin/zerotier-one $(TARGET_DIR)/usr/bin/zerotier-idtool
	$(INSTALL) -Dm755 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/zerotier-one/zerotier \
	    $(TARGET_DIR)/usr/share/batocera/services/zerotier
	$(INSTALL) -Dm755 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/zerotier-one/zerotier-join \
	    $(TARGET_DIR)/usr/bin/zerotier-join
endef

$(eval $(generic-package))
