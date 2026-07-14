################################################################################
#
# gopher64
#
################################################################################

GOPHER64_VERSION = a23ede433b46687b48cb13ae4305ce5a5857d616
GOPHER64_SITE = https://github.com/gopher64/gopher64.git
GOPHER64_SITE_METHOD = git
GOPHER64_GIT_SUBMODULES = YES
GOPHER64_LICENSE = GPL-3.0+
GOPHER64_LICENSE_FILES = LICENSE
GOPHER64_DEPENDENCIES = host-rustc host-rust-bin host-clang host-cmake host-ninja \
	alsa-lib libdrm mesa3d sdl3_ttf vulkan-loader

GOPHER64_GCC_VERSION = $(notdir $(firstword $(wildcard $(HOST_DIR)/$(GNU_TARGET_NAME)/include/c++/*)))
GOPHER64_BINDGEN_SYSROOT = $(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot
GOPHER64_BINDGEN_STDLIB = $(HOST_DIR)/$(GNU_TARGET_NAME)/include/c++/$(GOPHER64_GCC_VERSION)
GOPHER64_BINDGEN_STDLIB_TARGET = $(GOPHER64_BINDGEN_STDLIB)/$(GNU_TARGET_NAME)
GOPHER64_SKIA_TARGET_CPU = $(if $(BR2_aarch64),arm64,x64)

GOPHER64_CARGO_ENV = \
	BINDGEN_EXTRA_CLANG_ARGS="--sysroot=$(GOPHER64_BINDGEN_SYSROOT) --target=$(RUSTC_TARGET_NAME) -isystem $(GOPHER64_BINDGEN_STDLIB) -isystem $(GOPHER64_BINDGEN_STDLIB_TARGET)" \
	FREETYPE2_INCLUDE_PATH="$(STAGING_DIR)/usr/include/freetype2" \
	GOPHER64_GIT_HASH="$(GOPHER64_VERSION)" \
	PKG_CONFIG_ALLOW_CROSS=1 \
	RA_HARDCORE="true" \
	RUSTFLAGS="-A unpredictable_function_pointer_comparisons -C link-arg=-ldrm -C link-arg=-lgbm -C link-arg=-lasound -C link-arg=-lvulkan -C link-arg=-lvolk -C link-arg=-lfreetype" \
	SKIA_GN_ARGS='target_os="linux" target_cpu="$(GOPHER64_SKIA_TARGET_CPU)" cc="$(TARGET_CC)" cxx="$(TARGET_CXX)" skia_system_freetype2_include_path="$(STAGING_DIR)/usr/include/freetype2" extra_cflags=[] extra_asmflags=[]'

ifeq ($(BR2_aarch64),y)
GOPHER64_CARGO_ENV += \
	SKIA_BINARIES_URL="https://github.com/rust-skia/skia-binaries/releases/download/0.90.0/skia-binaries-da4579b39b75fa2187c5-aarch64-unknown-linux-gnu-gl-pdf-textlayout-vulkan.tar.gz"
endif

GOPHER64_CARGO_MODE = $(if $(BR2_ENABLE_DEBUG),debug,release)
GOPHER64_BIN_DIR = target/$(RUSTC_TARGET_NAME)/$(GOPHER64_CARGO_MODE)

define GOPHER64_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/$(GOPHER64_BIN_DIR)/gopher64 \
		$(TARGET_DIR)/usr/bin/gopher64
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/gopher64/config.json \
		$(TARGET_DIR)/usr/share/gopher64/config.json
endef

$(eval $(cargo-package))
