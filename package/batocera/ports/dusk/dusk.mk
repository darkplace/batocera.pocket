################################################################################
#
# dusk
#
################################################################################

DUSK_VERSION = 764fc0b96fd39fb1fbd159717b51fd3dfd7f00b4
DUSK_SITE = https://github.com/TwilitRealm/dusk.git
DUSK_SITE_METHOD = git
DUSK_GIT_SUBMODULES = YES
DUSK_LICENSE = MIT
DUSK_LICENSE_FILE = LICENSE
DUSK_SUPPORTS_IN_SOURCE_BUILD = NO
DUSK_INSTALL_STAGING = NO

DUSK_DEPENDENCIES += host-pkgconf host-rustc
DUSK_DEPENDENCIES += sdl3 vulkan-headers vulkan-loader
DUSK_DEPENDENCIES += libcurl freetype zlib libpng alsa-lib pulseaudio dbus udev

ifeq ($(BR2_PACKAGE_HAS_LIBMALI),y)
DUSK_DEPENDENCIES += libmali
endif

DUSK_CONF_ENV += $(PKG_CARGO_ENV)
DUSK_BUILD_ENV += $(PKG_CARGO_ENV)

DUSK_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
DUSK_CONF_OPTS += -DCMAKE_INSTALL_PREFIX=/usr/lib/dusk
DUSK_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
DUSK_CONF_OPTS += -DDUSK_MOVIE_SUPPORT=OFF
DUSK_CONF_OPTS += -DDUSK_ENABLE_UPDATE_CHECKER=OFF
DUSK_CONF_OPTS += -DDUSK_ENABLE_SENTRY_NATIVE=OFF
DUSK_CONF_OPTS += -DAURORA_SDL3_PROVIDER=system
DUSK_CONF_OPTS += -DAURORA_SDL3_LINKAGE=shared
DUSK_CONF_OPTS += -DAURORA_DAWN_PROVIDER=vendor
DUSK_CONF_OPTS += -DAURORA_DAWN_LINKAGE=static
DUSK_CONF_OPTS += -DAURORA_NOD_PROVIDER=vendor
DUSK_CONF_OPTS += -DAURORA_NOD_LINKAGE=static
DUSK_CONF_OPTS += -DRust_CARGO_TARGET=$(RUSTC_TARGET_NAME)

define DUSK_FIX_DAWN_WAYLAND_SURFACE_CHECK
	$(SED) '/case Surface::Type::WaylandSurface:/,/VkWaylandSurfaceCreateInfoKHR/ s/InstanceExt::XlibSurface/InstanceExt::WaylandSurface/' \
		$(@D)/buildroot-build/_deps/dawn-src/src/dawn/native/vulkan/SwapChainVk.cpp
endef
DUSK_POST_CONFIGURE_HOOKS += DUSK_FIX_DAWN_WAYLAND_SURFACE_CHECK

define DUSK_INSTALL_WRAPPER
	$(INSTALL) -D -m 0755 $(DUSK_PKGDIR)/dusk-wrapper \
		$(TARGET_DIR)/usr/bin/dusk
	$(RM) "$(TARGET_DIR)/usr/share/batocera/datainit/roms/ports/Dusk - Twilight Princess.sh"
	$(RM) -r "$(TARGET_DIR)/usr/share/batocera/datainit/roms/ports/dusk"
	$(INSTALL) -D -m 0644 "$(DUSK_PKGDIR)/_info.txt" \
		"$(TARGET_DIR)/usr/share/batocera/datainit/roms/dusk/_info.txt"
	$(INSTALL) -D -m 0644 "$(DUSK_PKGDIR)/gamelist.xml" \
		"$(TARGET_DIR)/usr/share/batocera/datainit/roms/dusk/gamelist.xml"
	$(INSTALL) -D -m 0644 "$(DUSK_PKGDIR)/images/dusk.png" \
		"$(TARGET_DIR)/usr/share/batocera/datainit/roms/dusk/images/dusk-image.png"
	$(INSTALL) -D -m 0644 "$(DUSK_PKGDIR)/images/dusk.png" \
		"$(TARGET_DIR)/usr/share/batocera/datainit/roms/dusk/images/dusk-marquee.png"
	$(INSTALL) -D -m 0644 "$(DUSK_PKGDIR)/images/dusk.png" \
		"$(TARGET_DIR)/usr/share/batocera/datainit/roms/dusk/images/dusk-logo.png"
endef
DUSK_POST_INSTALL_TARGET_HOOKS += DUSK_INSTALL_WRAPPER

$(eval $(cmake-package))
