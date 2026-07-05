# SPDX-FileCopyrightText: Added/modified by suckbluefrog
################################################################################
#
# lutris
#
################################################################################

LUTRIS_VERSION = 0.5.20
LUTRIS_SITE = https://github.com/lutris/lutris/archive/refs/tags
LUTRIS_SOURCE = v$(LUTRIS_VERSION).tar.gz
LUTRIS_LICENSE = GPL-3.0
LUTRIS_LICENSE_FILES = LICENSE
LUTRIS_SETUP_TYPE = setuptools

LUTRIS_DEPENDENCIES = \
	adwaita-icon-theme \
	dbus-python \
	font-awesome \
	gdk-pixbuf \
	hicolor-icon-theme \
	jpeg \
	libgtk3 \
	librsvg \
	openal \
	python-distro \
	python-evdev \
	python-gobject \
	python-pycairo \
	python-lxml \
	python-pillow \
	python-protobuf \
	python-pyyaml \
	python-requests \
	python-setproctitle \
	webkitgtk

ifeq ($(BR2_PACKAGE_XORG7),y)
LUTRIS_DEPENDENCIES += xapp_xrandr
ifeq ($(BR2_PACKAGE_HAS_LIBGL),y)
LUTRIS_DEPENDENCIES += mesa3d-demos
endif
endif

define LUTRIS_PREPARE_TARGET_SCRIPT_SLOT
	rm -f \
		$(TARGET_DIR)/usr/bin/lutris \
		$(TARGET_DIR)/usr/libexec/lutris-bin
	for d in $(TARGET_DIR)/usr/lib/python*/site-packages; do \
		[ -d "$$d" ] || continue; \
		rm -rf "$$d/lutris" "$$d"/lutris-*.dist-info; \
	done
	rm -rf \
		$(TARGET_DIR)/share/lutris \
		$(TARGET_DIR)/usr/share/lutris
	rm -f \
		$(TARGET_DIR)/share/applications/net.lutris.Lutris.desktop \
		$(TARGET_DIR)/share/applications/net.lutris.Lutris1.desktop \
		$(TARGET_DIR)/share/metainfo/net.lutris.Lutris.metainfo.xml \
		$(TARGET_DIR)/usr/share/applications/net.lutris.Lutris.desktop \
		$(TARGET_DIR)/usr/share/applications/net.lutris.Lutris1.desktop \
		$(TARGET_DIR)/usr/share/metainfo/net.lutris.Lutris.metainfo.xml
	if [ -d "$(TARGET_DIR)/share" ]; then \
		find "$(TARGET_DIR)/share" -depth \( -name '*lutris*' -o -name 'net.lutris*' \) -exec rm -rf {} +; \
	fi
	for d in $(TARGET_DIR)/share/icons/hicolor $(TARGET_DIR)/usr/share/icons/hicolor; do \
		[ -d "$$d" ] || continue; \
		find "$$d" -type f -name '*lutris*' -delete; \
	done
	for d in $(TARGET_DIR)/share/mime $(TARGET_DIR)/usr/share/mime; do \
		[ -d "$$d" ] || continue; \
		find "$$d" -type f -name '*lutris*' -delete; \
	done
endef

define LUTRIS_INSTALL_WRAPPER
	mkdir -p $(TARGET_DIR)/usr/libexec
	if [ -f "$(TARGET_DIR)/usr/bin/lutris" ]; then \
		if ! grep -q "BATOCERA_LUTRIS_HOME" "$(TARGET_DIR)/usr/bin/lutris"; then \
			mv -f "$(TARGET_DIR)/usr/bin/lutris" "$(TARGET_DIR)/usr/libexec/lutris-bin"; \
		fi; \
	fi
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/lutris/lutris \
		$(TARGET_DIR)/usr/bin/lutris
endef

define LUTRIS_FIX_SHARE_LAYOUT
	if [ -d "$(TARGET_DIR)/share/lutris" ]; then \
		mkdir -p "$(TARGET_DIR)/usr/share"; \
		rm -rf "$(TARGET_DIR)/usr/share/lutris"; \
		mv "$(TARGET_DIR)/share/lutris" "$(TARGET_DIR)/usr/share/lutris"; \
		ln -snf ../usr/share/lutris "$(TARGET_DIR)/share/lutris"; \
	fi
endef

define LUTRIS_PATCH_ROOT_CHECK
	for f in $(TARGET_DIR)/usr/lib/python*/site-packages/lutris/gui/application.py; do \
		[ -f "$$f" ] || continue; \
		sed -i 's/os.geteuid() == 0/os.geteuid() == 888/g' "$$f"; \
	done
endef

define LUTRIS_CLEAN_UP_DESKTOP_FILES
	rm -f \
		$(TARGET_DIR)/share/applications/net.lutris.Lutris.desktop \
		$(TARGET_DIR)/share/applications/net.lutris.Lutris1.desktop \
		$(TARGET_DIR)/usr/share/applications/net.lutris.Lutris.desktop \
		$(TARGET_DIR)/usr/share/applications/net.lutris.Lutris1.desktop
endef

define LUTRIS_INSTALL_OPENAL_COMPAT
	for d in lib usr/lib usr/lib64; do \
		if [ -e "$(TARGET_DIR)/$$d/libopenal.so.1" ] && [ ! -e "$(TARGET_DIR)/$$d/libal.so.1" ]; then \
			ln -sf libopenal.so.1 "$(TARGET_DIR)/$$d/libal.so.1"; \
		fi; \
	done
endef

define LUTRIS_INSTALL_ICON_FALLBACKS
	mkdir -p "$(TARGET_DIR)/usr/share/icons/hicolor/scalable/actions"
	for name in \
		wine-symbolic \
		flatpak-symbolic \
		linux-symbolic \
		eaapp-symbolic \
		ealauncher-symbolic \
		steam-symbolic; do \
		ln -snf /usr/share/icons/Adwaita/scalable/mimetypes/package-x-generic-symbolic.svg \
			"$(TARGET_DIR)/usr/share/icons/hicolor/scalable/actions/$$name.svg"; \
	done
	ln -snf /usr/share/icons/Adwaita/scalable/ui/window-close-symbolic.svg \
		"$(TARGET_DIR)/usr/share/icons/hicolor/scalable/actions/window-close-symbolic.svg"
	ln -snf window-close-symbolic.svg \
		"$(TARGET_DIR)/usr/share/icons/hicolor/scalable/actions/window-close.svg"
endef

LUTRIS_PRE_INSTALL_TARGET_HOOKS += LUTRIS_PREPARE_TARGET_SCRIPT_SLOT
LUTRIS_POST_INSTALL_TARGET_HOOKS += LUTRIS_FIX_SHARE_LAYOUT
LUTRIS_POST_INSTALL_TARGET_HOOKS += LUTRIS_INSTALL_WRAPPER
LUTRIS_POST_INSTALL_TARGET_HOOKS += LUTRIS_PATCH_ROOT_CHECK
LUTRIS_POST_INSTALL_TARGET_HOOKS += LUTRIS_CLEAN_UP_DESKTOP_FILES
LUTRIS_POST_INSTALL_TARGET_HOOKS += LUTRIS_INSTALL_OPENAL_COMPAT
LUTRIS_POST_INSTALL_TARGET_HOOKS += LUTRIS_INSTALL_ICON_FALLBACKS

$(eval $(python-package))
