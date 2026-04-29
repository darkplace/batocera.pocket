################################################################################
#
# freej2me
#
################################################################################

FREEJ2ME_VERSION = 6c534cb88d429ec638d84381185b9aa808c8b584
FREEJ2ME_SITE = $(call github,hex007,freej2me,$(FREEJ2ME_VERSION))
FREEJ2ME_LICENSE = GPL-3.0
FREEJ2ME_LICENSE_FILES = LICENSE

FREEJ2ME_DEPENDENCIES = openjdk host-openjdk-bin sdl2 libfreeimage

define FREEJ2ME_BUILD_CMDS
	mkdir -p $(@D)/build/classes
	cd $(@D) && find src -name '*.java' | sort > build/sources.list
	cd $(@D) && $(JAVAC) -encoding UTF-8 -d build/classes @build/sources.list
	cd $(@D) && $(HOST_OPENJDK_BIN_ROOT_DIR)/bin/jar --create --file build/freej2me.jar \
		--main-class org.recompile.freej2me.FreeJ2ME \
		-C build/classes . \
		-C resources . \
		-C META-INF .
	cd $(@D) && $(HOST_OPENJDK_BIN_ROOT_DIR)/bin/jar --create --file build/freej2me-sdl.jar \
		--main-class org.recompile.freej2me.Anbu \
		-C build/classes . \
		-C resources . \
		-C META-INF .
	SDL2_CONFIG="$(STAGING_DIR)/usr/bin/sdl2-config"; \
	"$${CXX:-$(TARGET_CXX)}" $(TARGET_CXXFLAGS) $(TARGET_LDFLAGS) -std=c++11 \
		-o $(@D)/build/sdl_interface $(@D)/src/sdl2/anbu.cpp \
		$$("$${SDL2_CONFIG}" --cflags --libs) -lfreeimage -lpthread
endef

define FREEJ2ME_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/build/freej2me.jar \
		$(TARGET_DIR)/usr/share/freej2me/freej2me.jar
	$(INSTALL) -D -m 0644 $(@D)/build/freej2me-sdl.jar \
		$(TARGET_DIR)/usr/share/freej2me/freej2me-sdl.jar
	$(INSTALL) -D -m 0755 $(@D)/build/sdl_interface \
		$(TARGET_DIR)/usr/bin/sdl_interface
	mkdir -p $(TARGET_DIR)/usr/local/bin
	ln -sf ../../bin/sdl_interface $(TARGET_DIR)/usr/local/bin/sdl_interface
	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/freej2me/freej2me.sh \
		$(TARGET_DIR)/usr/bin/freej2me
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/freej2me/freej2me.keys \
		$(TARGET_DIR)/usr/share/evmapy/j2me.freej2me.keys
endef

$(eval $(generic-package))
