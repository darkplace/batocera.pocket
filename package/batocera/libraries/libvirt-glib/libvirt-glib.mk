################################################################################
#
# libvirt-glib
#
################################################################################

LIBVIRT_GLIB_VERSION = 5.0.0
LIBVIRT_GLIB_SOURCE = libvirt-glib-$(LIBVIRT_GLIB_VERSION).tar.xz
LIBVIRT_GLIB_SITE = https://download.libvirt.org/glib
LIBVIRT_GLIB_LICENSE = LGPL-2.0+
LIBVIRT_GLIB_LICENSE_FILES = COPYING
LIBVIRT_GLIB_INSTALL_STAGING = YES
LIBVIRT_GLIB_DEPENDENCIES = \
	host-pkgconf \
	libglib2 \
	libvirt \
	libxml2

ifeq ($(BR2_PACKAGE_GOBJECT_INTROSPECTION),y)
LIBVIRT_GLIB_DEPENDENCIES += gobject-introspection
LIBVIRT_GLIB_CONF_OPTS += -Dintrospection=enabled -Dvapi=disabled
else
LIBVIRT_GLIB_CONF_OPTS += -Dintrospection=disabled -Dvapi=disabled
endif

LIBVIRT_GLIB_CONF_OPTS += \
	-Ddocs=disabled \
	-Dtests=disabled \
	-Dgit_werror=disabled \
	-Drpath=disabled

define LIBVIRT_GLIB_ENABLE_CROSS_INTROSPECTION
	$(SED) 's/gir\.found() and not meson\.is_cross_build()/gir.found()/' $(@D)/meson.build
endef
LIBVIRT_GLIB_POST_PATCH_HOOKS += LIBVIRT_GLIB_ENABLE_CROSS_INTROSPECTION

$(eval $(meson-package))
