LIBS += usbmuxd

usbmuxd_DEPS := plist libimobiledeviceGlue
usbmuxd_PLATFORMS := $(ALL_PLATFORMS)

usbmuxd_MAKEFLAGS := bin_PROGRAMS=""

usbmuxd_DIR := libusbmuxd
usbmuxd_AUTOGEN_FILES := configure.ac Makefile.am
usbmuxd_HEADERS := usbmuxd.h
usbmuxd_LIB := libusbmuxd-2.0.dylib
