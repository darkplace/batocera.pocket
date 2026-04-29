################################################################################
#
# dwarfs
#
################################################################################

DWARFS_VERSION = 0.14.1
DWARFS_SITE = https://github.com/mhx/dwarfs/releases/download/v$(DWARFS_VERSION)
DWARFS_SOURCE = dwarfs-$(DWARFS_VERSION).tar.xz
DWARFS_LICENSE = GPL-3.0+, MIT, Apache-2.0, BSL-1.0
DWARFS_LICENSE_FILES = \
	LICENSE \
	LICENSE.GPL-3.0 \
	folly/LICENSE \
	fbthrift/LICENSE \
	fsst/LICENSE \
	ricepp/LICENSE
DWARFS_INSTALL_STAGING = YES
DWARFS_DEPENDENCIES = \
	boost \
	double-conversion \
	fmt \
	glog \
	libarchive \
	libevent \
	libfuse3 \
	openssl \
	parallel-hashmap \
	range-v3 \
	utfcpp \
	xxhash \
	zstd \
	host-pkgconf

DWARFS_FOLLY_HAVE_UNALIGNED_ACCESS = 0

ifeq ($(BR2_i386)$(BR2_x86_64)$(BR2_aarch64),y)
DWARFS_FOLLY_HAVE_UNALIGNED_ACCESS = 1
endif

DWARFS_CONF_OPTS = \
	-DFETCHCONTENT_FULLY_DISCONNECTED=ON \
	-DCMAKE_DISABLE_FIND_PACKAGE_Libiberty=ON \
	-DDISABLE_CCACHE=ON \
	-DDISABLE_MOLD=ON \
	-DENABLE_PERFMON=OFF \
	-DENABLE_RICEPP=OFF \
	-DTRY_ENABLE_BROTLI=OFF \
	-DTRY_ENABLE_FLAC=OFF \
	-DTRY_ENABLE_LZ4=OFF \
	-DTRY_ENABLE_LZMA=OFF \
	-DUSE_JEMALLOC=OFF \
	-DFOLLY_HAVE_LINUX_VDSO=1 \
	-DFOLLY_HAVE_WEAK_SYMBOLS=1 \
	-DFOLLY_HAVE_WCHAR_SUPPORT=1 \
	-DHAVE_VSNPRINTF_ERRORS=1 \
	-DWITH_BENCHMARKS=OFF \
	-DWITH_DESKTOP_INTEGRATION=OFF \
	-DWITH_DEV_TOOLS=OFF \
	-DWITH_EXAMPLE=OFF \
	-DWITH_FUZZ=OFF \
	-DWITH_FUSE_DRIVER=ON \
	-DWITH_FUSE_EXTRACT_BINARY=OFF \
	-DWITH_LIBDWARFS=ON \
	-DWITH_MAN_PAGES=OFF \
	-DWITH_PXATTR=OFF \
	-DWITH_TESTS=OFF \
	-DWITH_TOOLS=ON \
	-DFOLLY_HAVE_UNALIGNED_ACCESS=$(DWARFS_FOLLY_HAVE_UNALIGNED_ACCESS)

$(eval $(cmake-package))
