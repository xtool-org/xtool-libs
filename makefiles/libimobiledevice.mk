LIBS += libimobiledevice

libimobiledevice_DEPS := usbmuxd plist
libimobiledevice_PLATFORMS := $(ALL_PLATFORMS)

# --enable-debug
libimobiledevice_CONFIGURE_FLAGS := --without-cython
libimobiledevice_MAKEFLAGS := bin_PROGRAMS=""
export openssl_LIBS = -L$(ROOT_DIR)/OpenSSL/$(CURR_PLATFORM)/lib -lssl -lcrypto
export openssl_CFLAGS = -I$(ROOT_DIR)/OpenSSL/$(CURR_PLATFORM)/include

libimobiledevice_DIR := libimobiledevice
libimobiledevice_AUTOGEN_FILES := configure.ac Makefile.am
libimobiledevice_HEADERS := libimobiledevice
libimobiledevice_LIB := libimobiledevice-1.0.dylib
