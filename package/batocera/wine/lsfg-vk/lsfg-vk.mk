################################################################################
#
# lsfg-vk
#
################################################################################

LSFG_VK_RELEASE_VERSION = 1.0.0
LSFG_VK_VERSION = v$(LSFG_VK_RELEASE_VERSION)
LSFG_VK_X86_SOURCE = lsfg-vk-$(LSFG_VK_RELEASE_VERSION)-x86_64.zip
LSFG_VK_LICENSE = GPL-3.0
LSFG_VK_BIN_ARCH_EXCLUDE += /usr/wine/lsfg-vk

ifeq ($(BR2_aarch64),y)
LSFG_VK_SITE = https://github.com/PancakeTAS/lsfg-vk.git
LSFG_VK_SITE_METHOD = git
LSFG_VK_GIT_SUBMODULES = YES
LSFG_VK_LICENSE_FILES = LICENSE.md
LSFG_VK_SUPPORTS_IN_SOURCE_BUILD = NO
LSFG_VK_CMAKE_BACKEND = ninja
LSFG_VK_DEPENDENCIES += vulkan-headers

LSFG_VK_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
LSFG_VK_CONF_OPTS += -DCMAKE_INSTALL_PREFIX=/usr

define LSFG_VK_BUILD_X86_LAYER
	rm -rf $(@D)/x86-build $(@D)/x86-vulkan-headers
	mkdir -p $(@D)/x86-build/tmp $(@D)/x86-vulkan-headers
	cp -a $(STAGING_DIR)/usr/include/vulkan $(@D)/x86-vulkan-headers/
	if [ -d $(STAGING_DIR)/usr/include/vk_video ]; then \
		cp -a $(STAGING_DIR)/usr/include/vk_video $(@D)/x86-vulkan-headers/; \
	fi
	cd $(@D)/x86-build && \
	PATH="$(HOST_DIR)/bin:$(HOST_DIR)/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
	PKG_CONFIG="$(HOST_DIR)/bin/pkg-config" \
	PKG_CONFIG_SYSROOT_DIR="/" \
	PKG_CONFIG_LIBDIR="$(HOST_DIR)/lib/pkgconfig:$(HOST_DIR)/share/pkgconfig" \
	PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1 \
	PKG_CONFIG_ALLOW_SYSTEM_LIBS=1 \
	TMPDIR="$(@D)/x86-build/tmp" \
	CFLAGS= CXXFLAGS= CPPFLAGS= LDFLAGS= \
	$(HOST_DIR)/bin/cmake $(@D) \
		-G"Ninja" \
		-DCMAKE_MAKE_PROGRAM="$(HOST_DIR)/bin/ninja" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=/usr \
		-DCMAKE_C_COMPILER="$(HOSTCC_NOCCACHE)" \
		-DCMAKE_CXX_COMPILER="$(HOSTCXX_NOCCACHE)" \
		-DCMAKE_C_FLAGS="-I$(@D)/x86-vulkan-headers" \
		-DCMAKE_CXX_FLAGS="-I$(@D)/x86-vulkan-headers -Wno-error=deprecated-declarations" \
		-DBUILD_SHARED_LIBS=ON \
		-DVulkan_INCLUDE_DIR="$(@D)/x86-vulkan-headers"
	PATH="$(HOST_DIR)/bin:$(HOST_DIR)/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
	TMPDIR="$(@D)/x86-build/tmp" \
	CFLAGS= CXXFLAGS= CPPFLAGS= LDFLAGS= \
	$(HOST_DIR)/bin/cmake --build $(@D)/x86-build \
		--target lsfg-vk -j$(PARALLEL_JOBS)
endef

LSFG_VK_POST_BUILD_HOOKS += LSFG_VK_BUILD_X86_LAYER

define LSFG_VK_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib
	mkdir -p $(TARGET_DIR)/usr/share/vulkan/explicit_layer.d
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/liblsfg-vk.so \
		$(TARGET_DIR)/usr/lib/liblsfg-vk.so
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/thirdparty/pe-parse/pe-parser-library/libpe-parse.so \
		$(TARGET_DIR)/usr/lib/libpe-parse.so
	sed 's#"library_path": "liblsfg-vk.so"#"library_path": "/usr/lib/liblsfg-vk.so"#' \
		$(@D)/VkLayer_LS_frame_generation.json \
		> $(TARGET_DIR)/usr/share/vulkan/explicit_layer.d/VkLayer_LS_frame_generation.json

	rm -rf $(TARGET_DIR)/usr/wine/lsfg-vk
	mkdir -p $(TARGET_DIR)/usr/wine/lsfg-vk/x64/lib
	mkdir -p $(TARGET_DIR)/usr/wine/lsfg-vk/x64/share/vulkan/explicit_layer.d
	$(INSTALL) -D -m 0755 $(@D)/x86-build/liblsfg-vk.so \
		$(TARGET_DIR)/usr/wine/lsfg-vk/x64/lib/liblsfg-vk.so
	$(INSTALL) -D -m 0755 $(@D)/x86-build/thirdparty/pe-parse/pe-parser-library/libpe-parse.so \
		$(TARGET_DIR)/usr/wine/lsfg-vk/x64/lib/libpe-parse.so
	sed 's#"library_path": "liblsfg-vk.so"#"library_path": "/usr/wine/lsfg-vk/x64/lib/liblsfg-vk.so"#' \
		$(@D)/VkLayer_LS_frame_generation.json \
		> $(TARGET_DIR)/usr/wine/lsfg-vk/x64/share/vulkan/explicit_layer.d/VkLayer_LS_frame_generation.json
endef

$(eval $(cmake-package))
else
LSFG_VK_SOURCE = $(LSFG_VK_X86_SOURCE)
LSFG_VK_SITE = https://github.com/PancakeTAS/lsfg-vk/releases/download/$(LSFG_VK_VERSION)

define LSFG_VK_EXTRACT_CMDS
	mkdir -p $(@D)/target
	unzip -q $(DL_DIR)/$(LSFG_VK_DL_SUBDIR)/$(LSFG_VK_SOURCE) -d $(@D)/target
endef

define LSFG_VK_INSTALL_TARGET_CMDS
	rm -rf $(TARGET_DIR)/usr/wine/lsfg-vk
	mkdir -p $(TARGET_DIR)/usr/wine/lsfg-vk/x64/lib
	mkdir -p $(TARGET_DIR)/usr/wine/lsfg-vk/x64/share/vulkan/explicit_layer.d
	$(INSTALL) -D -m 0755 $(@D)/target/lib/liblsfg-vk.so \
		$(TARGET_DIR)/usr/wine/lsfg-vk/x64/lib/liblsfg-vk.so
	sed 's#"library_path": "liblsfg-vk.so"#"library_path": "/usr/wine/lsfg-vk/x64/lib/liblsfg-vk.so"#' \
		$(@D)/target/share/vulkan/implicit_layer.d/VkLayer_LS_frame_generation.json \
		> $(TARGET_DIR)/usr/wine/lsfg-vk/x64/share/vulkan/explicit_layer.d/VkLayer_LS_frame_generation.json
endef

$(eval $(generic-package))
endif
