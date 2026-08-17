################################################################################
#
# batocera-scripts
#
################################################################################

BATOCERA_SCRIPTS_VERSION = 4.5
BATOCERA_SCRIPTS_LICENSE = GPL
BATOCERA_SCRIPTS_DEPENDENCIES = pciutils python-evdev python-pyudev
BATOCERA_SCRIPTS_SOURCE=

BATOCERA_SCRIPTS_PATH = $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/core/batocera-scripts

# mouse type #
ifeq ($(BR2_PACKAGE_XSERVER_XORG_SERVER),y)
  BATOCERA_SCRIPTS_MOUSE_TYPE=xorg
  BATOCERA_SCRIPTS_POST_INSTALL_TARGET_HOOKS += BATOCERA_SCRIPTS_INSTALL_MOUSE
endif

ifeq ($(BR2_PACKAGE_BATOCERA_WAYLAND_SWAY),y)
  BATOCERA_SCRIPTS_MOUSE_TYPE=wayland-sway
  BATOCERA_SCRIPTS_POST_INSTALL_TARGET_HOOKS += BATOCERA_SCRIPTS_INSTALL_MOUSE
endif

ifeq ($(BR2_PACKAGE_BATOCERA_WAYLAND_LABWC),y)
  BATOCERA_SCRIPTS_MOUSE_TYPE=wayland-labwc
  BATOCERA_SCRIPTS_DEPENDENCIES+= wtype
  BATOCERA_SCRIPTS_POST_INSTALL_TARGET_HOOKS += BATOCERA_SCRIPTS_INSTALL_MOUSE
endif

ifeq ($(BR2_PACKAGE_WAYLAND),y)
  BATOCERA_SCRIPTS_DEPENDENCIES += wayland host-wayland
  BATOCERA_SCRIPTS_POST_BUILD_HOOKS += BATOCERA_SCRIPTS_BUILD_NIGHTMODE
  BATOCERA_SCRIPTS_POST_INSTALL_TARGET_HOOKS += BATOCERA_SCRIPTS_INSTALL_NIGHTMODE
endif

###

ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_SM8250)$(BR2_PACKAGE_BATOCERA_TARGET_SM8X50),y)
  BATOCERA_SCRIPTS_POST_INSTALL_TARGET_HOOKS += BATOCERA_SCRIPTS_INSTALL_QCOM
endif

ifeq ($(BR2_PACKAGE_HEROIC),y)
  BATOCERA_SCRIPTS_POST_INSTALL_TARGET_HOOKS += BATOCERA_SCRIPTS_INSTALL_HEROIC_UPDATE_HOOK
endif

ifneq ($(filter y,$(BR2_PACKAGE_LUTRIS) $(BR2_PACKAGE_LUTRIS_APPIMAGE)),)
  BATOCERA_SCRIPTS_POST_INSTALL_TARGET_HOOKS += BATOCERA_SCRIPTS_INSTALL_LUTRIS_UPDATE_HOOK
endif

