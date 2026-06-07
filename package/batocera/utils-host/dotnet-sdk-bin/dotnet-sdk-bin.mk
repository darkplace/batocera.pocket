################################################################################
#
# dotnet-sdk-bin
#
################################################################################

DOTNET_SDK_BIN_VERSION = 9.0.314
DOTNET_SDK_BIN_LICENSE = MIT
DOTNET_SDK_BIN_LICENSE_FILES = LICENSE.txt

ifeq ($(HOSTARCH),x86_64)
DOTNET_SDK_BIN_ARCH = x64
else ifeq ($(HOSTARCH),aarch64)
DOTNET_SDK_BIN_ARCH = arm64
endif

DOTNET_SDK_BIN_SOURCE = dotnet-sdk-$(DOTNET_SDK_BIN_VERSION)-linux-$(DOTNET_SDK_BIN_ARCH).tar.gz
DOTNET_SDK_BIN_SITE = https://builds.dotnet.microsoft.com/dotnet/Sdk/$(DOTNET_SDK_BIN_VERSION)

HOST_DOTNET_SDK_BIN_INSTALL_DIR = $(HOST_DIR)/opt/dotnet

define HOST_DOTNET_SDK_BIN_INSTALL_CMDS
	rm -rf $(HOST_DOTNET_SDK_BIN_INSTALL_DIR)
	mkdir -p $(HOST_DOTNET_SDK_BIN_INSTALL_DIR) $(HOST_DIR)/bin $(HOST_DIR)/usr/bin
	cp -rpd $(@D)/* $(HOST_DOTNET_SDK_BIN_INSTALL_DIR)/
	ln -sf ../opt/dotnet/dotnet $(HOST_DIR)/bin/dotnet
	ln -sf ../opt/dotnet/dotnet $(HOST_DIR)/usr/bin/dotnet
endef

$(eval $(host-generic-package))
