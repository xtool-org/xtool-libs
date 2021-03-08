LIBS += plist

plist_PLATFORMS := $(ALL_PLATFORMS)

plist_CONFIGURE_FLAGS := --without-cython
plist_MAKEFLAGS := bin_PROGRAMS=""

plist_DIR := libplist
plist_AUTOGEN_FILES := configure.ac Makefile.am
plist_HEADERS := plist/plist.h
plist_LIB := libplist-2.0.dylib
