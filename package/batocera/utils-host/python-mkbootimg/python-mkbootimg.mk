################################################################################
#
# python-mkbootimg
#
################################################################################

PYTHON_MKBOOTIMG_DEPENDENCIES += python

PYTHON_MKBOOTIMG_SITE = https://android.googlesource.com/platform/system/tools/mkbootimg/+/refs/heads/main/mkbootimg.py?format=TEXT

define HOST_PYTHON_MKBOOTIMG_INSTALL_CMDS
	set -e; \
	wget -O - "${PYTHON_MKBOOTIMG_SITE}" | base64 -d > "${@D}/mkbootimg"; \
	test -s "${@D}/mkbootimg"; \
	$(INSTALL) -D -m 0755 "${@D}/mkbootimg" "$(HOST_DIR)/usr/bin/mkbootimg"
endef

$(eval $(host-generic-package))
