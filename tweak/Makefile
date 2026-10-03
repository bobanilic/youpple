TARGET := iphone:clang:latest:16.0
ARCHS := arm64
FINALPACKAGE := 1

YP_VERSION := $(or $(shell cat ../version.txt 2>/dev/null),0.0.0)
PACKAGE_VERSION := $(YP_VERSION)

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := youpple
youpple_FILES := $(shell find Sources -name '*.m' -o -name '*.x' | sort)
youpple_CFLAGS := -fobjc-arc -ISources -DYP_VERSION=\"$(YP_VERSION)\"
youpple_FRAMEWORKS := UIKit QuartzCore CoreImage
youpple_LOGOS_DEFAULT_GENERATOR := internal

include $(THEOS_MAKE_PATH)/tweak.mk
