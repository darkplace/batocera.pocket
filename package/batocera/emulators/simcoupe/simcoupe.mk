################################################################################
#
# simcoupe
#
################################################################################

SIMCOUPE_VERSION = v1.2.16
SIMCOUPE_SITE = $(call github,simonowen,simcoupe,$(SIMCOUPE_VERSION))
SIMCOUPE_LICENSE = GPL-3.0

SIMCOUPE_SUPPORTS_IN_SOURCE_BUILD = YES

SIMCOUPE_DEPENDENCIES = sdl2 zlib

SIMCOUPE_ZLIB_VERSION = 51b7f2abdade71cd9bb0e7a373ef2610ec6f9daf
SIMCOUPE_Z80_VERSION = 9917a379abdc80d49831e4b6eff9e2c4df43bfbc
SIMCOUPE_FMT_VERSION = e69e5f977d458f2650bb346dadf2ad30c5320281
SIMCOUPE_RESID_VERSION = 9ac2b4b5633a6c64fb02fd09a350ea857dd0c6d3
SIMCOUPE_SPECTRUM_VERSION = eb93bd36f6253471bf709bb9745176d1f9c994f0
SIMCOUPE_SAASOUND_VERSION = 7ceef2af64e7411cc723cb465f060bb856459eea
SIMCOUPE_WHEREAMI_VERSION = ba364cd54fd431c76c045393b6522b4bff547f50

SIMCOUPE_ZLIB_SOURCE = zlib-$(SIMCOUPE_ZLIB_VERSION).tar.gz
SIMCOUPE_Z80_SOURCE = z80-$(SIMCOUPE_Z80_VERSION).tar.gz
SIMCOUPE_FMT_SOURCE = fmt-$(SIMCOUPE_FMT_VERSION).tar.gz
SIMCOUPE_RESID_SOURCE = resid-$(SIMCOUPE_RESID_VERSION).tar.gz
SIMCOUPE_SPECTRUM_SOURCE = spectrum-$(SIMCOUPE_SPECTRUM_VERSION).tar.gz
SIMCOUPE_SAASOUND_SOURCE = saasound-$(SIMCOUPE_SAASOUND_VERSION).tar.gz
SIMCOUPE_WHEREAMI_SOURCE = whereami-$(SIMCOUPE_WHEREAMI_VERSION).tar.gz

SIMCOUPE_EXTRA_DOWNLOADS += \
	$(call github,madler,zlib,$(SIMCOUPE_ZLIB_VERSION))/$(SIMCOUPE_ZLIB_SOURCE) \
	$(call github,kosarev,z80,$(SIMCOUPE_Z80_VERSION))/$(SIMCOUPE_Z80_SOURCE) \
	$(call github,fmtlib,fmt,$(SIMCOUPE_FMT_VERSION))/$(SIMCOUPE_FMT_SOURCE) \
	$(call github,simonowen,resid,$(SIMCOUPE_RESID_VERSION))/$(SIMCOUPE_RESID_SOURCE) \
	$(call github,simonowen,libspectrum,$(SIMCOUPE_SPECTRUM_VERSION))/$(SIMCOUPE_SPECTRUM_SOURCE) \
	$(call github,stripwax,SAASound,$(SIMCOUPE_SAASOUND_VERSION))/$(SIMCOUPE_SAASOUND_SOURCE) \
	$(call github,gpakosz,whereami,$(SIMCOUPE_WHEREAMI_VERSION))/$(SIMCOUPE_WHEREAMI_SOURCE)

SIMCOUPE_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
SIMCOUPE_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
SIMCOUPE_CONF_OPTS += -DFETCHCONTENT_SOURCE_DIR_ZLIB=$(@D)/buildroot-fetchcontent/zlib
SIMCOUPE_CONF_OPTS += -DFETCHCONTENT_SOURCE_DIR_Z80=$(@D)/buildroot-fetchcontent/z80
SIMCOUPE_CONF_OPTS += -DFETCHCONTENT_SOURCE_DIR_FMT=$(@D)/buildroot-fetchcontent/fmt
SIMCOUPE_CONF_OPTS += -DFETCHCONTENT_SOURCE_DIR_RESID=$(@D)/resid-src
SIMCOUPE_CONF_OPTS += -DFETCHCONTENT_SOURCE_DIR_SPECTRUM=$(@D)/buildroot-fetchcontent/spectrum
SIMCOUPE_CONF_OPTS += -DFETCHCONTENT_SOURCE_DIR_SAASOUND=$(@D)/buildroot-fetchcontent/saasound
SIMCOUPE_CONF_OPTS += -DFETCHCONTENT_SOURCE_DIR_WHEREAMI=$(@D)/buildroot-fetchcontent/whereami

