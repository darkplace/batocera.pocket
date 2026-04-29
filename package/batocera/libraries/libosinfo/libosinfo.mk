################################################################################
#
# libosinfo
#
################################################################################

LIBOSINFO_VERSION = 1.12.0
LIBOSINFO_SOURCE = libosinfo-$(LIBOSINFO_VERSION).tar.xz
LIBOSINFO_SITE = https://releases.pagure.org/libosinfo
LIBOSINFO_LICENSE = LGPL-2.1+
LIBOSINFO_LICENSE_FILES = COPYING COPYING.LIB
LIBOSINFO_INSTALL_STAGING = YES
LIBOSINFO_DEPENDENCIES = \
	host-pkgconf \
	libglib2 \
	libsoup3 \
	libxml2 \
	libxslt \
	hwdata

ifeq ($(BR2_PACKAGE_GOBJECT_INTROSPECTION),y)
LIBOSINFO_DEPENDENCIES += gobject-introspection
LIBOSINFO_CONF_OPTS += -Denable-introspection=enabled -Denable-vala=disabled
else
LIBOSINFO_CONF_OPTS += -Denable-introspection=disabled -Denable-vala=disabled
endif

LIBOSINFO_CONF_OPTS += \
	-Denable-gtk-doc=false \
	-Denable-tests=false \
	-Dlibsoup-abi=3.0 \
	-Dwith-pci-ids-path=/usr/share/hwdata/pci.ids \
	-Dwith-usb-ids-path=/usr/share/hwdata/usb.ids

define LIBOSINFO_ENABLE_CROSS_INTROSPECTION
	$(SED) 's/gir\.found() and not meson\.is_cross_build()/gir.found()/' $(@D)/meson.build
endef
LIBOSINFO_POST_PATCH_HOOKS += LIBOSINFO_ENABLE_CROSS_INTROSPECTION

define LIBOSINFO_FIX_ATTRIBUTE_UNUSED
	$(SED) 's/msg ATTRIBUTE_UNUSED/msg G_GNUC_UNUSED/' $(@D)/osinfo/osinfo_loader.c
endef
LIBOSINFO_POST_PATCH_HOOKS += LIBOSINFO_FIX_ATTRIBUTE_UNUSED

$(eval $(meson-package))
