LIBS += libimobiledeviceGlue

libimobiledeviceGlue_DEPS := plist
libimobiledeviceGlue_PLATFORMS := $(ALL_PLATFORMS)

libimobiledeviceGlue_DIR := libimobiledevice-glue
libimobiledeviceGlue_AUTOGEN_FILES := configure.ac Makefile.am
libimobiledeviceGlue_HEADERS := libimobiledevice-glue
libimobiledeviceGlue_LIB := libimobiledevice-glue-1.0.dylib
