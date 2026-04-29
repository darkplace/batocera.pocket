################################################################################
#
# parallel-hashmap
#
################################################################################

PARALLEL_HASHMAP_VERSION = 2.0.0
PARALLEL_HASHMAP_SITE = $(call github,greg7mdp,parallel-hashmap,v$(PARALLEL_HASHMAP_VERSION))
PARALLEL_HASHMAP_LICENSE = Apache-2.0
PARALLEL_HASHMAP_LICENSE_FILES = LICENSE
PARALLEL_HASHMAP_INSTALL_STAGING = YES
PARALLEL_HASHMAP_INSTALL_TARGET = NO

define PARALLEL_HASHMAP_INSTALL_STAGING_CMDS
	$(INSTALL) -d $(STAGING_DIR)/usr/include/parallel_hashmap
	cp -dpfr $(@D)/parallel_hashmap/. $(STAGING_DIR)/usr/include/parallel_hashmap
endef

$(eval $(generic-package))
