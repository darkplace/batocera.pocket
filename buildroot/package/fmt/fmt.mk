################################################################################
#
# fmt
#
################################################################################
# batocera - bump
FMT_VERSION = 12.0.0
FMT_SITE = https://github.com/fmtlib/fmt/releases/download/$(FMT_VERSION)
FMT_SOURCE = fmt-$(FMT_VERSION).zip
FMT_LICENSE = MIT with exception
FMT_LICENSE_FILES = LICENSE
FMT_CPE_ID_VENDOR = fmt
FMT_INSTALL_STAGING = YES
HOST_FMT_SUBDIR = fmt-$(FMT_VERSION)

FMT_CONF_OPTS = \
	-DFMT_INSTALL=ON \
	-DFMT_TEST=OFF

define FMT_EXTRACT_CMDS
	$(UNZIP) -d $(BUILD_DIR) $(FMT_DL_DIR)/$(FMT_SOURCE)
endef

define HOST_FMT_EXTRACT_CMDS
	mkdir -p $(@D)
	cd $(@D) && $(UNZIP) -q $(FMT_DL_DIR)/$(FMT_SOURCE)
endef

$(eval $(cmake-package))
$(eval $(host-cmake-package))
