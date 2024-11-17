LIBS += tatsu

tatsu_DEPS := curl
tatsu_PLATFORMS := $(ALL_PLATFORMS)

tatsu_CONFIGURE_FLAGS :=
tatsu_MAKEFLAGS := bin_PROGRAMS=""

tatsu_DIR := libtatsu
tatsu_AUTOGEN_FILES := configure.ac Makefile.am
tatsu_HEADERS := libtatsu
tatsu_LIB := libtatsu.dylib
