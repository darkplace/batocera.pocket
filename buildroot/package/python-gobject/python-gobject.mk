################################################################################
#
# python-gobject
#
################################################################################

PYTHON_GOBJECT_VERSION_MAJOR = 3.42
PYTHON_GOBJECT_VERSION = $(PYTHON_GOBJECT_VERSION_MAJOR).2
PYTHON_GOBJECT_SOURCE = pygobject-$(PYTHON_GOBJECT_VERSION).tar.xz
PYTHON_GOBJECT_SITE = https://download.gnome.org/sources/pygobject/$(PYTHON_GOBJECT_VERSION_MAJOR)
PYTHON_GOBJECT_LICENSE = LGPL-2.1+
PYTHON_GOBJECT_LICENSE_FILES = COPYING
PYTHON_GOBJECT_INSTALL_STAGING = YES
PYTHON_GOBJECT_DEPENDENCIES = \
	gobject-introspection \
	host-pkgconf \
	libglib2 \
	python3 \
	python-pycairo

PYTHON_GOBJECT_CONF_OPTS += \
	-Dpycairo=enabled \
	-Dtests=false

# A sysconfigdata_name must be manually specified or the resulting .so
# will have a x86_64 prefix, which causes "import gi" to fail.
# A pythonpath must be specified or the host python path will be used resulting
# in a "not a valid python" error.
PYTHON_GOBJECT_CONF_ENV += \
	_PYTHON_SYSCONFIGDATA_NAME=$(PKG_PYTHON_SYSCONFIGDATA_NAME) \
	PYTHONPATH=$(PYTHON3_PATH)

# Lutris IconView covers stay blank without the cairo foreign module.
define PYTHON_GOBJECT_CHECK_CAIRO
	if ! ls "$(TARGET_DIR)"/usr/lib/python*/site-packages/gi/_gi_cairo*.so >/dev/null 2>&1; then \
		echo "ERROR: python-gobject missing gi._gi_cairo (enable pycairo)" >&2; \
		exit 1; \
	fi
endef
PYTHON_GOBJECT_POST_INSTALL_TARGET_HOOKS += PYTHON_GOBJECT_CHECK_CAIRO

$(eval $(meson-package))
