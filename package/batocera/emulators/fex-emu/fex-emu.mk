################################################################################
#
# fex-emu
#
################################################################################

FEX_EMU_VERSION = FEX-2608
FEX_EMU_SITE = https://github.com/FEX-Emu/FEX.git
FEX_EMU_SITE_METHOD = git
FEX_EMU_GIT_SUBMODULES = YES
FEX_EMU_LICENSE = MIT
FEX_EMU_LICENSE_FILES = LICENSE
FEX_EMU_SUPPORTS_IN_SOURCE_BUILD = NO

FEX_EMU_DEPENDENCIES += host-clang host-fex-emu alsa-lib libdrm libglvnd llvm mesa3d openssl squashfs squashfuse vulkan-headers wayland

FEX_EMU_CMAKE_BACKEND = ninja

# Use fex-clang wrapper: strips ARM flags (-mcpu, -march, etc.) when targeting x86_64
FEX_EMU_CONF_OPTS += -DCMAKE_C_COMPILER=$(HOST_DIR)/bin/fex-clang
FEX_EMU_CONF_OPTS += -DCMAKE_CXX_COMPILER=$(HOST_DIR)/bin/fex-clang++
FEX_EMU_CONF_OPTS += -DCMAKE_C_COMPILER_AR=$(HOST_DIR)/bin/llvm-ar
FEX_EMU_CONF_OPTS += -DCMAKE_CXX_COMPILER_AR=$(HOST_DIR)/bin/llvm-ar
FEX_EMU_CONF_OPTS += -DCMAKE_ASM_COMPILER_AR=$(HOST_DIR)/bin/llvm-ar
FEX_EMU_CONF_OPTS += -DCMAKE_C_COMPILER_RANLIB=$(HOST_DIR)/bin/llvm-ranlib
FEX_EMU_CONF_OPTS += -DCMAKE_CXX_COMPILER_RANLIB=$(HOST_DIR)/bin/llvm-ranlib
FEX_EMU_CONF_OPTS += -DCMAKE_ASM_COMPILER_RANLIB=$(HOST_DIR)/bin/llvm-ranlib
FEX_EMU_CONF_OPTS += -DCMAKE_EXE_LINKER_FLAGS="-lstdc++ -lm"
FEX_EMU_CONF_OPTS += -DCMAKE_PREFIX_PATH=$(HOST_DIR)/lib/cmake
FEX_EMU_CONF_OPTS += -DClang_DIR=$(HOST_DIR)/lib/cmake/clang
FEX_EMU_CONF_OPTS += -DLLVM_DIR=$(HOST_DIR)/lib/cmake/llvm
FEX_EMU_CONF_OPTS += -DCMAKE_CROSSCOMPILING=ON
FEX_EMU_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
FEX_EMU_CONF_OPTS += -DCMAKE_INSTALL_PREFIX=/usr
FEX_EMU_CONF_OPTS += -DUSE_LINKER=lld
FEX_EMU_CONF_OPTS += -DCMAKE_LINKER=$(HOST_DIR)/bin/ld.lld
FEX_EMU_CONF_OPTS += -DENABLE_LTO=False
FEX_EMU_CONF_OPTS += -DBUILD_TESTING=False
FEX_EMU_CONF_OPTS += -DENABLE_ASSERTIONS=False
FEX_EMU_CONF_OPTS += -DBUILD_FEXCONFIG=False
FEX_EMU_CONF_OPTS += -DBUILD_TESTS=False
FEX_EMU_CONF_OPTS += -DBUILD_THUNKS=True
FEX_EMU_CONF_OPTS += -DBUILD_32BIT_GUEST_THUNKS=False
FEX_EMU_CONF_OPTS += -DTHUNKGEN_EXE=$(HOST_DIR)/bin/fex-thunkgen
FEX_EMU_CONF_OPTS += -DX86_DEV_ROOTFS=$(HOST_DIR)/share/fex-guest-rootfs
FEX_EMU_CONF_OPTS += -DGUEST_THUNK_SYSROOT=$(HOST_DIR)/share/fex-guest-rootfs
FEX_EMU_CONF_OPTS += -DHOST_THUNK_SYSROOT=$(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot
FEX_EMU_CONF_OPTS += -DHOST_THUNK_TARGET_TRIPLE=$(GNU_TARGET_NAME)
FEX_EMU_CONF_OPTS += -DHOST_THUNK_TOOLCHAIN_INCLUDE_ROOT=$(HOST_DIR)/$(GNU_TARGET_NAME)/include
FEX_EMU_CONF_OPTS += -DHOST_THUNK_CXX_INCLUDE_ROOT=$(HOST_DIR)/$(GNU_TARGET_NAME)/include/c++
FEX_EMU_CONF_OPTS += -DGUEST_CLANG_PATH=$(HOST_DIR)/bin/fex-clang
FEX_EMU_CONF_OPTS += -DGUEST_CLANGXX_PATH=$(HOST_DIR)/bin/fex-clang++
FEX_EMU_CONF_OPTS += -DCLANG_RESOURCE_DIR=$(HOST_DIR)/lib/clang/20
FEX_EMU_CONF_OPTS += -DCLANG_BUILTIN_HEADERS=$(HOST_DIR)/lib/clang/20/include
FEX_EMU_CONF_OPTS += -DENABLE_JEMALLOC=False
FEX_EMU_CONF_OPTS += -DUSE_NATIVE_INSTRUCTIONS=OFF
FEX_EMU_CONF_OPTS += -DTUNE_CPU=none
FEX_EMU_CONF_OPTS += -DTUNE_ARCH=generic

FEX_EMU_CONF_ENV += CFLAGS=
FEX_EMU_CONF_ENV += CXXFLAGS=
FEX_EMU_CONF_ENV += CPPFLAGS=
FEX_EMU_CONF_ENV += LDFLAGS=
FEX_EMU_CONF_ENV += TARGET_CFLAGS=
FEX_EMU_CONF_ENV += TARGET_CXXFLAGS=
FEX_EMU_CONF_ENV += TARGET_LDFLAGS=
FEX_EMU_CONF_ENV += CCC_OVERRIDE_OPTIONS=
FEX_EMU_CONF_ENV += THUNKGEN_EXTRA_FLAGS="-isystem $(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot/usr/include"
FEX_EMU_CONF_ENV += HOME=$(FEX_EMU_BUILDDIR)/home
FEX_EMU_CONF_ENV += TMPDIR=$(FEX_EMU_BUILDDIR)/tmp

FEX_EMU_BUILD_ENV += CFLAGS=
FEX_EMU_BUILD_ENV += CXXFLAGS=
FEX_EMU_BUILD_ENV += CPPFLAGS=
FEX_EMU_BUILD_ENV += LDFLAGS=
FEX_EMU_BUILD_ENV += TARGET_CFLAGS=
FEX_EMU_BUILD_ENV += TARGET_CXXFLAGS=
FEX_EMU_BUILD_ENV += TARGET_LDFLAGS=
FEX_EMU_BUILD_ENV += CCC_OVERRIDE_OPTIONS=
FEX_EMU_BUILD_ENV += THUNKGEN_EXTRA_FLAGS="-isystem $(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot/usr/include"
FEX_EMU_BUILD_ENV += HOME=$(FEX_EMU_BUILDDIR)/home
FEX_EMU_BUILD_ENV += TMPDIR=$(FEX_EMU_BUILDDIR)/tmp

define FEX_EMU_PREPARE_GUEST_THUNK_ENV
	rm -rf $(HOST_DIR)/share/fex-guest-rootfs
	mkdir -p $(HOST_DIR)/share/fex-guest-rootfs/usr $(FEX_EMU_BUILDDIR)/home $(FEX_EMU_BUILDDIR)/tmp
	# Copy host /usr/include (headers for the guest x86_64 rootfs)
	cp -a /usr/include $(HOST_DIR)/share/fex-guest-rootfs/usr/
	# Explicitly copy C++ standard library headers (cp -a sometimes skips them)
	if [ -d /usr/include/c++ ]; then \
		cp -a /usr/include/c++ $(HOST_DIR)/share/fex-guest-rootfs/usr/include/; \
	fi
	# Replace GCC 15 cstdint/cinttypes with minimal wrappers to avoid
	# 'int_fast8_t' global namespace errors when clang --target=x86_64-linux-gnu
	# encounters the GCC 'using ::int_fast8_t;' declarations.
	for f in $$(find $(HOST_DIR)/share/fex-guest-rootfs/usr/include -name "cstdint" -type f); do \
		echo '#pragma once' > "$$f"; echo '#include <stdint.h>' >> "$$f"; \
	done
	for f in $$(find $(HOST_DIR)/share/fex-guest-rootfs/usr/include -name "cinttypes" -type f); do \
		echo '#pragma once' > "$$f"; echo '#include <inttypes.h>' >> "$$f"; \
	done
	for d in \
		alsa \
		xcb \
		X11 \
		GL \
		EGL \
		GLES \
		GLES2 \
		GLES3 \
		KHR \
		drm \
		libdrm \
		vulkan; do \
		if [ -d $(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot/usr/include/$$d ]; then \
			cp -a $(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot/usr/include/$$d $(HOST_DIR)/share/fex-guest-rootfs/usr/include/; \
		fi; \
	done
	# Override Vulkan headers with FEX's bundled version (newer extensions)
	# The target sysroot Vulkan headers are older and miss functions that
	# FEX-2607's libvulkan_interface.cpp references.
	# Apply to both guest rootfs (guest thunks) and host sysroot (host thunks).
	if [ -d $(BUILD_DIR)/fex-emu-$(FEX_EMU_VERSION)/External/Vulkan-Headers/include/vulkan ]; then \
		mkdir -p $(HOST_DIR)/share/fex-guest-rootfs/usr/include/vulkan; \
		cp -a $(BUILD_DIR)/fex-emu-$(FEX_EMU_VERSION)/External/Vulkan-Headers/include/vulkan/* \
			$(HOST_DIR)/share/fex-guest-rootfs/usr/include/vulkan/; \
		mkdir -p $(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot/usr/include/vulkan; \
		cp -a $(BUILD_DIR)/fex-emu-$(FEX_EMU_VERSION)/External/Vulkan-Headers/include/vulkan/* \
			$(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot/usr/include/vulkan/; \
	fi
	for f in $(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot/usr/include/wayland*.h \
		$(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot/usr/include/xf86drm.h \
		$(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot/usr/include/xf86drmMode.h \
		$(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot/usr/include/drm.h \
		$(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot/usr/include/drm_mode.h; do \
		if [ -e "$$f" ]; then \
			cp -a "$$f" $(HOST_DIR)/share/fex-guest-rootfs/usr/include/; \
		fi; \
	done
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/fex-emu/fex-clang \
		$(HOST_DIR)/bin/fex-clang
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/fex-emu/fex-clang++ \
		$(HOST_DIR)/bin/fex-clang++
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/fex-emu/fex-guest-clang \
		$(HOST_DIR)/bin/fex-guest-clang
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/fex-emu/fex-guest-clang++ \
		$(HOST_DIR)/bin/fex-guest-clang++
	if [ -x $(HOST_DIR)/bin/clang.br_real ]; then \
		$(INSTALL) -D -m 0755 $(HOST_DIR)/bin/clang.br_real $(HOST_DIR)/bin/fex-system-clang; \
	elif [ -x $(HOST_DIR)/bin/clang ]; then \
		$(INSTALL) -D -m 0755 $(HOST_DIR)/bin/clang $(HOST_DIR)/bin/fex-system-clang; \
	fi
	if [ -x $(HOST_DIR)/bin/clang++.br_real ]; then \
		$(INSTALL) -D -m 0755 $(HOST_DIR)/bin/clang++.br_real $(HOST_DIR)/bin/fex-system-clang++; \
	elif [ -x $(HOST_DIR)/bin/clang++ ]; then \
		$(INSTALL) -D -m 0755 $(HOST_DIR)/bin/clang++ $(HOST_DIR)/bin/fex-system-clang++; \
	fi
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/fex-emu/fex-host-clang \
		$(HOST_DIR)/bin/fex-host-clang
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/fex-emu/fex-host-clang++ \
		$(HOST_DIR)/bin/fex-host-clang++
endef

FEX_EMU_PRE_CONFIGURE_HOOKS += FEX_EMU_PREPARE_GUEST_THUNK_ENV

HOST_FEX_EMU_CMAKE_BACKEND = ninja
HOST_FEX_EMU_SUPPORTS_IN_SOURCE_BUILD = NO
HOST_FEX_EMU_DEPENDENCIES += host-clang host-fmt host-nasm host-openssl
HOST_FEX_EMU_CONF_OPTS += -DCMAKE_PREFIX_PATH=$(HOST_DIR)/lib/cmake
HOST_FEX_EMU_CONF_OPTS += -DClang_DIR=$(HOST_DIR)/lib/cmake/clang
HOST_FEX_EMU_CONF_OPTS += -DLLVM_DIR=$(HOST_DIR)/lib/cmake/llvm
HOST_FEX_EMU_CONF_OPTS += -DCMAKE_CXX_STANDARD=20
HOST_FEX_EMU_CONF_OPTS += -DCMAKE_CXX_STANDARD_REQUIRED=ON
HOST_FEX_EMU_CONF_OPTS += -DCMAKE_C_COMPILER=/usr/bin/gcc
HOST_FEX_EMU_CONF_OPTS += -DCMAKE_CXX_COMPILER=/usr/bin/g++
HOST_FEX_EMU_CONF_OPTS += -DCMAKE_ASM_COMPILER=/usr/bin/gcc
HOST_FEX_EMU_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
HOST_FEX_EMU_CONF_OPTS += -DCMAKE_C_FLAGS=-O2
HOST_FEX_EMU_CONF_OPTS += -DCMAKE_CXX_FLAGS=-O2
HOST_FEX_EMU_RPATH = \$$ORIGIN/../lib
HOST_FEX_EMU_CONF_OPTS += -DCMAKE_EXE_LINKER_FLAGS=-L$(HOST_DIR)/lib
HOST_FEX_EMU_CONF_OPTS += -DCMAKE_SHARED_LINKER_FLAGS=-L$(HOST_DIR)/lib
HOST_FEX_EMU_CONF_OPTS += -DCMAKE_BUILD_RPATH=$(HOST_FEX_EMU_RPATH)
HOST_FEX_EMU_CONF_OPTS += -DCMAKE_INSTALL_RPATH=$(HOST_FEX_EMU_RPATH)
HOST_FEX_EMU_CONF_OPTS += -DBUILD_THUNKS=True
HOST_FEX_EMU_CONF_OPTS += -DBUILD_32BIT_GUEST_THUNKS=False
HOST_FEX_EMU_CONF_OPTS += -DBUILD_FEXCONFIG=False
HOST_FEX_EMU_CONF_OPTS += -DTHUNKGEN_ONLY=True
HOST_FEX_EMU_CONF_OPTS += -DENABLE_X86_HOST_DEBUG=True
HOST_FEX_EMU_CONF_OPTS += -DENABLE_LTO=False
HOST_FEX_EMU_CONF_OPTS += -DCLANG_RESOURCE_DIR=$(HOST_DIR)/lib/clang/20
HOST_FEX_EMU_CONF_OPTS += -DTUNE_CPU=none
HOST_FEX_EMU_CONF_OPTS += -DTUNE_ARCH=generic

define HOST_FEX_EMU_CONFIGURE_CMDS
	(mkdir -p $(HOST_FEX_EMU_BUILDDIR) $(HOST_FEX_EMU_BUILDDIR)/tmp && \
	cd $(HOST_FEX_EMU_BUILDDIR) && \
	rm -f CMakeCache.txt && \
	PATH="$(HOST_DIR)/bin:$(HOST_DIR)/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
	PKG_CONFIG="$(HOST_DIR)/bin/pkg-config" \
	PKG_CONFIG_SYSROOT_DIR="/" \
	PKG_CONFIG_LIBDIR="$(HOST_DIR)/lib/pkgconfig:$(HOST_DIR)/share/pkgconfig" \
	PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1 \
	PKG_CONFIG_ALLOW_SYSTEM_LIBS=1 \
	TMPDIR="$(HOST_FEX_EMU_BUILDDIR)/tmp" \
	THUNKGEN_EXTRA_FLAGS="-isystem $(HOST_DIR)/$(GNU_TARGET_NAME)/sysroot/usr/include" \
	CFLAGS= CXXFLAGS= CPPFLAGS= LDFLAGS= CCC_OVERRIDE_OPTIONS= \
	$(HOST_DIR)/bin/cmake $(HOST_FEX_EMU_SRCDIR) \
		-G"Ninja" \
		-DCMAKE_MAKE_PROGRAM="$(HOST_DIR)/bin/ninja" \
		-DCMAKE_INSTALL_PREFIX="$(HOST_DIR)" \
		$(HOST_FEX_EMU_CONF_OPTS))
endef

define HOST_FEX_EMU_BUILD_CMDS
	PATH="$(HOST_DIR)/bin:$(HOST_DIR)/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
	TMPDIR="$(HOST_FEX_EMU_BUILDDIR)/tmp" \
	CFLAGS= CXXFLAGS= CPPFLAGS= LDFLAGS= CCC_OVERRIDE_OPTIONS= \
	$(HOST_DIR)/bin/cmake --build $(HOST_FEX_EMU_BUILDDIR) --target thunkgen -j$(PARALLEL_JOBS)
endef

define HOST_FEX_EMU_INSTALL_CMDS
	$(INSTALL) -D -m 0755 \
		$(HOST_FEX_EMU_BUILDDIR)/Bin/thunkgen \
		$(HOST_DIR)/bin/fex-thunkgen
endef

define FEX_EMU_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) DESTDIR=$(TARGET_DIR) \
		$(HOST_DIR)/bin/cmake --install $(FEX_EMU_BUILDDIR)
endef

# Always ship S30fex-emu when FEX is built. The script is a no-op at boot
# unless ports.ports_translator=fex, so Box64 stays the default binfmt.
# Without this file, batocera-ports-translator silently fails to switch to FEX.
define FEX_EMU_INSTALL_TARGET_BINFMT
	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/fex-emu/S30fex-emu \
		$(TARGET_DIR)/etc/init.d/S30fex-emu
endef

FEX_EMU_POST_INSTALL_TARGET_HOOKS += FEX_EMU_INSTALL_TARGET_BINFMT

$(eval $(cmake-package))
$(eval $(host-cmake-package))
