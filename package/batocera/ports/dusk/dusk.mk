################################################################################
#
# dusk
#
################################################################################

DUSK_VERSION = f5642f307384bd4b7b7a09f690e391152445c815
DUSK_SITE = https://github.com/TwilitRealm/dusk.git
DUSK_SITE_METHOD = git
DUSK_GIT_SUBMODULES = YES
DUSK_LICENSE = MIT
DUSK_LICENSE_FILE = LICENSE.md
DUSK_SUPPORTS_IN_SOURCE_BUILD = NO
DUSK_INSTALL_STAGING = NO

DUSK_TRACY_VERSION = a64b9a20294d59421a2f57aeca3c6383d8c48169
DUSK_TRACY_SOURCE = $(DUSK_TRACY_VERSION).tar.gz
DUSK_EXTRA_DOWNLOADS += https://github.com/wolfpld/tracy/archive/$(DUSK_TRACY_SOURCE)

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
DUSK_CONF_OPTS += -DCMAKE_SKIP_RPATH=ON
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
DUSK_CONF_OPTS += -DFETCHCONTENT_SOURCE_DIR_TRACY=$(@D)/buildroot-fetchcontent/tracy

define DUSK_EXTRACT_TRACY
	mkdir -p $(@D)/buildroot-fetchcontent/tracy
	$(call suitable-extractor,$(DUSK_TRACY_SOURCE)) $(DUSK_DL_DIR)/$(DUSK_TRACY_SOURCE) | \
		$(TAR) --strip-components=1 -C $(@D)/buildroot-fetchcontent/tracy $(TAR_OPTIONS) -
endef
DUSK_POST_EXTRACT_HOOKS += DUSK_EXTRACT_TRACY

define DUSK_FIX_DAWN_WAYLAND_SURFACE_CHECK
	$(SED) '/case Surface::Type::WaylandSurface:/,/VkWaylandSurfaceCreateInfoKHR/ s/InstanceExt::XlibSurface/InstanceExt::WaylandSurface/' \
		$(@D)/buildroot-build/_deps/dawn-src/src/dawn/native/vulkan/SwapChainVk.cpp
endef
DUSK_POST_CONFIGURE_HOOKS += DUSK_FIX_DAWN_WAYLAND_SURFACE_CHECK

define DUSK_FIX_DAWN_ABSEIL_BMI2_INCLUDE
	$(SED) 's|#include <bmi2intrin.h>|#include <x86gprintrin.h>|' \
		$(@D)/buildroot-build/_deps/dawn-src/third_party/abseil-cpp/absl/container/internal/raw_hash_set.h
endef
DUSK_POST_CONFIGURE_HOOKS += DUSK_FIX_DAWN_ABSEIL_BMI2_INCLUDE

define DUSK_FIX_DAWN_ITYP_ARRAY_EQUALITY
	$(SED) '/constexpr bool operator==(const array<Index, Value, Size>& other) const = default;/c\    constexpr bool operator==(const array<Index, Value, Size>& other) const requires requires(const Value& lhs, const Value& rhs) { lhs == rhs; } { return static_cast<const Base&>(*this) == static_cast<const Base&>(other); }' \
		$(@D)/buildroot-build/_deps/dawn-src/src/dawn/common/ityp_array.h
endef
DUSK_POST_CONFIGURE_HOOKS += DUSK_FIX_DAWN_ITYP_ARRAY_EQUALITY

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
