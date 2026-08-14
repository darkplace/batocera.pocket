################################################################################
#
# shadps4-qtlauncher
#
################################################################################

# v224 tag is gone; pin to current QtLauncher release matching 2026-08-08 tip.
SHADPS4_QTLAUNCHER_VERSION = a12b988ef35d98f2222a614c05498b27fef87121
SHADPS4_QTLAUNCHER_SITE = https://github.com/shadps4-emu/shadps4-qtlauncher
SHADPS4_QTLAUNCHER_SITE_METHOD = git
SHADPS4_QTLAUNCHER_GIT_SUBMODULES = YES

SHADPS4_QTLAUNCHER_LICENSE = GPL-2.0+
SHADPS4_QTLAUNCHER_LICENSE_FILES = LICENSE
SHADPS4_QTLAUNCHER_SUPPORTS_IN_SOURCE_BUILD = NO

SHADPS4_QTLAUNCHER_DEPENDENCIES = host-clang openssl qt6base qt6multimedia qt6tools sdl3 vulkan-headers

ifeq ($(BR2_PACKAGE_BATOCERA_WAYLAND),y)
SHADPS4_QTLAUNCHER_DEPENDENCIES += qt6wayland
endif

SHADPS4_QTLAUNCHER_CMAKE_BACKEND = ninja
SHADPS4_QTLAUNCHER_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
SHADPS4_QTLAUNCHER_CONF_OPTS += -DCMAKE_INSTALL_PREFIX=/usr
SHADPS4_QTLAUNCHER_CONF_OPTS += -DENABLE_UPDATER=OFF
SHADPS4_QTLAUNCHER_CONF_OPTS += -DENABLE_TRANSLATIONS=OFF

ifeq ($(BR2_x86_64),y)
SHADPS4_QTLAUNCHER_CONF_OPTS += -DCMAKE_C_COMPILER=$(HOST_DIR)/bin/clang
SHADPS4_QTLAUNCHER_CONF_OPTS += -DCMAKE_CXX_COMPILER=$(HOST_DIR)/bin/clang++
SHADPS4_QTLAUNCHER_CONF_OPTS += -DCMAKE_EXE_LINKER_FLAGS="-lm -lstdc++"
endif

define SHADPS4_QTLAUNCHER_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/bin/shadps4
	$(INSTALL) -m 0755 $(@D)/buildroot-build/shadPS4QtLauncher $(TARGET_DIR)/usr/bin/shadps4/
	ln -snf shadPS4QtLauncher $(TARGET_DIR)/usr/bin/shadps4/shadps4-qtlauncher
endef

$(eval $(cmake-package))
