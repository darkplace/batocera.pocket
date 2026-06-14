################################################################################
#
# es-theme-carbon
#
################################################################################
# Version: Commits on May 31, 2026
ES_THEME_CARBON_VERSION = 27e58be2f872866e680d48bedfd008c44ffb001a
ES_THEME_CARBON_SITE = $(call github,suckbluefrog,es-theme-carbon,$(ES_THEME_CARBON_VERSION))

define ES_THEME_CARBON_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon
	cp -r $(@D)/* $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/icons
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos
	$(INSTALL) -D -m 0644 $(ES_THEME_CARBON_PKGDIR)/assets/icons/Steam.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/icons/Steam.png
	$(INSTALL) -D -m 0644 $(ES_THEME_CARBON_PKGDIR)/assets/logos/apps.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/apps.png
	$(INSTALL) -D -m 0644 $(ES_THEME_CARBON_PKGDIR)/assets/logos/internet.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/internet.png
	$(INSTALL) -D -m 0644 $(ES_THEME_CARBON_PKGDIR)/assets/logos/lutris.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/lutris.png
	$(INSTALL) -D -m 0644 $(ES_THEME_CARBON_PKGDIR)/assets/logos/music.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/music.png
	$(INSTALL) -D -m 0644 $(ES_THEME_CARBON_PKGDIR)/assets/logos/tools.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/tools.png
	ln -snf apps.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/apps-w.png
	ln -snf internet.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/internet-w.png
	ln -snf lutris.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/lutris-w.png
	ln -snf music.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/music-w.png
	ln -snf tools.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/tools-w.png
	ln -snf linux.jpg $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/background/apps.jpg
	ln -snf ports.jpg $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/background/music.jpg
	ln -snf ports.jpg $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/background/tools.jpg
	ln -snf linux.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/consoles/apps.png
	ln -snf ports.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/consoles/music.png
	ln -snf ports.png $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/consoles/tools.png
	ln -snf desktop.svg $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/controllers/apps.svg
	ln -snf desktop.svg $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/controllers/lutris.svg
	ln -snf ports.svg $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/controllers/music.svg
	ln -snf ports.svg $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/controllers/tools.svg
	rm -f $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/background/starship.jpg
	rm -f $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/soh.png
	rm -f $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/soh-w.png
	rm -f $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/logos/starship.png
endef

$(eval $(generic-package))
