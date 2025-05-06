ALL_PLATFORMS := iphoneos iphonesimulator macosx
ALL_ARCHS := arm64 x86_64

ROOT_DIR := $(shell pwd)
BUILD_DIR := $(ROOT_DIR)/build
OUTPUT_DIR := $(ROOT_DIR)/output

XTLIBS_MAKEFLAGS := --no-keep-going --no-print-directory
MAKEFLAGS += $(XTLIBS_MAKEFLAGS)

# Platform config

iphoneos_ARCHS := arm64
iphoneos_CFLAGS := -miphoneos-version-min=8.0
iphoneos_TRIPLE_SUFFIX := apple-darwin

iphonesimulator_ARCHS := arm64 x86_64
iphonesimulator_CFLAGS := -mios-simulator-version-min=8.0
iphonesimulator_TRIPLE_SUFFIX := apple-darwin_sim

macosx_ARCHS := arm64 x86_64
macosx_CFLAGS := -mmacosx-version-min=10.11
macosx_TRIPLE_SUFFIX := apple-darwin
macosx_IS_HIERARCHICAL := 1

# Arch config

arm64_TRIPLE_PREFIX := aarch64

x86_64_TRIPLE_PREFIX := x86_64

# Targets

all::

include $(wildcard makefiles/*.mk)

.PHONY: before-all all clean FORCE
all:: $(LIBS)
$(LIBS): before-all
FORCE:

clean::
	@rm -rf $(BUILD_DIR)

$(BUILD_DIR):: $(filter clean,$(MAKECMDGOALS))
	@mkdir -p "$@"

$(OUTPUT_DIR)::
	@mkdir -p "$@"

before-all:: $(BUILD_DIR) $(OUTPUT_DIR)

after-all::

define LIB_TEMPLATE
.PHONY: $(1)
$(1): $($(1)_DEPS)
	@+$(MAKE) $(XTLIBS_MAKEFLAGS) CURR_LIB=$(1) build-lib
endef
$(foreach lib,$(LIBS),$(eval $(call LIB_TEMPLATE,$(lib))))

ifneq ($(CURR_LIB),)
.PHONY: build-lib invoke-platform-%

define XTLIBS_LIB_MODULEMAP
framework module $(CURR_LIB) {
    umbrella "."
}
endef
export XTLIBS_LIB_MODULEMAP
define XTLIBS_LIB_INFOPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleExecutable</key>
	<string>$(CURR_LIB)</string>
	<key>CFBundleIdentifier</key>
	<string>com.kabiroberai.$(CURR_LIB)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>1</string>
</dict>
</plist>
endef
export XTLIBS_LIB_INFOPLIST

XTLIBS_LIB_STAMPS_DIR := $(BUILD_DIR)/stamps/$(CURR_LIB)
XTLIBS_LIB_AUTOGEN_FILES := $(addprefix $($(CURR_LIB)_DIR)/,$($(CURR_LIB)_AUTOGEN_FILES))
XTLIBS_LIB_AUTOGEN_STAMP := $(XTLIBS_LIB_STAMPS_DIR)/autogen.stamp
XTLIBS_LIB_XCFRAMEWORKS_DIR := $(BUILD_DIR)/xcframeworks
XTLIBS_LIB_XCFRAMEWORK := $(XTLIBS_LIB_XCFRAMEWORKS_DIR)/$(CURR_LIB).xcframework
XTLIBS_LIB_XCFRAMEWORK_ZIP := $(OUTPUT_DIR)/$(CURR_LIB).xcframework.zip

build-lib: $(XTLIBS_LIB_AUTOGEN_STAMP)
	@+$(MAKE) $(XTLIBS_MAKEFLAGS) $(XTLIBS_LIB_XCFRAMEWORK_ZIP)

$(XTLIBS_LIB_AUTOGEN_STAMP): $(XTLIBS_LIB_AUTOGEN_FILES)
	@rm -rf $@.tmp
	@mkdir -p $(dir $@)
	@touch $@.tmp
	cd $($(CURR_LIB)_DIR) && NOCONFIGURE=1 $(or $($(CURR_LIB)_UNPACK),./autogen.sh)
	@mv -f $@.tmp $@

$(XTLIBS_LIB_XCFRAMEWORK): $(foreach plat,$($(CURR_LIB)_PLATFORMS),invoke-platform-$(plat))
	@rm -rf $@
	@mkdir -p $(dir $@)
	xcodebuild -create-xcframework $(foreach plat,$($(CURR_LIB)_PLATFORMS),-framework $(BUILD_DIR)/$(plat)/$(CURR_LIB).framework) -output $@

$(XTLIBS_LIB_XCFRAMEWORK_ZIP): $(XTLIBS_LIB_XCFRAMEWORK)
	@rm -rf $@
	zip -yqr $@ $(XTLIBS_LIB_XCFRAMEWORK)

invoke-platform-%:
	@+$(MAKE) $(XTLIBS_MAKEFLAGS) CURR_PLATFORM=$* build-platform

ifneq ($(CURR_PLATFORM),)
.PHONY: build-platform invoke-arch-%

XTLIBS_PLATFORM_DIR := $(BUILD_DIR)/$(CURR_PLATFORM)
XTLIBS_PLATFORM_FWK := $(XTLIBS_PLATFORM_DIR)/$(CURR_LIB).framework
XTLIBS_PLATFORM_FWK_HEADERS_DIR := $(XTLIBS_PLATFORM_FWK)/Headers
XTLIBS_PLATFORM_FWK_MODULES_DIR := $(XTLIBS_PLATFORM_FWK)/Modules
XTLIBS_PLATFORM_FWK_RESOURCES_DIR = $(XTLIBS_PLATFORM_FWK)$(if $($(CURR_PLATFORM)_IS_HIERARCHICAL),/Resources)

# Just use the first arch's headers
XTLIBS_PLATFORM_FIRST_ARCH_PREFIX := $(XTLIBS_PLATFORM_DIR)/archs/$(firstword $($(CURR_PLATFORM)_ARCHS))/prefix
XTLIBS_PLATFORM_INCLUDE := $(XTLIBS_PLATFORM_FIRST_ARCH_PREFIX)/include
XTLIBS_PLATFORM_LIB_HEADERS := $(XTLIBS_PLATFORM_INCLUDE)/$($(CURR_LIB)_HEADERS)

build-platform: $(foreach arch,$($(CURR_PLATFORM)_ARCHS),invoke-arch-$(arch))
	@rm -rf $(XTLIBS_PLATFORM_FWK)
	@mkdir -p $(XTLIBS_PLATFORM_FWK) $(XTLIBS_PLATFORM_FWK_MODULES_DIR) $(XTLIBS_PLATFORM_FWK_RESOURCES_DIR)
# If XTLIBS_PLATFORM_LIB_HEADERS is an entire dir then make that the framework's Headers
# dir, otherwise create a Headers dir and copy the single header file into it
ifeq ($(suffix $(XTLIBS_PLATFORM_LIB_HEADERS)),.h)
	@mkdir -p $(XTLIBS_PLATFORM_FWK_HEADERS_DIR)
endif
	@cp -a $(XTLIBS_PLATFORM_LIB_HEADERS) $(XTLIBS_PLATFORM_FWK_HEADERS_DIR)
	echo "$${XTLIBS_LIB_MODULEMAP}" | cat > "$(XTLIBS_PLATFORM_FWK_MODULES_DIR)/module.modulemap"
	echo "$${XTLIBS_LIB_INFOPLIST}" | cat > "$(XTLIBS_PLATFORM_FWK_RESOURCES_DIR)/Info.plist"
ifeq ($(words $($(CURR_PLATFORM)_ARCHS)),1)
	@cp -L $(XTLIBS_PLATFORM_FIRST_ARCH_PREFIX)/lib/$($(CURR_LIB)_LIB) $(XTLIBS_PLATFORM_FWK)/$(CURR_LIB)
else
	lipo -create $(foreach arch,$($(CURR_PLATFORM)_ARCHS),$(XTLIBS_PLATFORM_DIR)/archs/$(arch)/prefix/lib/$($(CURR_LIB)_LIB)) -output $(XTLIBS_PLATFORM_FWK)/$(CURR_LIB)
endif
ifeq ($($(CURR_PLATFORM)_IS_HIERARCHICAL),1)
	@mkdir -p $(XTLIBS_PLATFORM_FWK)/Versions/A
	@ln -s A $(XTLIBS_PLATFORM_FWK)/Versions/Current
	@for file in Headers Resources Modules $(CURR_LIB); do \
		mv $(XTLIBS_PLATFORM_FWK)/$${file} $(XTLIBS_PLATFORM_FWK)/Versions/A/; \
		ln -s Versions/Current/$${file} $(XTLIBS_PLATFORM_FWK)/$${file}; \
	done
endif

invoke-arch-%:
	@+$(MAKE) $(XTLIBS_MAKEFLAGS) CURR_ARCH=$* build-arch

ifneq ($(CURR_ARCH),)
.PHONY: build-arch

XTLIBS_ARCH_CONFIG_TAG := $(shell echo $($(CURR_LIB)_CONFIGURE_FLAGS) | shasum | cut -c1-8)
XTLIBS_ARCH_CONFIG_STAMP := $(XTLIBS_LIB_STAMPS_DIR)/configure-$(CURR_PLATFORM)-$(CURR_ARCH).$(XTLIBS_ARCH_CONFIG_TAG).stamp
XTLIBS_ARCH_DIR := $(XTLIBS_PLATFORM_DIR)/archs/$(CURR_ARCH)
XTLIBS_ARCH_PREFIX := $(XTLIBS_ARCH_DIR)/prefix
XTLIBS_ARCH_LIB_BUILD_DIR := $(XTLIBS_ARCH_DIR)/build/$(CURR_LIB)

# TODO: Also clean if switching from one tag to another and then back
# (store latest tag somewhere or something)
build-arch: $(XTLIBS_ARCH_CONFIG_STAMP)
	@+if [[ -f $(XTLIBS_ARCH_CONFIG_STAMP).new ]]; then \
		$(MAKE) -C $(XTLIBS_ARCH_LIB_BUILD_DIR) \
			$(XTLIBS_MAKEFLAGS) $($(CURR_LIB)_MAKEFLAGS) -j1 clean; \
		rm $(XTLIBS_ARCH_CONFIG_STAMP).new; \
	else \
		cd $(XTLIBS_ARCH_LIB_BUILD_DIR) && ./config.status; \
	fi
	@+$(MAKE) -C $(XTLIBS_ARCH_LIB_BUILD_DIR) \
		$(XTLIBS_MAKEFLAGS) $($(CURR_LIB)_MAKEFLAGS) -j1 all install
	install_name_tool -id '@rpath/$(CURR_LIB).framework/$(CURR_LIB)' $(XTLIBS_ARCH_PREFIX)/lib/$($(CURR_LIB)_LIB)

export CC = xcrun -sdk $(CURR_PLATFORM) clang -arch $(CURR_ARCH) -fapplication-extension
export CXX = xcrun -sdk $(CURR_PLATFORM) clang++ -arch $(CURR_ARCH) -fapplication-extension
export CFLAGS = $($(CURR_PLATFORM)_CFLAGS) $($(CURR_LIB)_CFLAGS) -fapplication-extension
export LDFLAGS = -fapplication-extension
export PKG_CONFIG_PATH = $(XTLIBS_ARCH_PREFIX)/lib/pkgconfig

$(XTLIBS_ARCH_CONFIG_STAMP): $(XTLIBS_LIB_AUTOGEN_FILES)
	@rm -rf $@.tmp
	@mkdir -p $(dir $@)
	@touch $@.tmp
	@mkdir -p $(XTLIBS_ARCH_LIB_BUILD_DIR) $(XTLIBS_ARCH_PREFIX)
	cd $(XTLIBS_ARCH_LIB_BUILD_DIR) && \
		$(ROOT_DIR)/$($(CURR_LIB)_DIR)/configure \
			--host=$($(CURR_ARCH)_TRIPLE_PREFIX)-$($(CURR_PLATFORM)_TRIPLE_SUFFIX) \
			--prefix=$(XTLIBS_ARCH_PREFIX) \
			$($(CURR_LIB)_CONFIGURE_FLAGS)
	@mv -f $@.tmp $@
# denotes that the stamp was just configured
	@touch $@.new
endif
endif
endif
