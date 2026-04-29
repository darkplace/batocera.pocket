################################################################################
#
# mangohud
#
################################################################################
# Version: v0.8.3
MANGOHUD_VERSION = 330c42a5956e005a4d102473f5782bb0e3d94b6f
MANGOHUD_SITE =  $(call github,flightlessmango,MangoHud,$(MANGOHUD_VERSION))

MANGOHUD_DEPENDENCIES += host-libcurl host-python-mako host-glslang dbus
MANGOHUD_DEPENDENCIES += json-for-modern-cpp

ifeq ($(BR2_PACKAGE_LIBXKBCOMMON),y)
    MANGOHUD_DEPENDENCIES += libxkbcommon
endif

ifeq ($(BR2_PACKAGE_LIBDRM),y)
    MANGOHUD_DEPENDENCIES += libdrm
endif

ifeq ($(BR2_PACKAGE_XSERVER_XORG_SERVER),y)
    MANGOHUD_DEPENDENCIES += xserver_xorg-server
endif

MANGOHUD_CONF_OPTS = -Dwith_xnvctrl=disabled

ifeq ($(BR2_PACKAGE_XORG7):$(BR2_PACKAGE_LIBGLFW),y:y)
    MANGOHUD_DEPENDENCIES += libglfw
    MANGOHUD_CONF_OPTS += -Dwith_x11=enabled -Dmangoapp=true
else ifeq ($(BR2_PACKAGE_XORG7),y)
    MANGOHUD_CONF_OPTS += -Dwith_x11=enabled -Dmangoapp=false
else
    MANGOHUD_CONF_OPTS += -Dwith_x11=disabled -Dmangoapp=false
endif

ifeq ($(BR2_PACKAGE_BATOCERA_WAYLAND),y)
    MANGOHUD_DEPENDENCIES += wayland
    MANGOHUD_CONF_OPTS += -Dwith_wayland=enabled
else
    MANGOHUD_CONF_OPTS += -Dwith_wayland=disabled
endif

# this is a not nice workaround
# i don't know why meson uses bad ssl certificates and doesn't manage to download them
# use submodule vulkan headers - https://github.com/flightlessmango/MangoHud/issues/968
define MANGOHUD_DWD_DEPENDENCIES
	mkdir -p $(@D)/subprojects/packagecache
	$(HOST_DIR)/bin/curl -L https://github.com/ocornut/imgui/archive/refs/tags/v1.91.6.tar.gz \
        -o $(@D)/subprojects/packagecache/imgui-1.91.6.tar.gz
	$(HOST_DIR)/bin/curl -L https://wrapdb.mesonbuild.com/v2/imgui_1.91.6-3/get_patch \
        -o $(@D)/subprojects/packagecache/imgui_1.91.6-3_patch.zip
	$(HOST_DIR)/bin/curl -L https://github.com/gabime/spdlog/archive/refs/tags/v1.14.1.tar.gz \
        -o $(@D)/subprojects/packagecache/spdlog-1.14.1.tar.gz
	$(HOST_DIR)/bin/curl -L https://wrapdb.mesonbuild.com/v2/spdlog_1.14.1-1/get_patch \
        -o $(@D)/subprojects/packagecache/spdlog_1.14.1-1_patch.zip
	$(HOST_DIR)/bin/curl -L https://github.com/KhronosGroup/Vulkan-Headers/archive/v1.4.346.tar.gz \
        -o $(@D)/subprojects/packagecache/vulkan-headers-1.4.346.tar.gz
	$(HOST_DIR)/bin/curl -L https://github.com/KhronosGroup/Vulkan-Utility-Libraries/archive/v1.4.346.tar.gz \
        -o $(@D)/subprojects/packagecache/vulkan-utility-libraries-1.4.346.tar.gz
	$(HOST_DIR)/bin/curl -L https://github.com/epezent/implot/archive/refs/tags/v0.16.zip \
        -o $(@D)/subprojects/packagecache/implot-0.16.zip
	$(HOST_DIR)/bin/curl -L https://wrapdb.mesonbuild.com/v2/implot_0.16-1/get_patch \
        -o $(@D)/subprojects/packagecache/implot_0.16-1_patch.zip
endef
MANGOHUD_PRE_CONFIGURE_HOOKS += MANGOHUD_DWD_DEPENDENCIES

define MANGOHUD_POST_INSTALL_CLEAN
	rm -f $(TARGET_DIR)/usr/share/man/man1/mangohud.1 \
		$(TARGET_DIR)/usr/share/man/man1/mangoapp.1
endef

MANGOHUD_POST_INSTALL_TARGET_HOOKS = MANGOHUD_POST_INSTALL_CLEAN

$(eval $(meson-package))
