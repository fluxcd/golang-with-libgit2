BUILD_TYPE ?= "RelWithDebInfo"
FLAGS ?=

INSTALL_PREFIX ?= /usr
INSTALL_LIBDIR ?= $(INSTALL_PREFIX)/lib
USE_HTTPS ?= OpenSSL
USE_SSH ?= ON

LIBGIT2_VERSION ?= 1.1.1
# Overwritten to a specific version by default for git2go support
# Ref: https://github.com/libgit2/git2go/issues/834
LIBGIT2_REVISION ?=

ifeq ($(LIBGIT2_REVISION),)
LIBGIT2_DOWNLOAD_URL ?= https://github.com/libgit2/libgit2/archive/refs/tags/v$(LIBGIT2_VERSION).tar.gz
else
LIBGIT2_DOWNLOAD_URL ?= https://github.com/libgit2/libgit2/archive/$(LIBGIT2_REVISION).tar.gz
endif

LIBGIT2_LIB := $(INSTALL_LIBDIR)/libgit2.so.$(LIBGIT2_VERSION)

PKG_CONFIG_PATH ?=
# Detect Darwin (MacOS) to help the user a bit configuring OpenSSL,
# or at least in pointing out what steps should be taken if it can't
# magically figure it out by itself. Because we too, are nice people.
ifeq ($(shell uname -s),Darwin)
	LIBGIT2_LIB := $(INSTALL_LIBDIR)/libgit2.$(LIBGIT2_VERSION).dylib
	HAS_BREW := $(shell brew --version 2>/dev/null)
ifdef HAS_BREW
HAS_OPENSSL := $(shell brew --prefix openssl@1.1)
ifdef HAS_OPENSSL
	PKG_CONFIG_PATH := $(PKG_CONFIG_PATH):$(HAS_OPENSSL)/lib/pkgconfig
else
	$(warning "Failed to detect openssl@1.1 installation with brew. It can be installed with 'brew install openssl@1.1',")
	$(warning "or an alternative location can be provided using the PKG_CONFIG_PATH flag, for example:")
	$(warning "'PKG_CONFIG_PATH=/usr/local/lib/pkgconfig make'.")
endif
HAS_LIBSSH2 := $(shell brew --prefix libssh2)
ifdef HAS_LIBSSH2
	PKG_CONFIG_PATH := $(PKG_CONFIG_PATH):$(HAS_LIBSSH2)/lib/pkgconfig
else
	$(warning "Failed to detect libssh2 installation with brew. It can be installed with 'brew install libssh2',")
	$(warning "or an alternative location can be provided using the PKG_CONFIG_PATH flag, for example:")
	$(warning "'PKG_CONFIG_PATH=/usr/local/lib/pkgconfig make'.")
endif
else
	$(warning "Failed to detect brew installation, and therefore unable to automatically determine lib paths.")
	$(warning "The location of openssl and libssh2 can be provided using the PKG_CONFIG_PATH flag, for example:")
	$(warning "'PKG_CONFIG_PATH=/usr/local/lib/pkgconfig make'.")
endif
endif

$(LIBGIT2_LIB):
	set -e; \
	SETUP_LIBGIT2_TMP_DIR=$$(mktemp -d) \
	&& curl -L $(LIBGIT2_DOWNLOAD_URL) -o $$SETUP_LIBGIT2_TMP_DIR/archive.tar.gz \
	&& mkdir -p $$SETUP_LIBGIT2_TMP_DIR/src \
	&& tar xzf $$SETUP_LIBGIT2_TMP_DIR/archive.tar.gz --strip 1 -C $$SETUP_LIBGIT2_TMP_DIR/src \
	&& PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) cmake -S $$SETUP_LIBGIT2_TMP_DIR/src -B $$SETUP_LIBGIT2_TMP_DIR/build \
		-DCMAKE_BUILD_TYPE:STRING=$(BUILD_TYPE)\
		-DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON \
		-DCMAKE_C_FLAGS=-fPIC \
		-DDEPRECATE_HARD=ON \
		-DCMAKE_INSTALL_PREFIX:PATH=$(INSTALL_PREFIX) \
		-DCMAKE_INSTALL_LIBDIR:PATH=$(INSTALL_LIBDIR) \
		-DBUILD_CLAR:BOOL:BOOL=OFF \
		-DTHREADSAFE:BOOL=ON \
		-DBUILD_SHARED_LIBS=ON \
		-DUSE_BUNDLED_ZLIB:BOOL=OFF \
		-DUSE_HTTP_PARSER:STRING=builtin  \
		-DREGEX_BACKEND:STRING=builtin \
		-DUSE_HTTPS:STRING=$(USE_HTTPS) \
		-DUSE_SSH:BOOL=$(USE_SSH) \
		$(OS_FLAGS) \
		$(FLAGS) \
	&& cmake --build $$SETUP_LIBGIT2_TMP_DIR/build --target install \
	&& rm -rf $$SETUP_LIBGIT2_TMP_DIR

#    \ && cmake -S $tmp/src -B $tmp/build $(xx-clang --print-cmake-defines) \
#      -DCMAKE_BUILD_TYPE:STRING=$LIBGIT2_BUILD_TYPE \
#      -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON \
#      -DCMAKE_C_FLAGS=-fPIC \
#      -DCMAKE_CXX_FLAGS=-fPIC \
#      -DDEPRECATE_HARD=ON \
#      -DCMAKE_INSTALL_PREFIX:PATH=/usr \
#      -DCMAKE_INSTALL_LIBDIR:PATH=/usr/lib/$(xx-info triple) \
#      -DBUILD_CLAR:BOOL:BOOL=OFF \
#      -DTHREADSAFE:BOOL=ON \
#      -DBUILD_SHARED_LIBS=OFF \
#      -DUSE_BUNDLED_ZLIB:BOOL=OFF \
#      -DUSE_HTTP_PARSER:STRING=builtin  \
#      -DREGEX_BACKEND:STRING=builtin \
#      -DUSE_HTTPS:STRING=OpenSSL \
#      -DUSE_SSH:BOOL=ON \
#    && cmake --build $tmp/build --target install \
