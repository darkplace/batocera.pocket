################################################################################
#
# openssl102-compat
#
################################################################################

OPENSSL102_COMPAT_VERSION = 1.0.2u
OPENSSL102_COMPAT_SITE = http://www.openssl.org/source
OPENSSL102_COMPAT_SOURCE = openssl-$(OPENSSL102_COMPAT_VERSION).tar.gz
OPENSSL102_COMPAT_LICENSE = OpenSSL OR SSLeay
OPENSSL102_COMPAT_LICENSE_FILES = LICENSE

# Runtime compatibility package only: avoid staging old headers/pkg-config.
OPENSSL102_COMPAT_INSTALL_STAGING = NO
OPENSSL102_COMPAT_DEPENDENCIES = zlib

define OPENSSL102_COMPAT_CONFIGURE_CMDS
	(cd $(@D); \
		$(TARGET_CONFIGURE_ARGS) \
		$(TARGET_CONFIGURE_OPTS) \
		./Configure \
			linux-generic32 \
			--prefix=/usr \
			--openssldir=/etc/ssl \
			--libdir=lib \
			shared \
			zlib-dynamic \
			no-ssl2 \
			no-ssl3 \
	)
	$(SED) "s#-O[0-9]#$(TARGET_CFLAGS)#" $(@D)/Makefile
endef

define OPENSSL102_COMPAT_BUILD_CMDS
	$(MAKE1) -C $(@D) depend
	$(MAKE1) -C $(@D) build_libs
endef

define OPENSSL102_COMPAT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/libcrypto.so.1.0.0 \
		$(TARGET_DIR)/usr/lib/libcrypto.so.1.0.0
	$(INSTALL) -D -m 0755 $(@D)/libssl.so.1.0.0 \
		$(TARGET_DIR)/usr/lib/libssl.so.1.0.0
endef

$(eval $(generic-package))
