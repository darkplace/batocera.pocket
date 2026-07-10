################################################################################
#
# batocera-ubuntu-plasma-lxc
#
################################################################################

BATOCERA_UBUNTU_PLASMA_LXC_VERSION = 1.01
BATOCERA_UBUNTU_PLASMA_LXC_SOURCE =
BATOCERA_UBUNTU_PLASMA_LXC_DEPENDENCIES = \
	batocera-arch-plasma-lxc \
	bash \
	dialog \
	dnsmasq \
	iptables \
	libcurl \
	lxc \
	squashfs \
	xterm

BATOCERA_UBUNTU_PLASMA_LXC_PKGDIR = \
	$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-ubuntu-plasma-lxc

define BATOCERA_UBUNTU_PLASMA_LXC_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(BATOCERA_UBUNTU_PLASMA_LXC_PKGDIR)/batocera-ubuntu-plasma-lxc \
		$(TARGET_DIR)/usr/bin/batocera-ubuntu-plasma-lxc
endef

$(eval $(generic-package))
