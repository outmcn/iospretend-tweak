export THEOS := /opt/theos
export THEOS_PACKAGE_SCHEME := rootless
export ARCHS := arm64 arm64e
export TARGET := iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := iOSPretendGPS iOSPretendDevice

iOSPretendGPS_FILES := GPSTweak.xm
iOSPretendGPS_CFLAGS := -fobjc-arc -Wall
iOSPretendGPS_FRAMEWORKS := Foundation CoreLocation

iOSPretendDevice_FILES := SimTweak.x
iOSPretendDevice_CFLAGS := -fobjc-arc -Wall
iOSPretendDevice_FRAMEWORKS := Foundation CoreTelephony

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
