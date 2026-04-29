################################################################################
#
# BOX64 emulator
#
################################################################################

# Release: Apr 20, 2026
BOX64_VERSION = v0.4.2
BOX64_SITE = https://github.com/ptitseb/box64
BOX64_SITE_METHOD = git
BOX64_LICENSE = GPLv3
BOX64_DEPENDENCIES = host-python3
BOX64_BIN_ARCH_EXCLUDE += /usr/lib/box64-x86_64-linux-gnu
BOX64_BIN_ARCH_EXCLUDE += /usr/lib/box64-i386-linux-gnu

BOX64_CONF_OPTS += \
	-DCMAKE_BUILD_TYPE=Release \
	-DNOGIT=ON \
	-DBOX32=ON \
	-DBOX32_BINFMT=ON \
	-DUSE_CCACHE=OFF \
	-DNO_AUTO_MARCH=ON \
	-DINSTALL_BINFMT=OFF \
	-DINSTALL_LIBS=OFF \
	-DINSTALL_HELPERS=OFF



################################################################################
# AArch64 targets (Batocera only)
################################################################################
ifeq ($(BR2_aarch64),y)

ifeq ($(BR2_PACKAGE_SYSTEM_TARGET_BCM2837),y)
BOX64_CONF_OPTS += -DRPI3ARM64=ON

else ifeq ($(BR2_PACKAGE_SYSTEM_TARGET_BCM2711),y)
BOX64_CONF_OPTS += -DRPI4ARM64=ON

else ifeq ($(BR2_PACKAGE_SYSTEM_TARGET_BCM2712),y)
BOX64_CONF_OPTS += -DRPI5ARM64=ON

else ifeq ($(BR2_PACKAGE_SYSTEM_TARGET_H700),y)
BOX64_CONF_OPTS += -DA53=ON -DSAVE_MEM=ON

else ifeq ($(BR2_PACKAGE_SYSTEM_TARGET_RK3326)$(BR2_PACKAGE_SYSTEM_TARGET_S9GEN4),y)
BOX64_CONF_OPTS += -DRK3326=ON

else ifeq ($(BR2_PACKAGE_SYSTEM_TARGET_RK3566)$(BR2_PACKAGE_SYSTEM_TARGET_RK3568),y)
BOX64_CONF_OPTS += -DRK3566=ON

else ifeq ($(BR2_PACKAGE_SYSTEM_TARGET_RK3399),y)
BOX64_CONF_OPTS += -DRK3399=ON

else ifeq ($(BR2_PACKAGE_SYSTEM_TARGET_RK3588),y)
BOX64_CONF_OPTS += -DRK3588=ON

else ifeq ($(BR2_cortex_a73_a53),y)
BOX64_CONF_OPTS += -DODROIDN2=ON

else ifeq ($(BR2_PACKAGE_SYSTEM_TARGET_SDM845),y)
BOX64_CONF_OPTS += -DSD845=ON

else ifeq ($(BR2_PACKAGE_SYSTEM_TARGET_SM8250)$(BR2_PACKAGE_SYSTEM_TARGET_QCS6490),y)
BOX64_CONF_OPTS += -DSD865=ON

else ifeq ($(BR2_PACKAGE_SYSTEM_TARGET_SM8550),y)
BOX64_CONF_OPTS += -DSD8G2=ON

else
# Generic ARM64 fallback (ARMv8.0+ safe)
BOX64_CONF_OPTS += -DARM64=ON -DSAVE_MEM=ON
endif

endif # BR2_aarch64

define BOX64_INSTALL_BATOCERA_FILES
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/box64/S31box64-binfmt \
		$(TARGET_DIR)/etc/init.d/S31box64-binfmt
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/box64/box64.conf \
		$(TARGET_DIR)/etc/binfmt.d/box64.conf
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/box64/box32.conf \
		$(TARGET_DIR)/etc/binfmt.d/box32.conf
endef

define BOX64_REMOVE_FOREIGN_HELPERS
	rm -f $(TARGET_DIR)/usr/bin/box64-bash
endef

BOX64_POST_INSTALL_TARGET_HOOKS += BOX64_INSTALL_BATOCERA_FILES
BOX64_POST_INSTALL_TARGET_HOOKS += BOX64_REMOVE_FOREIGN_HELPERS

$(eval $(cmake-package))
