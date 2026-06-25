################################################################################
#
# yabasanshiro
#
################################################################################

YABASANSHIRO_VERSION = a40dace1ae0af3ebd45848549fdf396f40e3930f
YABASANSHIRO_SITE = https://github.com/sydarn/yabause.git
YABASANSHIRO_SITE_METHOD = git
YABASANSHIRO_GIT_SUBMODULES = YES
YABASANSHIRO_LICENSE = GPLv2
YABASANSHIRO_LICENSE_FILES = yabause/COPYING
YABASANSHIRO_DEPENDENCIES = boost host-pkgconf json-for-modern-cpp libchdr libpng openal sdl2 zlib
YABASANSHIRO_SUBDIR = yabause
YABASANSHIRO_SUPPORTS_IN_SOURCE_BUILD = NO

YABASANSHIRO_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
YABASANSHIRO_CONF_OPTS += -DCMAKE_INSTALL_PREFIX=/usr
YABASANSHIRO_CONF_OPTS += -DBoost_NO_BOOST_CMAKE=ON
YABASANSHIRO_CONF_OPTS += -DYAB_PORTS=retro_arena
YABASANSHIRO_CONF_OPTS += -DYAB_WANT_ARM7=ON
YABASANSHIRO_CONF_OPTS += -DYAB_WANT_DYNAREC_DEVMIYAX=ON
YABASANSHIRO_CONF_OPTS += -DYAB_WANT_OPENAL=ON
YABASANSHIRO_CONF_OPTS += -DYAB_WANT_OPENGL=ON
YABASANSHIRO_CONF_OPTS += -DYAB_USE_SCSP2=OFF
YABASANSHIRO_CONF_OPTS += -DYAB_USE_SSF=ON
YABASANSHIRO_CONF_OPTS += -DWEB_INTERFACE=OFF
YABASANSHIRO_CONF_OPTS += -DUSE_EGL=ON
YABASANSHIRO_CONF_OPTS += -DUSE_OPENGL=OFF
YABASANSHIRO_CONF_OPTS += -DBIN2C_EXECUTABLE=$(@D)/bin2c_host
YABASANSHIRO_CONF_OPTS += -DM68KMAKE_EXECUTABLE=$(@D)/m68kmake_host
YABASANSHIRO_CONF_OPTS += -DOPENGL_INCLUDE_DIR=$(STAGING_DIR)/usr/include
YABASANSHIRO_CONF_OPTS += -DOPENGL_opengl_LIBRARY=$(STAGING_DIR)/usr/lib/libGLESv2.so
YABASANSHIRO_CONF_OPTS += -DOPENGL_glx_LIBRARY=$(STAGING_DIR)/usr/lib/libEGL.so
YABASANSHIRO_CONF_OPTS += -DOPENGLES_INCLUDE_DIR=$(STAGING_DIR)/usr/include
YABASANSHIRO_CONF_OPTS += -DOPENGLES2_INCLUDE_DIR=$(STAGING_DIR)/usr/include
YABASANSHIRO_CONF_OPTS += -DOPENGLES_gl2_LIBRARY=$(STAGING_DIR)/usr/lib/libGLESv2.so

define YABASANSHIRO_FIX_CMAKE_MINIMUM
	find $(@D) -type f -name CMakeLists.txt -exec \
		$(SED) 's/^[[:space:]]*cmake_minimum_required.*$$/cmake_minimum_required(VERSION 3.5)/' {} +
endef
YABASANSHIRO_POST_PATCH_HOOKS += YABASANSHIRO_FIX_CMAKE_MINIMUM

define YABASANSHIRO_BUILD_HOST_TOOLS
	$(HOSTCC) $(@D)/yabause/src/retro_arena/nanogui-sdl/resources/bin2c.c -o $(@D)/bin2c_host
	$(HOSTCC) $(@D)/yabause/src/musashi/m68kmake.c -o $(@D)/m68kmake_host
endef
YABASANSHIRO_PRE_CONFIGURE_HOOKS += YABASANSHIRO_BUILD_HOST_TOOLS

define YABASANSHIRO_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/yabause/buildroot-build/src/libyabause.so \
		$(TARGET_DIR)/usr/lib/libyabause.so
	$(INSTALL) -D -m 0755 $(@D)/yabause/buildroot-build/src/retro_arena/yabasanshiro \
		$(TARGET_DIR)/usr/bin/yabasanshiro
	$(INSTALL) -D -m 0644 $(@D)/yabause/src/android/app/src/main/web_hi_res_512.png \
		$(TARGET_DIR)/usr/share/icons/hicolor/512x512/apps/yabasanshiro.png
endef

$(eval $(cmake-package))
