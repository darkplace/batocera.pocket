################################################################################
#
# mesa3d-turnip-gamescope-sm8550
#
################################################################################

MESA3D_TURNIP_GAMESCOPE_SM8550_VERSION = 26.1.6
MESA3D_TURNIP_GAMESCOPE_SM8550_SOURCE = mesa-$(MESA3D_TURNIP_GAMESCOPE_SM8550_VERSION).tar.xz
MESA3D_TURNIP_GAMESCOPE_SM8550_SITE = https://archive.mesa3d.org
MESA3D_TURNIP_GAMESCOPE_SM8550_LICENSE = MIT, SGI, Khronos
MESA3D_TURNIP_GAMESCOPE_SM8550_LICENSE_FILES = \
	docs/license.rst \
	licenses/MIT \
	licenses/SGI-B-2.0

MESA3D_TURNIP_GAMESCOPE_SM8550_DEPENDENCIES = \
	mesa3d \
	host-bison \
	host-flex \
	host-glslang \
	host-python-glslang \
	host-python-mako \
	host-python-pyyaml \
	expat \
	libdrm \
	libxcb \
	spirv-tools \
	wayland \
	wayland-protocols \
	xlib_libX11 \
	xlib_libXdamage \
	xlib_libXext \
	xlib_libXfixes \
	xlib_libXrandr \
	xlib_libXxf86vm \
	xlib_libxshmfence \
	xorgproto \
	zlib \
	zstd

MESA3D_TURNIP_GAMESCOPE_SM8550_CONF_OPTS = \
	-Dmicrosoft-clc=disabled \
	-Dllvm=disabled \
	-Dgallium-rusticl=false \
	-Dglx=disabled \
	-Dgallium-drivers= \
	-Dgallium-extra-hud=false \
	-Dvulkan-drivers=freedreno \
	-Dvulkan-layers= \
	-Dvideo-codecs= \
	-Dopengl=false \
	-Dgallium-va=disabled \
	-Dplatforms=x11,wayland \
	-Dgbm=disabled \
	-Degl=disabled \
	-Dgles1=disabled \
	-Dgles2=disabled \
	-Dvalgrind=disabled \
	-Dlibunwind=disabled \
	-Dlmsensors=disabled \
	-Dzstd=enabled \
	-Dglvnd=disabled

define MESA3D_TURNIP_GAMESCOPE_SM8550_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 \
		$(@D)/build/src/freedreno/vulkan/libvulkan_freedreno.so \
		$(TARGET_DIR)/usr/lib/libvulkan_freedreno_gamescope.so
	icd_json="$$(find $(@D)/build/src/freedreno/vulkan -name 'freedreno_icd*.json' -print -quit)"; \
		test -n "$${icd_json}" || exit 1; \
		$(INSTALL) -D -m 0644 "$${icd_json}" \
			$(TARGET_DIR)/usr/share/vulkan/icd.d/freedreno_icd.gamescope.json; \
		$(SED) 's#libvulkan_freedreno\.so#libvulkan_freedreno_gamescope.so#g' \
			$(TARGET_DIR)/usr/share/vulkan/icd.d/freedreno_icd.gamescope.json
endef

$(eval $(meson-package))
