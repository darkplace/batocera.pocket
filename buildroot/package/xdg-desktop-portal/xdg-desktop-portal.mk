################################################################################
#
# xdg-desktop-portal
#
################################################################################

XDG_DESKTOP_PORTAL_VERSION = 1.18.4
XDG_DESKTOP_PORTAL_SOURCE = xdg-desktop-portal-$(XDG_DESKTOP_PORTAL_VERSION).tar.xz
XDG_DESKTOP_PORTAL_SITE = https://github.com/flatpak/xdg-desktop-portal/releases/download/$(XDG_DESKTOP_PORTAL_VERSION)
XDG_DESKTOP_PORTAL_LICENSE = LGPL-2.1+
XDG_DESKTOP_PORTAL_LICENSE_FILES = COPYING
XDG_DESKTOP_PORTAL_INSTALL_STAGING = YES

XDG_DESKTOP_PORTAL_DEPENDENCIES = \
	host-pkgconf \
	gdk-pixbuf \
	json-glib \
	libfuse3 \
	libglib2 \
	pipewire

XDG_DESKTOP_PORTAL_CONF_OPTS = \
	-Ddocbook-docs=disabled \
	-Dgeoclue=disabled \
	-Dinstalled-tests=false \
	-Dlibportal=disabled \
	-Dman-pages=disabled \
	-Dpytest=disabled \
	-Dsandboxed-image-validation=false \
	-Dsystemd=disabled

define XDG_DESKTOP_PORTAL_FIX_STAGING_PKGCONFIG
	$(SED) 's#^interfaces_dir=.*#interfaces_dir=$${pc_sysrootdir}$${datadir}/dbus-1/interfaces/#' \
		$(STAGING_DIR)/usr/share/pkgconfig/xdg-desktop-portal.pc
endef

XDG_DESKTOP_PORTAL_POST_INSTALL_STAGING_HOOKS += XDG_DESKTOP_PORTAL_FIX_STAGING_PKGCONFIG

$(eval $(meson-package))
