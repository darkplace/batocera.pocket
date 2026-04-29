################################################################################
#
# spice-gtk
#
################################################################################

SPICE_GTK_VERSION = 0.42
SPICE_GTK_SOURCE = spice-gtk-$(SPICE_GTK_VERSION).tar.xz
SPICE_GTK_SITE = https://www.spice-space.org/download/gtk
SPICE_GTK_LICENSE = LGPL-2.1+
SPICE_GTK_LICENSE_FILES = COPYING
SPICE_GTK_INSTALL_STAGING = YES
SPICE_GTK_DEPENDENCIES = \
	host-gettext \
	host-pkgconf \
	gstreamer1 \
	gst1-plugins-base \
	json-glib \
	jpeg \
	libglib2 \
	libgtk3 \
	openssl \
	pixman \
	spice-protocol \
	zlib

ifeq ($(BR2_PACKAGE_GOBJECT_INTROSPECTION),y)
SPICE_GTK_DEPENDENCIES += gobject-introspection
SPICE_GTK_CONF_OPTS += -Dintrospection=enabled -Dvapi=disabled
else
SPICE_GTK_CONF_OPTS += -Dintrospection=disabled -Dvapi=disabled
endif

SPICE_GTK_CONF_OPTS += \
	-Dgtk=enabled \
	-Dwayland-protocols=disabled \
	-Dwebdav=disabled \
	-Dusbredir=disabled \
	-Dlibcap-ng=disabled \
	-Dpolkit=disabled \
	-Dlz4=disabled \
	-Dsasl=disabled \
	-Dsmartcard=disabled \
	-Dopus=disabled \
	-Dgtk_doc=disabled \
	-Dspice-common:python-checks=false \
	-Dcoroutine=gthread

$(eval $(meson-package))
