################################################################################
#
# batocera-arch-plasma-lxc
#
################################################################################

BATOCERA_ARCH_PLASMA_LXC_VERSION = 1.16
BATOCERA_ARCH_PLASMA_LXC_SOURCE =
BATOCERA_ARCH_PLASMA_LXC_DEPENDENCIES = \
	bash \
	dialog \
	dnsmasq \
	iptables \
	lxc \
	xterm

BATOCERA_ARCH_PLASMA_LXC_PKGDIR = \
	$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-arch-plasma-lxc

define BATOCERA_ARCH_PLASMA_LXC_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(BATOCERA_ARCH_PLASMA_LXC_PKGDIR)/batocera-arch-plasma-lxc \
		$(TARGET_DIR)/usr/bin/batocera-arch-plasma-lxc
endef

$(eval $(generic-package))
