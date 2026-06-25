################################################################################
#
# batocera-desktopapps
#
################################################################################

BATOCERA_DESKTOPAPPS_VERSION = 1.1
BATOCERA_DESKTOPAPPS_SOURCE =

BATOCERA_DESKTOPAPPS_PKGDIR = \
    $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-desktopapps

# Base files
BATOCERA_DESKTOPAPPS_SCRIPTS = filemanagerlauncher ftoolbox batocera-config-gpu-wrapper
BATOCERA_DESKTOPAPPS_APPS    = xterm.desktop m3u-builder.desktop win9x-tool.desktop
BATOCERA_DESKTOPAPPS_ICONS   = m3u-builder.png win9x-tool.png
BATOCERA_DESKTOPAPPS_TOOLBOX =
BATOCERA_DESKTOPAPPS_ACTIONS = system.md5sum.desktop multidisc.toolbox.m3ufromdir.desktop
BATOCERA_DESKTOPAPPS_STALE_APPS =
BATOCERA_DESKTOPAPPS_STALE_ICONS =

#file-roller integration for pcmanfm - open/list archives
BATOCERA_DESKTOPAPPS_APPS    += file-roller-mimics.desktop

## System depended applets

# wiimote
BATOCERA_DESKTOPAPPS_APPS    += xwiishowir.desktop
BATOCERA_DESKTOPAPPS_ICONS   += xwiishowir.png

