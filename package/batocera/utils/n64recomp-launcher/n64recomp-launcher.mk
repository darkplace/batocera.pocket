################################################################################
#
# n64recomp-launcher
#
################################################################################

N64RECOMP_LAUNCHER_VERSION = 1.70
N64RECOMP_LAUNCHER_SITE = https://github.com/SirDiabo/N64RecompLauncher/releases/download/v$(N64RECOMP_LAUNCHER_VERSION)
N64RECOMP_LAUNCHER_SOURCE = N64RecompLauncher-v$(N64RECOMP_LAUNCHER_VERSION)-Linux-ARM64.zip
N64RECOMP_LAUNCHER_LICENSE = MIT
N64RECOMP_LAUNCHER_STRIP = NO
N64RECOMP_LAUNCHER_DEPENDENCIES = sdl2 es-theme-carbon

define N64RECOMP_LAUNCHER_EXTRACT_CMDS
	mkdir -p $(@D)
	unzip -q -o $(N64RECOMP_LAUNCHER_DL_DIR)/$(N64RECOMP_LAUNCHER_SOURCE) -d $(@D)
endef

define N64RECOMP_LAUNCHER_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/n64recomp-launcher
	$(INSTALL) -m 0644 $(@D)/N64RecompLauncher \
		$(TARGET_DIR)/usr/share/n64recomp-launcher/N64RecompLauncher
	$(INSTALL) -m 0644 $(@D)/libHarfBuzzSharp.so \
		$(TARGET_DIR)/usr/share/n64recomp-launcher/libHarfBuzzSharp.so
	if test -f $(@D)/libSDL2.so; then \
		$(INSTALL) -m 0644 $(@D)/libSDL2.so \
			$(TARGET_DIR)/usr/share/n64recomp-launcher/libSDL2.so; \
	fi
	$(INSTALL) -m 0644 $(@D)/libSkiaSharp.so \
		$(TARGET_DIR)/usr/share/n64recomp-launcher/libSkiaSharp.so
	$(INSTALL) -m 0644 $(@D)/N64RecompLauncher.dll.config \
		$(TARGET_DIR)/usr/share/n64recomp-launcher/N64RecompLauncher.dll.config
	$(INSTALL) -m 0644 $(N64RECOMP_LAUNCHER_PKGDIR)/files/default-settings.json \
		$(TARGET_DIR)/usr/share/n64recomp-launcher/default-settings.json
	$(INSTALL) -m 0755 $(N64RECOMP_LAUNCHER_PKGDIR)/files/n64recomp-launcher \
		$(TARGET_DIR)/usr/bin/n64recomp-launcher
	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/roms/n64recomp/images
	$(INSTALL) -m 0755 $(N64RECOMP_LAUNCHER_PKGDIR)/files/N64\ Recomp\ Launcher.sh \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/n64recomp/N64\ Recomp\ Launcher.sh
	$(INSTALL) -m 0644 $(N64RECOMP_LAUNCHER_PKGDIR)/files/gamelist.xml \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/n64recomp/gamelist.xml
	$(INSTALL) -m 0644 $(N64RECOMP_LAUNCHER_PKGDIR)/files/n64recomp-launcher.png \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/n64recomp/images/n64recomp-launcher.png
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/background
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/consoles
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/controllers
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/layouts
	ln -snf n64.jpg $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/background/n64recomp.jpg
	ln -snf n64.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/consoles/n64recomp.png
	ln -snf n64.svg $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/controllers/n64recomp.svg
	ln -snf n64.svg $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/n64recomp.svg
	ln -snf n64.xml $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/layouts/n64recomp.xml
endef

$(eval $(generic-package))
