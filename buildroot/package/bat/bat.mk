################################################################################
#
# bat
#
################################################################################

BAT_VERSION = 0.24.0
BAT_SITE = $(call github,sharkdp,bat,v$(BAT_VERSION))
BAT_LICENSE = Apache-2.0 or MIT
BAT_LICENSE_FILES = LICENSE-APACHE LICENSE-MIT

ifeq ($(BR2_TOOLCHAIN_GCC_AT_LEAST_15),y)
BAT_CARGO_ENV += CFLAGS="$(TARGET_CFLAGS) -std=gnu17"
endif

$(eval $(cargo-package))
