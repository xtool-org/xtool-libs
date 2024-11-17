LIBS += curl

curl_PLATFORMS := $(ALL_PLATFORMS)

curl_CONFIGURE_FLAGS := --with-secure-transport --without-libpsl --disable-ldap

curl_DIR := curl
curl_AUTOGEN_FILES := configure.ac Makefile.am
curl_HEADERS := curl
curl_LIB := libcurl.dylib
curl_UNPACK := autoreconf -fi
