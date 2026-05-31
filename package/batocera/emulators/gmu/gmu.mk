################################################################################
#
# gmu
#
################################################################################

GMU_VERSION = 3aed18be8a50873ccfb31d2b135b0d22442ded59
GMU_SITE = $(call github,jhe2,gmu,$(GMU_VERSION))
GMU_LICENSE = GPL-2.0
GMU_LICENSE_FILES = COPYING
GMU_DEPENDENCIES = sdl2 sdl2_gfx sdl2_image sqlite mpg123 tremor flac opus opusfile speex ncurses

define GMU_CONFIGURE_CMDS
	cd $(@D) && \
		$(TARGET_CONFIGURE_OPTS) \
		SDL2CONFIG=$(STAGING_DIR)/usr/bin/sdl2-config \
		CFLAGS="$(TARGET_CFLAGS) -fcommon" \
		LFLAGS="$(TARGET_LDFLAGS)" \
		./configure --noauto \
		    --enable=gmu \
		    --enable=medialib \
		    --enable=opus-decoder \
		    --enable=mpg123-decoder \
		    --enable=vorbis-decoder \
		    --enable=flac-decoder \
		    --enable=speex-decoder \
		    --enable=sdl-frontend \
		    --enable=SDL_gfx \
		    --release
endef

define GMU_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)
endef

define GMU_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) DESTDIR=$(TARGET_DIR) PREFIX=/usr install
	$(INSTALL) -D -m 0755 $(GMU_PKGDIR)/scripts/start_gmu.sh $(TARGET_DIR)/usr/bin/start_gmu.sh
	$(INSTALL) -D -m 0644 $(GMU_PKGDIR)/config/gmu.conf $(TARGET_DIR)/usr/share/gmu/batocera/gmu.conf
	$(INSTALL) -D -m 0644 $(GMU_PKGDIR)/config/gmuinput.conf $(TARGET_DIR)/usr/share/gmu/batocera/gmuinput.conf
	$(INSTALL) -D -m 0644 $(GMU_PKGDIR)/config/batocera.keymap $(TARGET_DIR)/usr/etc/gmu/batocera.keymap
	rm -f $(TARGET_DIR)/usr/share/evmapy/music.gmu.keys
	$(INSTALL) -D -m 0755 $(GMU_PKGDIR)/datainit/Start\ Music\ Player.sh \
	    $(TARGET_DIR)/usr/share/batocera/datainit/roms/music/Start\ Music\ Player.sh
	$(INSTALL) -D -m 0644 $(GMU_PKGDIR)/datainit/gamelist.xml \
	    $(TARGET_DIR)/usr/share/batocera/datainit/roms/music/gamelist.xml
endef

$(eval $(generic-package))
