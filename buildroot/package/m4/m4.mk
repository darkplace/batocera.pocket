################################################################################
#
# m4
#
################################################################################

M4_VERSION = 1.4.19
M4_SOURCE = m4-$(M4_VERSION).tar.xz
M4_SITE = $(BR2_GNU_MIRROR)/m4
M4_LICENSE = GPL-3.0+
M4_LICENSE_FILES = COPYING

M4_HOST_GCC_MAJOR = $(shell $(HOSTCC_NOCCACHE) -dumpfullversion -dumpversion 2>/dev/null | cut -d. -f1)

# gcc 15 defaults to -std=gnu23, which m4-1.4.19's bundled gnulib
# misdetects and then fails to build. Force the previous default only
# for affected host compilers.
ifeq ($(shell test $(M4_HOST_GCC_MAJOR) -ge 15 2>/dev/null && echo y),y)
HOST_M4_CONF_ENV = CFLAGS="$(HOST_CFLAGS) -std=gnu17"
endif

$(eval $(host-autotools-package))
