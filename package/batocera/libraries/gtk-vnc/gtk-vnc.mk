################################################################################
#
# gtk-vnc
#
################################################################################

GTK_VNC_VERSION = 1.3.1
GTK_VNC_SOURCE = gtk-vnc-$(GTK_VNC_VERSION).tar.xz
GTK_VNC_SITE = https://download.gnome.org/sources/gtk-vnc/1.3
GTK_VNC_LICENSE = LGPL-2.1+
GTK_VNC_LICENSE_FILES = COPYING.LIB
GTK_VNC_INSTALL_STAGING = YES
GTK_VNC_DEPENDENCIES = \
	host-pkgconf \
	gnutls \
	libgcrypt \
	libgtk3 \
	zlib

ifeq ($(BR2_PACKAGE_GOBJECT_INTROSPECTION),y)
GTK_VNC_DEPENDENCIES += gobject-introspection
GTK_VNC_CONF_OPTS += -Dintrospection=enabled -Dwith-vala=disabled
else
GTK_VNC_CONF_OPTS += -Dintrospection=disabled -Dwith-vala=disabled
endif

GTK_VNC_CONF_OPTS += \
	-Dpulseaudio=disabled \
	-Dsasl=disabled \
	-Dwith-coroutine=gthread

$(eval $(meson-package))
