include $(THEOS)/makefiles/common.mk

BUNDLE_NAME := iOSPretendPrefs
iOSPretendPrefs_FILES := iOSPretendRootListController.m iOSPretendMapPickerController.m iOSPretendAppSelectionController.m iOSPretendFavoriteLocationsController.m
iOSPretendPrefs_CFLAGS := -fobjc-arc -Wall
iOSPretendPrefs_FRAMEWORKS := UIKit MapKit CoreLocation
iOSPretendPrefs_PRIVATE_FRAMEWORKS := Preferences
iOSPretendPrefs_INSTALL_PATH := /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
