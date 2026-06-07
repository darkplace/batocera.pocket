################################################################################
#
# EKA2L1
#
################################################################################
# Dirty version and repo while:
# -fixing gcc13
# - upstreaming needed changes (wayland, ffmpeg, gles)
EKA2L1_VERSION = 22fe6c97cead08cb8ea630c47789adec9f2b4246
EKA2L1_SITE = https://github.com/rtissera/EKA2L1.git
EKA2L1_SITE_METHOD=git
EKA2L1_GIT_SUBMODULES=YES
EKA2L1_DL_ENV += GIT_TERMINAL_PROMPT=0
EKA2L1_LICENSE = GPLv2
EKA2L1_DEPENDENCIES = boost qt6base qt6multimedia qt6svg

EKA2L1_SUPPORTS_IN_SOURCE_BUILD = NO

EKA2L1_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
EKA2L1_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
EKA2L1_CONF_OPTS += -DBUILD_STATIC_LIBS=ON
EKA2L1_CONF_OPTS += -DEKA2L1_ENABLE_SCRIPTING_ABILITY=OFF
EKA2L1_CONF_OPTS += -DEKA2L1_BUILD_TOOLS=OFF
EKA2L1_CONF_OPTS += -DEKA2L1_BUILD_TESTS=OFF
EKA2L1_CONF_OPTS += -DEKA2L1_USE_SYSTEM_FFMPEG=ON
EKA2L1_CONF_OPTS += -DENABLE_PROGRAMS=OFF # for mbedtls

define EKA2L1_SKIP_DEAD_SUBMODULES
	mkdir -p $(EKA2L1_DL_DIR)/git
	cd $(EKA2L1_DL_DIR)/git && \
		git init . && \
		git config submodule.ext-boost.update none && \
		git config submodule.dynarmic-android.update none
endef
EKA2L1_PRE_DOWNLOAD_HOOKS += EKA2L1_SKIP_DEAD_SUBMODULES

ifneq ($(BR2_x86_64),y)
EKA2L1_CONF_OPTS += -DEKA2L1_UNIX_USE_X11=OFF
EKA2L1_CONF_OPTS += -DEKA2L1_UNIX_USE_WAYLAND=ON
endif

define EKA2L1_INSTALL_TARGET_CMDS
    mkdir -p $(TARGET_DIR)/usr/eka2l1
    $(TARGET_STRIP) $(@D)/buildroot-build/bin/eka2l1_qt
    cp -R $(@D)/buildroot-build/bin/* \
                $(TARGET_DIR)/usr/eka2l1/
endef


$(eval $(cmake-package))