define SIMCOUPE_EXTRACT_FETCHCONTENT
	mkdir -p $(@D)/buildroot-fetchcontent/zlib
	$(call suitable-extractor,$(SIMCOUPE_ZLIB_SOURCE)) $(SIMCOUPE_DL_DIR)/$(SIMCOUPE_ZLIB_SOURCE) | \
		$(TAR) --strip-components=1 -C $(@D)/buildroot-fetchcontent/zlib $(TAR_OPTIONS) -
	mkdir -p $(@D)/buildroot-fetchcontent/z80
	$(call suitable-extractor,$(SIMCOUPE_Z80_SOURCE)) $(SIMCOUPE_DL_DIR)/$(SIMCOUPE_Z80_SOURCE) | \
		$(TAR) --strip-components=1 -C $(@D)/buildroot-fetchcontent/z80 $(TAR_OPTIONS) -
	mkdir -p $(@D)/buildroot-fetchcontent/fmt
	$(call suitable-extractor,$(SIMCOUPE_FMT_SOURCE)) $(SIMCOUPE_DL_DIR)/$(SIMCOUPE_FMT_SOURCE) | \
		$(TAR) --strip-components=1 -C $(@D)/buildroot-fetchcontent/fmt $(TAR_OPTIONS) -
	mkdir -p $(@D)/resid-src
	$(call suitable-extractor,$(SIMCOUPE_RESID_SOURCE)) $(SIMCOUPE_DL_DIR)/$(SIMCOUPE_RESID_SOURCE) | \
		$(TAR) --strip-components=1 -C $(@D)/resid-src $(TAR_OPTIONS) -
	mkdir -p $(@D)/buildroot-fetchcontent/spectrum
	$(call suitable-extractor,$(SIMCOUPE_SPECTRUM_SOURCE)) $(SIMCOUPE_DL_DIR)/$(SIMCOUPE_SPECTRUM_SOURCE) | \
		$(TAR) --strip-components=1 -C $(@D)/buildroot-fetchcontent/spectrum $(TAR_OPTIONS) -
	mkdir -p $(@D)/buildroot-fetchcontent/saasound
	$(call suitable-extractor,$(SIMCOUPE_SAASOUND_SOURCE)) $(SIMCOUPE_DL_DIR)/$(SIMCOUPE_SAASOUND_SOURCE) | \
		$(TAR) --strip-components=1 -C $(@D)/buildroot-fetchcontent/saasound $(TAR_OPTIONS) -
	mkdir -p $(@D)/buildroot-fetchcontent/whereami
	$(call suitable-extractor,$(SIMCOUPE_WHEREAMI_SOURCE)) $(SIMCOUPE_DL_DIR)/$(SIMCOUPE_WHEREAMI_SOURCE) | \
		$(TAR) --strip-components=1 -C $(@D)/buildroot-fetchcontent/whereami $(TAR_OPTIONS) -
endef
SIMCOUPE_POST_EXTRACT_HOOKS += SIMCOUPE_EXTRACT_FETCHCONTENT

SIMCOUPE_BIOS_AND_RESOURCES = /usr/share/simcoupe
define SIMCOUPE_INSTALL_TARGET_CMDS
		$(INSTALL) -D $(@D)/simcoupe $(TARGET_DIR)/usr/bin/simcoupe
		cp -d $(@D)/_deps/saasound-build/libSAASound* $(TARGET_DIR)/usr/lib/
		mkdir -p $(TARGET_DIR)$(SIMCOUPE_BIOS_AND_RESOURCES)
		cp -R $(@D)/Resource/* $(TARGET_DIR)$(SIMCOUPE_BIOS_AND_RESOURCES)
		mkdir -p $(TARGET_DIR)/usr/share/evmapy
		cp $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/simcoupe/samcoupe.keys \
		    $(TARGET_DIR)/usr/share/evmapy
endef

$(eval $(cmake-package))
