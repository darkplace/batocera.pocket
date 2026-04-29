################################################################################
#
# virglrenderer
#
################################################################################

VIRGLRENDERER_VERSION = virglrenderer-1.3.0
VIRGLRENDERER_SITE = https://gitlab.freedesktop.org/virgl/virglrenderer/-/archive/$(VIRGLRENDERER_VERSION)
VIRGLRENDERER_SOURCE = virglrenderer-$(VIRGLRENDERER_VERSION).tar.gz
VIRGLRENDERER_LICENSE = MIT
VIRGLRENDERER_LICENSE_FILES = COPYING
VIRGLRENDERER_DEPENDENCIES = libdrm libepoxy
VIRGLRENDERER_INSTALL_STAGING = YES

# QEMU only needs the core GL renderer path.
VIRGLRENDERER_CONF_OPTS = \
	-Dplatforms=egl \
	-Dvideo=false \
	-Dvenus=false \
	-Dtests=false \
	-Dfuzzer=false \
	-Dvalgrind=false \
	-Dtracing=none \
	-Dunstable-apis=false

$(eval $(meson-package))
