################################################################################
#
# 86Box
#
################################################################################

86BOX_VERSION = v5.3
86BOX_SITE = https://github.com/86Box/86Box.git
86BOX_SITE_METHOD = git
86BOX_LICENSE = GPL-2.0-or-later
86BOX_LICENSE_FILES = LICENSE

86BOX_DEPENDENCIES = \
	freetype \
	host-pkgconf \
	libevdev \
	libpng \
	libsndfile \
	openal \
	qt6base \
	qt6tools \
	rtmidi \
	sdl2 \
	slirp \
	libxkbcommon \
	xlib_libXi

86BOX_SUPPORTS_IN_SOURCE_BUILD = NO

86BOX_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
86BOX_CONF_OPTS += -DBUILD_TYPE=release
86BOX_CONF_OPTS += -DRELEASE=ON
86BOX_CONF_OPTS += -DQT=ON -DUSE_QT6=ON
86BOX_CONF_OPTS += -DDISCORD=OFF
86BOX_CONF_OPTS += -DVNC=OFF
86BOX_CONF_OPTS += -DDYNAREC=ON

ifeq ($(BR2_PACKAGE_FLUIDSYNTH),y)
86BOX_CONF_OPTS += -DFLUIDSYNTH=ON
86BOX_DEPENDENCIES += fluidsynth
else
86BOX_CONF_OPTS += -DFLUIDSYNTH=OFF
endif

$(eval $(cmake-package))