define BATOCERA_SCRIPTS_INSTALL_TARGET_CMDS
    mkdir -p $(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)
    mkdir -p $(TARGET_DIR)/usr/bin
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/bluetooth/bluezutils.py            $(TARGET_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/ # any variable ?
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/bluetooth/batocera-bluetooth       $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/bluetooth/batocera-bluetooth-agent $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-save-overlay              $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-kodi                      $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-kodilauncher              $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-encode                    $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-padsinfo                  $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-info                      $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-model                     $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-install                   $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-format                    $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-mount                     $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-overclock                 $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-part                      $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-support                   $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-version                   $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-sync                      $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-upgrade                   $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-pocket-github-release     $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-systems                   $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-config                    $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-es-thebezelproject        $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-cores                     $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-wifi                      $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-brightness                $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-temp                      $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-keyboard                  $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-mouse-mode                $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-es-swissknife             $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-store                     $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-autologin                 $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-timezone                  $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-gameforce                 $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-shutdown                  $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-services                  $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-planemode                 $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-switch-screen-checker     $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-switch-screen-checker-delayed     $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-ikemen                    $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-streaming                 $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-n64recomp-update          $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-pcgamingwiki-update       $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-ports-appimage-update     $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-ports-translator          $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-m3u-builder               $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-media-swap                $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-win9x-tool                $(TARGET_DIR)/usr/bin/
    install -m 0644 $(BATOCERA_SCRIPTS_PATH)/rules/80-switch-screen.rules               $(TARGET_DIR)/etc/udev/rules.d
    mkdir -p $(TARGET_DIR)/usr/share/emulationstation/hooks
    ln -sf /usr/bin/batocera-n64recomp-update $(TARGET_DIR)/usr/share/emulationstation/hooks/preupdate-gamelists-n64recomp
    ln -sf /usr/bin/batocera-pcgamingwiki-update $(TARGET_DIR)/usr/share/emulationstation/hooks/preupdate-gamelists-pcgamingwiki
    ln -sf /usr/bin/batocera-ports-appimage-update $(TARGET_DIR)/usr/share/emulationstation/hooks/preupdate-gamelists-ports-appimage
    mkdir -p $(TARGET_DIR)/etc/udev/rules.d
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-amd-tdp                   $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-spinner-calibrator        $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-vulkan                    $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-power-mode                $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-cpu-limit                 $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-gpu-profile               $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-ui-scale                  $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-nightmode                 $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-oled-care                 $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-oled-refresher            $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-oled-idle-helper          $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-es-web-notifier           $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-docker-containers         $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-xtract                    $(TARGET_DIR)/usr/bin/
    ln -sf /usr/bin/batocera-xtract $(TARGET_DIR)/usr/bin/file-roller
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/getLocalXDisplay                   $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/getLocalWaylandDisplay             $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-storage-manager           $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-storage-udev              $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/systemctl                          $(TARGET_DIR)/usr/bin/
    mkdir -p $(TARGET_DIR)/usr/share/batocera/services
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/darkmode                           $(TARGET_DIR)/usr/share/batocera/services/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/oledcare                           $(TARGET_DIR)/usr/share/batocera/services/
    mkdir -p $(TARGET_DIR)/usr/share/batocera/f1-theme
    install -m 0644 $(BATOCERA_SCRIPTS_PATH)/Adwaita-dark.zip                           $(TARGET_DIR)/usr/share/batocera/f1-theme/
endef

define BATOCERA_SCRIPTS_INSTALL_MOUSE
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-mouse.${BATOCERA_SCRIPTS_MOUSE_TYPE} $(TARGET_DIR)/usr/bin/batocera-mouse
endef

define BATOCERA_SCRIPTS_INSTALL_QCOM
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/qcom-fan                           $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-install-internal          $(TARGET_DIR)/usr/bin/
endef

define BATOCERA_SCRIPTS_INSTALL_HEROIC_UPDATE_HOOK
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-heroic-update             $(TARGET_DIR)/usr/bin/
    mkdir -p $(TARGET_DIR)/usr/share/emulationstation/hooks
    ln -sf /usr/bin/batocera-heroic-update $(TARGET_DIR)/usr/share/emulationstation/hooks/preupdate-gamelists-heroic
endef

define BATOCERA_SCRIPTS_INSTALL_LUTRIS_UPDATE_HOOK
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-lutris-update             $(TARGET_DIR)/usr/bin/
    mkdir -p $(TARGET_DIR)/usr/share/emulationstation/hooks
    ln -sf /usr/bin/batocera-lutris-update $(TARGET_DIR)/usr/share/emulationstation/hooks/preupdate-gamelists-lutris
endef

define BATOCERA_SCRIPTS_BUILD_NIGHTMODE
    mkdir -p $(@D)/nightmode
    $(HOST_DIR)/bin/wayland-scanner client-header \
        $(BATOCERA_SCRIPTS_PATH)/protocols/wlr-gamma-control-unstable-v1.xml \
        $(@D)/nightmode/wlr-gamma-control-unstable-v1-client-protocol.h
    $(HOST_DIR)/bin/wayland-scanner private-code \
        $(BATOCERA_SCRIPTS_PATH)/protocols/wlr-gamma-control-unstable-v1.xml \
        $(@D)/nightmode/wlr-gamma-control-unstable-v1-client-protocol.c
    $(HOST_DIR)/bin/wayland-scanner client-header \
        $(BATOCERA_SCRIPTS_PATH)/protocols/wlr-layer-shell-unstable-v1.xml \
        $(@D)/nightmode/wlr-layer-shell-unstable-v1-client-protocol.h
    $(HOST_DIR)/bin/wayland-scanner private-code \
        $(BATOCERA_SCRIPTS_PATH)/protocols/wlr-layer-shell-unstable-v1.xml \
        $(@D)/nightmode/wlr-layer-shell-unstable-v1-client-protocol.c
    $(HOST_DIR)/bin/wayland-scanner client-header \
        $(BATOCERA_SCRIPTS_PATH)/protocols/xdg-shell.xml \
        $(@D)/nightmode/xdg-shell-client-protocol.h
    $(HOST_DIR)/bin/wayland-scanner private-code \
        $(BATOCERA_SCRIPTS_PATH)/protocols/xdg-shell.xml \
        $(@D)/nightmode/xdg-shell-client-protocol.c
    $(TARGET_CC) $(TARGET_CFLAGS) -Wall -Wextra -Werror \
        -I$(@D)/nightmode \
        -o $(@D)/batocera-nightmode-gamma \
        $(BATOCERA_SCRIPTS_PATH)/src/batocera-nightmode-gamma.c \
        $(@D)/nightmode/wlr-gamma-control-unstable-v1-client-protocol.c \
        $(TARGET_LDFLAGS) -lwayland-client
    $(TARGET_CC) $(TARGET_CFLAGS) -Wall -Wextra -Werror \
        -I$(@D)/nightmode \
        -o $(@D)/batocera-nightmode-overlay \
        $(BATOCERA_SCRIPTS_PATH)/src/batocera-nightmode-overlay.c \
        $(@D)/nightmode/wlr-layer-shell-unstable-v1-client-protocol.c \
        $(@D)/nightmode/xdg-shell-client-protocol.c \
        $(TARGET_LDFLAGS) -lwayland-client
endef

define BATOCERA_SCRIPTS_INSTALL_NIGHTMODE
    install -D -m 0755 $(@D)/batocera-nightmode-gamma $(TARGET_DIR)/usr/bin/batocera-nightmode-gamma
    install -D -m 0755 $(@D)/batocera-nightmode-overlay $(TARGET_DIR)/usr/bin/batocera-nightmode-overlay
    install -D -m 0755 $(BATOCERA_SCRIPTS_PATH)/S32nightmode $(TARGET_DIR)/etc/init.d/S32nightmode
    install -D -m 0755 $(BATOCERA_SCRIPTS_PATH)/S33oledcare $(TARGET_DIR)/etc/init.d/S33oledcare
endef

define BATOCERA_SCRIPTS_INSTALL_ROCKCHIP
    mkdir -p $(TARGET_DIR)/usr/bin/
    install -m 0755 $(BATOCERA_SCRIPTS_PATH)/scripts/batocera-rockchip-suspend $(TARGET_DIR)/usr/bin/
endef

$(eval $(generic-package))
