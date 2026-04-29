################################################################################
#
# rockchip-mpp
#
################################################################################

ROCKCHIP_MPP_VERSION = 1.0.9
ROCKCHIP_MPP_SITE = $(call github,HermanChen,mpp,$(ROCKCHIP_MPP_VERSION))
ROCKCHIP_MPP_LICENSE = Apache-2.0 & MIT
ROCKCHIP_MPP_LICENSE_FILES = LICENSES/Apache-2.0 LICENSES/MIT
ROCKCHIP_MPP_INSTALL_STAGING = YES

ROCKCHIP_MPP_DEPENDENCIES = host-pkgconf

ROCKCHIP_MPP_CONF_OPTS = \
	-DRKPLATFORM=ON \
	-DENABLE_AVSD=OFF \
	-DENABLE_H263D=OFF \
	-DENABLE_H264D=ON \
	-DENABLE_H265D=ON \
	-DENABLE_MPEG2D=ON \
	-DENABLE_MPEG4D=ON \
	-DENABLE_VP8D=ON \
	-DENABLE_VP9D=ON \
	-DENABLE_JPEGD=OFF \
	-DENABLE_TEST=OFF \
	-DENABLE_SHARED=ON

$(eval $(cmake-package))
