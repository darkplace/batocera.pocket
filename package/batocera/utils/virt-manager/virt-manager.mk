################################################################################
#
# virt-manager
#
################################################################################

VIRT_MANAGER_VERSION = 5.1.0
VIRT_MANAGER_SOURCE = virt-manager-$(VIRT_MANAGER_VERSION).tar.xz
VIRT_MANAGER_SITE = https://github.com/virt-manager/virt-manager/releases/download/v$(VIRT_MANAGER_VERSION)
VIRT_MANAGER_LICENSE = GPL-2.0+
VIRT_MANAGER_LICENSE_FILES = COPYING
VIRT_MANAGER_DEPENDENCIES = \
	host-gettext \
	host-libglib2 \
	host-pkgconf \
	gtk-vnc \
	spice-gtk \
	gtksourceview \
	hicolor-icon-theme \
	adwaita-icon-theme \
	libgtk3 \
	libosinfo \
	libvirt-glib \
	osinfo-db \
	python-argcomplete \
	python-gobject \
	python-libxml2 \
	python-libvirt \
	python-lxml \
	python-requests \
	python3 \
	shared-mime-info \
	vte \
	xorriso

VIRT_MANAGER_CONF_OPTS += \
	-Dcompile-schemas=false \
	-Ddefault-graphics=vnc \
	-Ddefault-hvs=qemu,lxc \
	-Dtests=disabled \
	-Dupdate-icon-cache=false

define VIRT_MANAGER_DISABLE_MANPAGES
	$(SED) '/subdir('"'"'man'"'"')/d' $(@D)/meson.build
endef
VIRT_MANAGER_POST_PATCH_HOOKS += VIRT_MANAGER_DISABLE_MANPAGES

define VIRT_MANAGER_INSTALL_XMLAPI_COMPAT
	$(INSTALL) -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/virt-manager/xmlapi.py \
		$(@D)/virtinst/xmlapi.py
endef
VIRT_MANAGER_POST_PATCH_HOOKS += VIRT_MANAGER_INSTALL_XMLAPI_COMPAT

define VIRT_MANAGER_INSTALL_GSETTINGS_SCHEMA
	$(INSTALL) -D -m 0644 \
		$(@D)/data/org.virt-manager.virt-manager.gschema.xml \
		$(STAGING_DIR)/usr/share/glib-2.0/schemas/org.virt-manager.virt-manager.gschema.xml
	$(HOST_DIR)/bin/glib-compile-schemas \
		$(STAGING_DIR)/usr/share/glib-2.0/schemas \
		--targetdir=$(TARGET_DIR)/usr/share/glib-2.0/schemas
endef
VIRT_MANAGER_POST_INSTALL_TARGET_HOOKS += VIRT_MANAGER_INSTALL_GSETTINGS_SCHEMA

$(eval $(meson-package))
