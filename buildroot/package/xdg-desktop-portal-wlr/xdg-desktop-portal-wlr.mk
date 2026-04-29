################################################################################
#
# xdg-desktop-portal-wlr
#
################################################################################

XDG_DESKTOP_PORTAL_WLR_VERSION = 0.7.1
XDG_DESKTOP_PORTAL_WLR_SOURCE = v$(XDG_DESKTOP_PORTAL_WLR_VERSION).tar.gz
XDG_DESKTOP_PORTAL_WLR_SITE = https://github.com/emersion/xdg-desktop-portal-wlr/archive/refs/tags
XDG_DESKTOP_PORTAL_WLR_LICENSE = MIT
XDG_DESKTOP_PORTAL_WLR_LICENSE_FILES = LICENSE

XDG_DESKTOP_PORTAL_WLR_DEPENDENCIES = \
	basu \
	host-pkgconf \
	inih \
	libdrm \
	pipewire \
	wayland \
	wayland-protocols \
	xdg-desktop-portal

XDG_DESKTOP_PORTAL_WLR_CONF_OPTS = \
	-Dman-pages=disabled \
	-Dsd-bus-provider=basu \
	-Dsystemd=disabled

$(eval $(meson-package))
