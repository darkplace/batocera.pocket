################################################################################
#
# ryujinx
#
################################################################################

RYUJINX_VERSION = 1.3.3
RYUJINX_SITE = https://git.ryujinx.app/ryubing/ryujinx.git
RYUJINX_SITE_METHOD = git
RYUJINX_LICENSE = MIT
RYUJINX_LICENSE_FILES = LICENSE.txt
RYUJINX_STRIP = NO
RYUJINX_DEPENDENCIES = host-dotnet-sdk-bin host-icu icu sdl2 openal hicolor-icon-theme \
	adwaita-icon-theme librsvg

ifeq ($(BR2_x86_64),y)
RYUJINX_RUNTIME_IDENTIFIER = linux-x64
else ifeq ($(BR2_aarch64),y)
RYUJINX_RUNTIME_IDENTIFIER = linux-arm64
endif

RYUJINX_DOTNET_ENV = \
	DOTNET_CLI_HOME=$(@D)/.dotnet \
	DOTNET_CLI_TELEMETRY_OPTOUT=1 \
	DOTNET_NOLOGO=1 \
	DOTNET_ROOT=$(HOST_DIR)/opt/dotnet \
	DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
	HOME=$(@D)/.dotnet \
	LD_LIBRARY_PATH=$(HOST_DIR)/lib \
	NUGET_PACKAGES=$(@D)/.nuget/packages \
	PATH=$(HOST_DIR)/bin:$(BR_PATH)

define RYUJINX_BUILD_CMDS
	mkdir -p $(@D)/.dotnet $(@D)/.nuget/packages $(@D)/target/publish
	cd $(@D) && \
	    $(RYUJINX_DOTNET_ENV) \
	    dotnet publish src/Ryujinx/Ryujinx.csproj \
		-c Release \
		-r $(RYUJINX_RUNTIME_IDENTIFIER) \
		--self-contained true \
		--disable-build-servers \
		-p:DebugSymbols=false \
		-p:DebugType=none \
		-p:Version=$(RYUJINX_VERSION) \
		-o $(@D)/target/publish
endef

define RYUJINX_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/ryujinx
	cp -pr $(@D)/target/publish/* $(TARGET_DIR)/usr/ryujinx

	# evmap config
	mkdir -p $(TARGET_DIR)/usr/share/evmapy
	cp $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/ryujinx/switch.ryujinx.keys \
		$(TARGET_DIR)/usr/share/evmapy/
endef

$(eval $(generic-package))
