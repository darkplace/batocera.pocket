################################################################################
#
# libclc
#
################################################################################

LIBCLC_VERSION = $(LLVM_PROJECT_VERSION)
LIBCLC_SITE = $(LLVM_PROJECT_SITE)
LIBCLC_SOURCE = libclc-$(LIBCLC_VERSION).src.tar.xz
LIBCLC_LICENSE = Apache-2.0 with exceptions or MIT
LIBCLC_LICENSE_FILES = LICENSE.TXT

LIBCLC_DEPENDENCIES = host-clang host-llvm host-spirv-llvm-translator
HOST_LIBCLC_DEPENDENCIES = host-clang host-llvm host-spirv-llvm-translator
LIBCLC_INSTALL_STAGING = YES

# CMAKE_*_COMPILER_FORCED=ON skips testing the tools and assumes
# llvm-config provided values
#
# CMAKE_*_COMPILER has to be set to the host compiler to build a host
# 'prepare_builtins' tool used during the build process
#
# The headers are installed in /usr/share and not /usr/include,
# because they are needed at runtime on the target to build the OpenCL
# kernels.
LIBCLC_CONF_OPTS = \
	-DCMAKE_SYSROOT="" \
	-DCMAKE_C_COMPILER_FORCED=ON \
	-DCMAKE_CXX_COMPILER_FORCED=ON \
	-DCMAKE_INSTALL_DATADIR="share" \
	-DCMAKE_FIND_ROOT_PATH="$(HOST_DIR)" \
	-DCMAKE_C_FLAGS="$(HOST_CFLAGS)" \
	-DCMAKE_CXX_FLAGS="$(HOST_CXXFLAGS)" \
	-DCMAKE_EXE_LINKER_FLAGS="$(HOST_LDFLAGS)" \
	-DCMAKE_SHARED_LINKER_FLAGS="$(HOST_LDFLAGS)" \
	-DCMAKE_MODULE_LINKER_FLAGS="$(HOST_LDFLAGS)" \
	-DCMAKE_C_COMPILER="$(CMAKE_HOST_C_COMPILER)" \
	-DCMAKE_CXX_COMPILER="$(CMAKE_HOST_CXX_COMPILER)" \
	-DLLVM_CMAKE_DIR="$(HOST_DIR)/lib/cmake/llvm" \
	-DLIBCLC_CUSTOM_LLVM_TOOLS_BINARY_DIR="$(@D)/buildroot-llvm-tools"

HOST_LIBCLC_CONF_OPTS = \
	-DLIBCLC_TARGETS_TO_BUILD=spirv64-mesa3d- \
	-DLIBCLC_CUSTOM_LLVM_TOOLS_BINARY_DIR="$(@D)/buildroot-llvm-tools"

# The clang wrapper injects target tune flags (e.g. -mcpu/-mtune) that break
# libclc's non-CPU target builds (spir*/nvptx/amdgcn). Provide an unwrapped
# clang for both target and host libclc builds.
define LIBCLC_PREPARE_LLVM_TOOLS
	mkdir -p $(@D)/buildroot-llvm-tools
	ln -sf $(HOST_DIR)/bin/clang.br_real $(@D)/buildroot-llvm-tools/clang
	ln -sf $(HOST_DIR)/bin/llvm-as $(@D)/buildroot-llvm-tools/llvm-as
	ln -sf $(HOST_DIR)/bin/llvm-link $(@D)/buildroot-llvm-tools/llvm-link
	ln -sf $(HOST_DIR)/bin/opt $(@D)/buildroot-llvm-tools/opt
endef
LIBCLC_PRE_CONFIGURE_HOOKS += LIBCLC_PREPARE_LLVM_TOOLS
HOST_LIBCLC_PRE_CONFIGURE_HOOKS += LIBCLC_PREPARE_LLVM_TOOLS

$(eval $(cmake-package))
$(eval $(host-cmake-package))
