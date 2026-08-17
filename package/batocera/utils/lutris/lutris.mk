# SPDX-FileCopyrightText: Added/modified by suckbluefrog
################################################################################
#
# lutris
#
################################################################################

LUTRIS_VERSION = 0.5.22
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
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/lutris/batocera-lutris-egs-install \
		$(TARGET_DIR)/usr/bin/batocera-lutris-egs-install
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/lutris/batocera-lutris-gog-install \
		$(TARGET_DIR)/usr/bin/batocera-lutris-gog-install
	# Legendary / gogdl helper modules
	for d in $(TARGET_DIR)/usr/lib/python*/site-packages/lutris/util/egs; do \
		[ -d "$$d" ] || continue; \
		$(INSTALL) -D -m 0644 \
			$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/lutris/legendary.py \
			"$$d/legendary.py"; \
	done
	for d in $(TARGET_DIR)/usr/lib/python*/site-packages/lutris/util; do \
		[ -d "$$d" ] || continue; \
		$(INSTALL) -D -m 0644 \
			$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/lutris/gogdl_helper.py \
			"$$d/gogdl_helper.py"; \
	done
	# Firefox OAuth login dialog (replaces WebKit when BATOCERA_LUTRIS_BROWSER_LOGIN=1)
	for d in $(TARGET_DIR)/usr/lib/python*/site-packages/lutris; do \
		[ -d "$$d" ] || continue; \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/lutris/apply-browser-login.sh "$$d"; \
	done
	# Convenience symlinks when Heroic ships tools
	if [ ! -e "$(TARGET_DIR)/usr/bin/legendary" ]; then \
		leg=""; \
		for f in $(TARGET_DIR)/usr/share/heroic/heroic-arm64/Heroic-*/resources/app.asar.unpacked/build/bin/arm64/linux/legendary; do \
			[ -x "$$f" ] || continue; leg="$$f"; break; \
		done; \
		if [ -n "$$leg" ]; then \
			rel="$$(echo "$$leg" | sed "s|^$(TARGET_DIR)||")"; \
			ln -snf "$$rel" "$(TARGET_DIR)/usr/bin/legendary"; \
		fi; \
	fi
	if [ ! -e "$(TARGET_DIR)/usr/bin/gogdl" ]; then \
		gog=""; \
		for f in $(TARGET_DIR)/usr/share/heroic/heroic-arm64/Heroic-*/resources/app.asar.unpacked/build/bin/arm64/linux/gogdl; do \
			[ -x "$$f" ] || continue; gog="$$f"; break; \
		done; \
		if [ -n "$$gog" ]; then \
			rel="$$(echo "$$gog" | sed "s|^$(TARGET_DIR)||")"; \
			ln -snf "$$rel" "$(TARGET_DIR)/usr/bin/gogdl"; \
		fi; \
	fi
	# Without gi._gi_cairo, Lutris IconView covers stay blank on aarch64.
	if ! ls "$(TARGET_DIR)"/usr/lib/python*/site-packages/gi/_gi_cairo*.so >/dev/null 2>&1; then \
		echo "ERROR: gi._gi_cairo missing — enable cairo support in python-gobject" >&2; \
		exit 1; \
	fi
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
	mkdir -p "$(TARGET_DIR)/usr/share/icons/hicolor/scalable/actions" \
		"$(TARGET_DIR)/usr/share/icons/hicolor/16x16/actions" \
		"$(TARGET_DIR)/usr/share/icons/hicolor/24x24/actions"
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
	# Adwaita (this image) lacks favorite-symbolic / tag-symbolic; alias PNG emblems.
	for sz in 16x16 24x24 32x32 48x48; do \
		fav="$(TARGET_DIR)/usr/share/icons/Adwaita/$$sz/emblems/emblem-favorite-symbolic.symbolic.png"; \
		star="$(TARGET_DIR)/usr/share/icons/Adwaita/$$sz/status/starred-symbolic.symbolic.png"; \
		mkdir -p "$(TARGET_DIR)/usr/share/icons/hicolor/$$sz/actions"; \
		if [ -f "$$fav" ]; then \
			ln -snf "/usr/share/icons/Adwaita/$$sz/emblems/emblem-favorite-symbolic.symbolic.png" \
				"$(TARGET_DIR)/usr/share/icons/hicolor/$$sz/actions/favorite-symbolic.png"; \
			ln -snf "/usr/share/icons/Adwaita/$$sz/emblems/emblem-favorite-symbolic.symbolic.png" \
				"$(TARGET_DIR)/usr/share/icons/hicolor/$$sz/actions/tag-symbolic.png"; \
		elif [ -f "$$star" ]; then \
			ln -snf "/usr/share/icons/Adwaita/$$sz/status/starred-symbolic.symbolic.png" \
				"$(TARGET_DIR)/usr/share/icons/hicolor/$$sz/actions/favorite-symbolic.png"; \
			ln -snf "/usr/share/icons/Adwaita/$$sz/status/starred-symbolic.symbolic.png" \
				"$(TARGET_DIR)/usr/share/icons/hicolor/$$sz/actions/tag-symbolic.png"; \
		fi; \
	done
endef

LUTRIS_PRE_INSTALL_TARGET_HOOKS += LUTRIS_PREPARE_TARGET_SCRIPT_SLOT
LUTRIS_POST_INSTALL_TARGET_HOOKS += LUTRIS_FIX_SHARE_LAYOUT
LUTRIS_POST_INSTALL_TARGET_HOOKS += LUTRIS_INSTALL_WRAPPER
LUTRIS_POST_INSTALL_TARGET_HOOKS += LUTRIS_PATCH_ROOT_CHECK
LUTRIS_POST_INSTALL_TARGET_HOOKS += LUTRIS_CLEAN_UP_DESKTOP_FILES
LUTRIS_POST_INSTALL_TARGET_HOOKS += LUTRIS_INSTALL_OPENAL_COMPAT
LUTRIS_POST_INSTALL_TARGET_HOOKS += LUTRIS_INSTALL_ICON_FALLBACKS

$(eval $(python-package))
