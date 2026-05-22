TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
DEBUG = 0
FINALPACKAGE = 1
# Use deb by default for jailbreak package managers.
# For TrollStore IPA builds run: make package PACKAGE_FORMAT=ipa
PACKAGE_FORMAT ?= deb

THEOS_PACKAGE_SCHEME ?= roothide
THEOS_PACKAGE_DIR ?= ./packages/$(THEOS_PACKAGE_SCHEME)

include $(THEOS)/makefiles/common.mk

ZIP_ARCHIVE_DEFINES = -DHAVE_INTTYPES_H -DHAVE_PKCRYPT -DHAVE_STDINT_H -DHAVE_WZAES -DHAVE_ZLIB
DEPS_PATH = ../../deps

APPLICATION_NAME = SDKViewerMobile

$(APPLICATION_NAME)_FILES = \
src/main.m \
src/SDKVAppDelegate.m \
src/SDKVParser.m \
src/SDKVPointerGenerator.m \
src/SDKVProjectStore.m \
src/SDKVRootViewController.m \
$(DEPS_PATH)/SSZipArchive/SSZipArchive.m \
$(wildcard $(DEPS_PATH)/SSZipArchive/minizip/*.c)

$(APPLICATION_NAME)_CFLAGS = -fobjc-arc $(ZIP_ARCHIVE_DEFINES) -Wno-deprecated-declarations
$(APPLICATION_NAME)_CFLAGS += -I$(DEPS_PATH) -I$(DEPS_PATH)/SSZipArchive -I$(DEPS_PATH)/SSZipArchive/minizip
$(APPLICATION_NAME)_FRAMEWORKS = UIKit Foundation UniformTypeIdentifiers MobileCoreServices SwiftUI
$(APPLICATION_NAME)_LDFLAGS = -lz -liconv
$(APPLICATION_NAME)_RESOURCE_DIRS = Resources
$(APPLICATION_NAME)_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

# $(APPLICATION_NAME)_RESOURCE_FILES = 
# 	Resources/Assets.xcassets/AppIcon.appiconset/20.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/29.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/40.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/50.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/57.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/58.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/60.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/72.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/76.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/80.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/87.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/100.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/114.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/120.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/144.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/152.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/167.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/180.png \
# 	Resources/Assets.xcassets/AppIcon.appiconset/1024.png
