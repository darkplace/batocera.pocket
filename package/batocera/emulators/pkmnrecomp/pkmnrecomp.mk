################################################################################
#
# pkmnrecomp — gen1recomp + Gen2Recomped ARM64 AppImages
#
################################################################################

PKMNRECOMP_VERSION = 0.1.99
PKMNRECOMP_GEN2_VERSION = 0.7.10
PKMNRECOMP_SITE = https://github.com/bryanthaboi/gen1recomp/releases/download/v$(PKMNRECOMP_VERSION)
PKMNRECOMP_SOURCE = gen1recomp-$(PKMNRECOMP_VERSION)-linux-arm64.AppImage
PKMNRECOMP_GEN2_SOURCE = Gen2Recomped-$(PKMNRECOMP_GEN2_VERSION)-linux-arm64.AppImage
PKMNRECOMP_EXTRA_DOWNLOADS = \
	https://github.com/UNDERdecoded/Gen2Recomped/releases/download/v$(PKMNRECOMP_GEN2_VERSION)/$(PKMNRECOMP_GEN2_SOURCE)

PKMNRECOMP_LICENSE = Custom
PKMNRECOMP_STRIP = NO
PKMNRECOMP_TOOLCHAIN = manual
PKMNRECOMP_DEPENDENCIES = sdl2 es-theme-carbon

define PKMNRECOMP_EXTRACT_CMDS
	cp $(PKMNRECOMP_DL_DIR)/$(PKMNRECOMP_SOURCE) $(@D)/gen1recomp.AppImage
	cp $(PKMNRECOMP_DL_DIR)/$(PKMNRECOMP_GEN2_SOURCE) $(@D)/gen2recomp.AppImage
endef

define PKMNRECOMP_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/pkmnrecomp
	$(INSTALL) -m 0755 $(@D)/gen1recomp.AppImage \
		$(TARGET_DIR)/usr/share/pkmnrecomp/gen1recomp.AppImage
	$(INSTALL) -m 0755 $(@D)/gen2recomp.AppImage \
		$(TARGET_DIR)/usr/share/pkmnrecomp/gen2recomp.AppImage
	$(INSTALL) -m 0755 $(PKMNRECOMP_PKGDIR)/pkmnrecomp \
		$(TARGET_DIR)/usr/bin/pkmnrecomp
	mkdir -p $(TARGET_DIR)/usr/share/evmapy
	$(INSTALL) -m 0644 $(PKMNRECOMP_PKGDIR)/pkmnrecomp.keys \
		$(TARGET_DIR)/usr/share/evmapy/pkmnrecomp.keys
	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/roms/pkmnrecomp/mods/gen1
	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/roms/pkmnrecomp/mods/gen2
	mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/roms/pkmnrecomp/mods/optional
	$(INSTALL) -m 0644 $(PKMNRECOMP_PKGDIR)/files/_info.txt \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/pkmnrecomp/_info.txt
	$(INSTALL) -m 0644 $(PKMNRECOMP_PKGDIR)/files/README.txt \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/pkmnrecomp/README.txt
	$(INSTALL) -m 0644 $(PKMNRECOMP_PKGDIR)/files/mods-optional-README.txt \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/pkmnrecomp/mods/optional/README.txt
	cp -a $(PKMNRECOMP_PKGDIR)/files/mods/batocera-handheld \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/pkmnrecomp/mods/gen1/batocera-handheld
	cp -a $(PKMNRECOMP_PKGDIR)/files/mods/batocera-handheld \
		$(TARGET_DIR)/usr/share/batocera/datainit/roms/pkmnrecomp/mods/gen2/batocera-handheld
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/background
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/consoles
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/controllers
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/layouts
	ln -snf gb.jpg $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/background/pkmnrecomp.jpg
	ln -snf gb.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/consoles/pkmnrecomp.png
	ln -snf gb.svg $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/controllers/pkmnrecomp.svg
	ln -snf gb.svg $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/pkmnrecomp.svg
	ln -snf gb.xml $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/layouts/pkmnrecomp.xml
endef

$(eval $(generic-package))
