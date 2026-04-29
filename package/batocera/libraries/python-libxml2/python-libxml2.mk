################################################################################
#
# python-libxml2
#
################################################################################

PYTHON_LIBXML2_VERSION_MAJOR = 2.15
PYTHON_LIBXML2_VERSION = $(PYTHON_LIBXML2_VERSION_MAJOR).1
PYTHON_LIBXML2_SOURCE = libxml2-$(PYTHON_LIBXML2_VERSION).tar.xz
PYTHON_LIBXML2_SITE = https://download.gnome.org/sources/libxml2/$(PYTHON_LIBXML2_VERSION_MAJOR)
PYTHON_LIBXML2_SUBDIR = python
PYTHON_LIBXML2_SETUP_TYPE = setuptools
PYTHON_LIBXML2_LICENSE = MIT
PYTHON_LIBXML2_LICENSE_FILES = Copyright
PYTHON_LIBXML2_DEPENDENCIES = libxml2 python3
PYTHON_LIBXML2_ENV = \
	_PYTHON_SYSCONFIGDATA_NAME=$(PKG_PYTHON_SYSCONFIGDATA_NAME) \
	PYTHONPATH=$(PYTHON3_PATH)

ifeq ($(BR2_TOOLCHAIN_HAS_THREADS),y)
PYTHON_LIBXML2_WITH_THREADS = 1
else
PYTHON_LIBXML2_WITH_THREADS = 0
endif

define PYTHON_LIBXML2_GENERATE_SETUP
	cp $(@D)/python/setup.py.in $(@D)/python/setup.py
	$(SED) "s|@prefix@|$(STAGING_DIR)/usr|g" $(@D)/python/setup.py
	$(SED) "s|@LIBXML_VERSION@|$(PYTHON_LIBXML2_VERSION)|g" $(@D)/python/setup.py
	$(SED) "s|@WITH_THREADS@|$(PYTHON_LIBXML2_WITH_THREADS)|g" $(@D)/python/setup.py
	$(SED) "s|@WITH_ICONV@|1|g" $(@D)/python/setup.py
	$(SED) "s|@WITH_ZLIB@|1|g" $(@D)/python/setup.py
	$(SED) "s|@WITH_ICU@|1|g" $(@D)/python/setup.py
	( \
		printf '%s\n' \
			'from pathlib import Path' \
			'path = Path("$(@D)/python/generator.py")' \
			'text = path.read_text()' \
			'old = """xmlDocDir = dstPref + '\''/../doc/xml'\''' \
			'if not os.path.isdir(xmlDocDir):' \
			'    xmlDocDir = dstPref + '\''/doc/xml'\''' \
			'    if not os.path.isdir(xmlDocDir):' \
			'        raise Exception(f'\''Doxygen XML not found in {dstPref}'\'')' \
			'"""' \
			'new = """xmlDocDir = None' \
			'for candidate in (dstPref + '\''/../doc/xml'\'', dstPref + '\''/doc/xml'\''):' \
			'    if os.path.isdir(candidate):' \
			'        xmlDocDir = candidate' \
			'        break' \
			'"""' \
			'text = text.replace(old, new)' \
			'text = text.replace("for file in os.listdir(xmlDocDir):", "for file in os.listdir(xmlDocDir) if xmlDocDir is not None else []:")' \
			'path.write_text(text)' \
			> $(@D)/python/fix_generator.py; \
		$(HOST_DIR)/bin/python $(@D)/python/fix_generator.py; \
		rm -f $(@D)/python/fix_generator.py; \
	)
endef
PYTHON_LIBXML2_POST_PATCH_HOOKS += PYTHON_LIBXML2_GENERATE_SETUP

PYTHON_LIBXML2_PYTHON_ENV = \
	$(PKG_PYTHON_SETUPTOOLS_ENV) \
	PYTHONPATH="$(@D)/python:$(PYTHON3_PATH)"

define PYTHON_LIBXML2_BUILD_CMDS
	(cd $(@D)/python; \
		$(PYTHON_LIBXML2_PYTHON_ENV) \
		$(HOST_DIR)/bin/python setup.py build)
endef

define PYTHON_LIBXML2_INSTALL_TARGET_CMDS
	(cd $(@D)/python; \
		$(PYTHON_LIBXML2_PYTHON_ENV) \
		$(HOST_DIR)/bin/python setup.py install \
			$(PKG_PYTHON_SETUPTOOLS_INSTALL_OPTS) \
			--root=$(TARGET_DIR))
endef

$(eval $(python-package))
