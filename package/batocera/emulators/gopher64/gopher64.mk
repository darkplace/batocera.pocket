################################################################################
#
# gopher64
#
################################################################################

GOPHER64_VERSION = acf5e08b97d8526e7f25578bdaa202557c42c200
GOPHER64_SITE = https://github.com/gopher64/gopher64.git
GOPHER64_SITE_METHOD = git
GOPHER64_GIT_SUBMODULES = YES
GOPHER64_LICENSE = GPL-3.0+
GOPHER64_LICENSE_FILES = LICENSE
GOPHER64_DEPENDENCIES = host-rustc host-rust-bin host-clang host-cmake host-ninja \
	alsa-lib libdrm mesa3d vulkan-loader

GOPHER64_GCC_VERSION = $(notdir $(firstword $(wildcard $(HOST_DIR)/$(GNU_TARGET_NAME)/include/c++/*)))
GOPHER64_BINDGEN_SYSROOT = $(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot
GOPHER64_BINDGEN_STDLIB = $(HOST_DIR)/$(GNU_TARGET_NAME)/include/c++/$(GOPHER64_GCC_VERSION)
GOPHER64_BINDGEN_STDLIB_TARGET = $(GOPHER64_BINDGEN_STDLIB)/$(GNU_TARGET_NAME)

GOPHER64_CARGO_ENV = \
	BINDGEN_EXTRA_CLANG_ARGS="--sysroot=$(GOPHER64_BINDGEN_SYSROOT) --target=$(RUSTC_TARGET_NAME) -isystem $(GOPHER64_BINDGEN_STDLIB) -isystem $(GOPHER64_BINDGEN_STDLIB_TARGET)" \
	FREETYPE2_INCLUDE_PATH="$(STAGING_DIR)/usr/include/freetype2" \
	GOPHER64_GIT_HASH="$(GOPHER64_VERSION)" \
	PKG_CONFIG_ALLOW_CROSS=1 \
	RUSTFLAGS="-A unpredictable_function_pointer_comparisons -C link-arg=-ldrm -C link-arg=-lgbm -C link-arg=-lasound -C link-arg=-lvulkan"

GOPHER64_CARGO_MODE = $(if $(BR2_ENABLE_DEBUG),debug,release)
GOPHER64_BIN_DIR = target/$(RUSTC_TARGET_NAME)/$(GOPHER64_CARGO_MODE)

define GOPHER64_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/$(GOPHER64_BIN_DIR)/gopher64 \
		$(TARGET_DIR)/usr/bin/gopher64
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/gopher64/config.json \
		$(TARGET_DIR)/usr/share/gopher64/config.json
endef

$(eval $(cargo-package))
