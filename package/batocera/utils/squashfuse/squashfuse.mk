################################################################################
#
# squashfuse
#
################################################################################

SQUASHFUSE_VERSION = 0.6.1
SQUASHFUSE_SITE = https://github.com/vasi/squashfuse/releases/download/0.6.1
SQUASHFUSE_SOURCE = squashfuse-$(SQUASHFUSE_VERSION).tar.gz

SQUASHFUSE_LICENSE = BSD-2-Clause
SQUASHFUSE_LICENSE_FILES = LICENSE

SQUASHFUSE_DEPENDENCIES = libfuse3 zlib xz lz4 zstd

SQUASHFUSE_CONF_OPTS = \
    --enable-fuse3 \
    --enable-low-level

$(eval $(autotools-package))
