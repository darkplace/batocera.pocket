################################################################################
#
# gmp
#
################################################################################

GMP_VERSION = 6.3.0
GMP_SITE = $(BR2_GNU_MIRROR)/gmp
GMP_SOURCE = gmp-$(GMP_VERSION).tar.xz
GMP_INSTALL_STAGING = YES
GMP_LICENSE = LGPL-3.0+ or GPL-2.0+
GMP_LICENSE_FILES = COPYING.LESSERv3 COPYINGv2
GMP_CPE_ID_VENDOR = gmplib
GMP_DEPENDENCIES = host-m4
HOST_GMP_DEPENDENCIES = host-m4

GMP_CONF_ENV += CC_FOR_BUILD="$(HOSTCC) -std=c99"

GMP_HOST_GCC_MAJOR = $(shell $(HOSTCC_NOCCACHE) -dumpfullversion -dumpversion 2>/dev/null | cut -d. -f1)

# gcc 15 defaults to -std=gnu23, where an empty function parameter list
# means no arguments. GMP 6.3.0's configure probes still rely on the
# older GNU C behavior, so keep host-gmp on the previous default.
ifeq ($(shell test $(GMP_HOST_GCC_MAJOR) -ge 15 2>/dev/null && echo y),y)
HOST_GMP_CONF_ENV += CFLAGS="$(HOST_CFLAGS) -std=gnu17"
endif

# Apply the same workaround when building target gmp with a gcc 15+
# toolchain.
ifeq ($(BR2_TOOLCHAIN_GCC_AT_LEAST_15),y)
GMP_CONF_ENV += CFLAGS="$(TARGET_CFLAGS) -std=gnu17"
endif

# GMP doesn't support assembly for coldfire or mips r6 ISA yet
# Disable for ARM v7m since it has different asm constraints
ifeq ($(BR2_m68k_cf)$(BR2_MIPS_CPU_MIPS32R6)$(BR2_MIPS_CPU_MIPS64R6)$(BR2_ARM_CPU_ARMV7M),y)
GMP_CONF_OPTS += --disable-assembly
endif

# GMP needs M extension for riscv assembly
ifeq ($(BR2_riscv):$(BR2_RISCV_ISA_RVM),y:)
GMP_CONF_OPTS += --disable-assembly
endif

ifeq ($(BR2_INSTALL_LIBSTDCPP),y)
GMP_CONF_OPTS += --enable-cxx
else
GMP_CONF_OPTS += --disable-cxx
endif

$(eval $(autotools-package))
$(eval $(host-autotools-package))