# pcsx2
ifeq ($(BR2_PACKAGE_PCSX2),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-pcsx2
  BATOCERA_DESKTOPAPPS_APPS    += pcsx2-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += pcsx2.png
endif

# aethersx2
ifeq ($(BR2_PACKAGE_AETHERSX2),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-aethersx2
  BATOCERA_DESKTOPAPPS_APPS    += aethersx2-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += aethersx2.png
endif

# armsx2
ifeq ($(BR2_PACKAGE_ARMSX2),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-armsx2
  BATOCERA_DESKTOPAPPS_APPS    += armsx2-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += armsx2.png
endif

# armsx2-masies
ifeq ($(BR2_PACKAGE_ARMSX2_MASIES),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-armsx2-masies
  BATOCERA_DESKTOPAPPS_APPS    += armsx2-masies-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += armsx2-masies.png
endif

# gopher64
ifeq ($(BR2_PACKAGE_GOPHER64),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-gopher64
  BATOCERA_DESKTOPAPPS_APPS    += gopher64-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += gopher64.png
endif

# dolphin
ifeq ($(BR2_PACKAGE_DOLPHIN_EMU)$(BR2_PACKAGE_XORG7),yy)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-dolphin
  BATOCERA_DESKTOPAPPS_APPS    += dolphin-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += dolphin.png
endif

# duckstation
ifeq ($(BR2_PACKAGE_DUCKSTATION),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-duckstation
  BATOCERA_DESKTOPAPPS_APPS    += duckstation-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += duckstation.png
endif

# retroarch
ifeq ($(BR2_PACKAGE_RETROARCH),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-retroarch
  BATOCERA_DESKTOPAPPS_APPS    += retroarch-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += retroarch.png
endif

# ppsspp
ifeq ($(BR2_PACKAGE_PPSSPP),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-ppsspp
  BATOCERA_DESKTOPAPPS_APPS    += ppsspp-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += ppsspp.png
endif

# flycast
ifeq ($(BR2_PACKAGE_FLYCAST),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-flycast
  BATOCERA_DESKTOPAPPS_APPS    += flycast-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += flycast.png
endif

# scummvm
ifeq ($(BR2_PACKAGE_SCUMMVM),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-scummvm
  BATOCERA_DESKTOPAPPS_APPS    += scummvm-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += scummvm.png
endif

# azahar
ifeq ($(BR2_PACKAGE_AZAHAR),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-azahar
  BATOCERA_DESKTOPAPPS_APPS    += azahar-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += azahar.png
endif

# rpcs3
ifeq ($(BR2_PACKAGE_RPCS3),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-rpcs3
  BATOCERA_DESKTOPAPPS_APPS    += rpcs3-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += rpcs3.png
endif

# cemu
ifeq ($(BR2_PACKAGE_CEMU),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-cemu
  BATOCERA_DESKTOPAPPS_APPS    += cemu-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += cemu.png
endif

# model2emu
ifeq ($(BR2_PACKAGE_MODEL2EMU),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-model2emu
  BATOCERA_DESKTOPAPPS_APPS    += model2emu-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += model2emu.png
endif

# 86Box
ifeq ($(BR2_PACKAGE_86BOX),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += 86Box.sh
  BATOCERA_DESKTOPAPPS_APPS    += 86box.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += 86box.png
endif

# flatpak
ifeq ($(BR2_PACKAGE_BAUH),y)
  BATOCERA_DESKTOPAPPS_APPS    += flatpak-config.desktop
endif

# steam
ifneq ($(filter y,$(BR2_PACKAGE_BATOCERA_STEAM) $(BR2_PACKAGE_BATOCERA_STEAM_AARCH64)),)
  BATOCERA_DESKTOPAPPS_APPS    += steam.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += steam.png
endif

# heroic
ifeq ($(BR2_PACKAGE_HEROIC),y)
  BATOCERA_DESKTOPAPPS_APPS    += heroic.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += heroic.png
endif

# n64 recomp launcher
ifeq ($(BR2_PACKAGE_N64RECOMP_LAUNCHER),y)
  BATOCERA_DESKTOPAPPS_APPS    += n64recomp-launcher.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += n64recomp-launcher.png
endif

# bundled desktop apps
ifeq ($(BR2_PACKAGE_BATOCERA_APPS),y)
  BATOCERA_DESKTOPAPPS_APPS    += vacuumtube.desktop
  BATOCERA_DESKTOPAPPS_APPS    += chrome.desktop
  BATOCERA_DESKTOPAPPS_APPS    += firefox.desktop
  BATOCERA_DESKTOPAPPS_APPS    += parsec.desktop
  BATOCERA_DESKTOPAPPS_APPS    += geforcenow.desktop
  BATOCERA_DESKTOPAPPS_APPS    += greenlight.desktop
  BATOCERA_DESKTOPAPPS_APPS    += moonlight.desktop
  BATOCERA_DESKTOPAPPS_APPS    += chiaki.desktop
  BATOCERA_DESKTOPAPPS_APPS    += peazip.desktop
  BATOCERA_DESKTOPAPPS_APPS    += protonupqt.desktop
  BATOCERA_DESKTOPAPPS_APPS    += steamrommanager.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += vacuumtube.png
  BATOCERA_DESKTOPAPPS_ICONS   += chrome.png
  BATOCERA_DESKTOPAPPS_ICONS   += firefox.png
  BATOCERA_DESKTOPAPPS_ICONS   += parsec.png
  BATOCERA_DESKTOPAPPS_ICONS   += geforcenow.png
  BATOCERA_DESKTOPAPPS_ICONS   += greenlight.png
  BATOCERA_DESKTOPAPPS_ICONS   += moonlight.png
  BATOCERA_DESKTOPAPPS_ICONS   += chiaki.png
  BATOCERA_DESKTOPAPPS_ICONS   += peazip.png
  BATOCERA_DESKTOPAPPS_ICONS   += protonupqt.png
  BATOCERA_DESKTOPAPPS_ICONS   += steam-rom-manager.png
endif

# bundled aarch64 desktop apps
ifeq ($(BR2_PACKAGE_BATOCERA_APPS_AARCH64),y)
  BATOCERA_DESKTOPAPPS_APPS    += vacuumtube.desktop
  BATOCERA_DESKTOPAPPS_APPS    += brave.desktop
  BATOCERA_DESKTOPAPPS_APPS    += firefox.desktop
  BATOCERA_DESKTOPAPPS_APPS    += peazip.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += vacuumtube.png
  BATOCERA_DESKTOPAPPS_ICONS   += firefox.png
  BATOCERA_DESKTOPAPPS_ICONS   += peazip.png
  BATOCERA_DESKTOPAPPS_STALE_APPS  += geforcenow.desktop
  BATOCERA_DESKTOPAPPS_STALE_ICONS += geforcenow.png
endif

# waydroid
ifeq ($(BR2_PACKAGE_WAYDROID),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += Waydroid.sh
  BATOCERA_DESKTOPAPPS_APPS    += waydroid.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += waydroid.png
endif

# Arch Plasma LXC
ifeq ($(BR2_PACKAGE_BATOCERA_ARCH_PLASMA_LXC),y)
  BATOCERA_DESKTOPAPPS_APPS    += arch-plasma-lxc.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += arch-plasma-lxc.svg
endif

# yuzu
ifeq ($(BR2_PACKAGE_YUZU),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-yuzu
  BATOCERA_DESKTOPAPPS_APPS    += yuzu-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += yuzu.png
endif

# citron
ifeq ($(BR2_PACKAGE_CITRON),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-citron
  BATOCERA_DESKTOPAPPS_APPS    += citron-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += citron.png
endif

# eden
ifeq ($(BR2_PACKAGE_EDEN),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-eden
  BATOCERA_DESKTOPAPPS_APPS    += eden-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += eden.png
endif

# ryujinx
ifeq ($(BR2_PACKAGE_RYUJINX),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-ryujinx
  BATOCERA_DESKTOPAPPS_APPS    += ryujinx-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += ryujinx.png
endif

# touchHLE
ifeq ($(BR2_PACKAGE_TOUCHHLE),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += touchHLE.sh
  BATOCERA_DESKTOPAPPS_APPS    += touchhle.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += touchhle.png
endif

# batocera-wine-tools
ifeq ($(BR2_PACKAGE_BATOCERA_WINE),y)
  BATOCERA_DESKTOPAPPS_APPS    += wine-tools.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += wine-tools.png
endif

# melonds
ifeq ($(BR2_PACKAGE_DEMUL),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-melonds
  BATOCERA_DESKTOPAPPS_APPS    += melonds-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += melonds.png
endif

# xenia
ifeq ($(BR2_PACKAGE_XENIA),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-xenia
  BATOCERA_DESKTOPAPPS_APPS    += xenia-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += xenia.png
endif

# xenia-canary
ifeq ($(BR2_PACKAGE_XENIA_CANARY),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-xenia-canary
  BATOCERA_DESKTOPAPPS_APPS    += xenia-canary-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += xenia-canary.png
endif

# xenia-edge
ifeq ($(BR2_PACKAGE_XENIA_EDGE),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-xenia-edge
  BATOCERA_DESKTOPAPPS_APPS    += xenia-edge-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += xenia-edge.png
endif

# vita3k
ifeq ($(BR2_PACKAGE_VITA3K),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-vita3k
  BATOCERA_DESKTOPAPPS_APPS    += vita3k-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += vita3k.png
endif

# play!
ifeq ($(BR2_PACKAGE_PLAY),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-play
  BATOCERA_DESKTOPAPPS_APPS    += play-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += play.png
endif

# shadPS4
ifeq ($(BR2_PACKAGE_SHADPS4),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-shadps4
  BATOCERA_DESKTOPAPPS_APPS    += shadps4-config.desktop
  BATOCERA_DESKTOPAPPS_ICONS   += shadps4.png
endif

# lindbergh loader
ifeq ($(BR2_PACKAGE_LINDBERGH_LOADER),y)
  BATOCERA_DESKTOPAPPS_SCRIPTS += batocera-config-lindbergh
endif

## Context Menu Actions

# wine
ifeq ($(BR2_PACKAGE_WINE_TKG),y)
  BATOCERA_DESKTOPAPPS_TOOLBOX += wine.toolbox
  BATOCERA_DESKTOPAPPS_ACTIONS += wine.toolbox.configit.desktop
  BATOCERA_DESKTOPAPPS_ACTIONS += wine.toolbox.wsquashfs.desktop
  BATOCERA_DESKTOPAPPS_ACTIONS += wine.toolbox.symlinkprefix.desktop
  BATOCERA_DESKTOPAPPS_ACTIONS += wine.toolbox.listprefix.desktop
  BATOCERA_DESKTOPAPPS_ACTIONS += wine.toolbox.folder2autorun.desktop
  BATOCERA_DESKTOPAPPS_ACTIONS += wine.toolbox.file2autorun.desktop
  BATOCERA_DESKTOPAPPS_ACTIONS += wine.toolbox.extract.desktop
  BATOCERA_DESKTOPAPPS_ACTIONS += wine.toolbox.steam-shortcut.desktop
endif

ifeq ($(BR2_PACKAGE_BATOCERA_APPS_AARCH64),y)
define BATOCERA_DESKTOPAPPS_INSTALL_AARCH64_ICONS
	$(INSTALL) -D -m 0644 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/batocera-apps-aarch64/images/brave.png \
		$(TARGET_DIR)/usr/share/icons/batocera/brave.png
endef
endif

define BATOCERA_DESKTOPAPPS_INSTALL_TARGET_CMDS
	$(foreach f,$(BATOCERA_DESKTOPAPPS_STALE_APPS),\
		rm -f $(TARGET_DIR)/usr/share/applications/$(f)$(sep))
	$(foreach f,$(BATOCERA_DESKTOPAPPS_STALE_ICONS),\
		rm -f $(TARGET_DIR)/usr/share/icons/batocera/$(f)$(sep))

	# scripts (Install as executable 0755)
	$(foreach f,$(BATOCERA_DESKTOPAPPS_SCRIPTS),\
		$(INSTALL) -D -m 0755 $(BATOCERA_DESKTOPAPPS_PKGDIR)/scripts/$(f) \
			$(TARGET_DIR)/usr/bin/$(f)$(sep))

	# apps (Install as data 0644)
	$(foreach f,$(BATOCERA_DESKTOPAPPS_APPS),\
		$(INSTALL) -D -m 0644 $(BATOCERA_DESKTOPAPPS_PKGDIR)/apps/$(f) \
			$(TARGET_DIR)/usr/share/applications/$(f)$(sep))

	# default-mime types
	$(INSTALL) -D -m 0644 $(BATOCERA_DESKTOPAPPS_PKGDIR)/mime/defaults.list \
		$(TARGET_DIR)/usr/share/applications/defaults.list

	# icons
	$(foreach f,$(BATOCERA_DESKTOPAPPS_ICONS),\
		$(INSTALL) -D -m 0644 $(BATOCERA_DESKTOPAPPS_PKGDIR)/icons/$(f) \
			$(TARGET_DIR)/usr/share/icons/batocera/$(f)$(sep))

	$(BATOCERA_DESKTOPAPPS_INSTALL_AARCH64_ICONS)

	# context menu actions
	$(foreach f,$(BATOCERA_DESKTOPAPPS_ACTIONS),\
		$(INSTALL) -D -m 0644 $(BATOCERA_DESKTOPAPPS_PKGDIR)/contextactions/$(f) \
			$(TARGET_DIR)/usr/share/file-manager/actions/$(f)$(sep))

	# toolbox (Install as executable 0755)
	$(foreach f,$(BATOCERA_DESKTOPAPPS_TOOLBOX),\
		$(INSTALL) -D -m 0755 $(BATOCERA_DESKTOPAPPS_PKGDIR)/toolbox/$(f) \
			$(TARGET_DIR)/usr/share/file-manager/actions/toolbox/$(f)$(sep))

	# menu
	$(INSTALL) -D -m 0644 $(BATOCERA_DESKTOPAPPS_PKGDIR)/menu/batocera-applications.menu \
		$(TARGET_DIR)/etc/xdg/menus/batocera-applications.menu
endef

$(eval $(generic-package))
