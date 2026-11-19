TARGET := iphone:clang:latest:15.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = WeChat
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = LiquidTabBar
LiquidTabBar_FILES = Tweak.xm LTBCore.m LTBUI.m
LiquidTabBar_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
LiquidTabBar_FRAMEWORKS = UIKit AVFoundation MediaPlayer QuartzCore
include $(THEOS_MAKE_PATH)/tweak.mk
