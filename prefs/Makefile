TARGET = iphone:clang::11.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = QuietDown
QuietDown_CFLAGS = -fobjc-arc
QuietDown_FILES = QDRootListController.m
QuietDown_INSTALL_PATH = /Library/PreferenceBundles
QuietDown_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/QuietDown.plist$(ECHO_END)
