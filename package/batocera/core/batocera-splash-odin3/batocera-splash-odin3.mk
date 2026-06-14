################################################################################
#
# batocera-splash-odin3
#
################################################################################

BATOCERA_SPLASH_ODIN3_VERSION = 1.0
BATOCERA_SPLASH_ODIN3_SOURCE =
BATOCERA_SPLASH_ODIN3_DEPENDENCIES = batocera-splash

BATOCERA_SPLASH_ODIN3_TGVERSION = $(BATOCERA_SYSTEM_VERSION) $(BATOCERA_SYSTEM_DATE)

ifeq ($(BR2_PACKAGE_BATOCERA_SPLASH_MPV),y)
BATOCERA_SPLASH_ODIN3_POST_INSTALL_TARGET_HOOKS += BATOCERA_SPLASH_ODIN3_INSTALL_BOOT_LOGO
BATOCERA_SPLASH_ODIN3_POST_INSTALL_TARGET_HOOKS += BATOCERA_SPLASH_ODIN3_INSTALL_VIDEO
else
BATOCERA_SPLASH_ODIN3_POST_INSTALL_TARGET_HOOKS += BATOCERA_SPLASH_ODIN3_INSTALL_IMAGE
endif

define BATOCERA_SPLASH_ODIN3_INSTALL_BOOT_LOGO
    mkdir -p $(TARGET_DIR)/usr/share/batocera/splash
    cp "$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-splash-odin3/images/logo.png" \
        "$(TARGET_DIR)/usr/share/batocera/splash/boot-logo.png"
    cp "$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-splash-odin3/images/logo-480p.png" \
        "$(TARGET_DIR)/usr/share/batocera/splash/boot-logo-4x3.png"
endef

define BATOCERA_SPLASH_ODIN3_INSTALL_VIDEO
    mkdir -p $(TARGET_DIR)/usr/share/batocera/splash
    cp "$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-splash-odin3/videos/splash.mp4" \
        "$(TARGET_DIR)/usr/share/batocera/splash/splash.mp4"
endef

define BATOCERA_SPLASH_ODIN3_INSTALL_IMAGE
    mkdir -p $(TARGET_DIR)/usr/share/batocera/splash
    convert "$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-splash-odin3/images/logo.png" -fill white -pointsize 30 -annotate +50+1020 "$(BATOCERA_SPLASH_ODIN3_TGVERSION)" "$(TARGET_DIR)/usr/share/batocera/splash/logo-version.png"
    convert "$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-splash-odin3/images/logo-3-2-480-rotate.png" -fill white -pointsize 15 -annotate 270x270+300+440 "$(BATOCERA_SPLASH_ODIN3_TGVERSION)" "$(TARGET_DIR)/usr/share/batocera/splash/logo-version-320x480.png"
    convert "$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-splash-odin3/images/logo-16-9-480-rotate.png" -fill white -pointsize 20 -annotate 270x270+440+814 "$(BATOCERA_SPLASH_ODIN3_TGVERSION)" "$(TARGET_DIR)/usr/share/batocera/splash/logo-version-480x854.png"
    convert "$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-splash-odin3/images/logo-480p.png" -fill white -pointsize 20 -annotate +40+440 "$(BATOCERA_SPLASH_ODIN3_TGVERSION)" "$(TARGET_DIR)/usr/share/batocera/splash/logo-version-640x480.png"
    convert "$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-splash-odin3/images/logo-240.png" -fill white -pointsize 15 -annotate +20+220 "$(BATOCERA_SPLASH_ODIN3_TGVERSION)" "$(TARGET_DIR)/usr/share/batocera/splash/logo-version-320x240.png"
    convert "$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-splash-odin3/images/logo-480-dmg.png" -fill white -pointsize 20 -annotate +40+440 "$(BATOCERA_SPLASH_ODIN3_TGVERSION)" "$(TARGET_DIR)/usr/share/batocera/splash/logo-version-640x480-dmg.png"
endef

$(eval $(generic-package))
