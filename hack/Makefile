BUILD_TYPE ?= "RelWithDebInfo"
FLAGS ?=

INSTALL_PREFIX ?= /usr
INSTALL_LIBDIR ?= $(INSTALL_PREFIX)/lib

LIBGIT2_VERSION ?= 1.2.0
# Overwritten to a specific version by default for git2go support
# Ref: https://github.com/libgit2/git2go/issues/834
LIBGIT2_REVISION ?= 109b4c887ffb63962c7017a66fc4a1f48becb48e

ifeq ($(LIBGIT2_REVISION),)
LIBGIT2_DOWNLOAD_URL ?= https://github.com/libgit2/libgit2/archive/refs/tags/v$(LIBGIT2_VERSION).tar.gz
else
LIBGIT2_DOWNLOAD_URL ?= https://github.com/libgit2/libgit2/archive/$(LIBGIT2_REVISION).tar.gz
endif

$(INSTALL_LIBDIR)/libgit2.so.$(LIBGIT2_VERSION):
	set -e; \
	SETUP_LIBGIT2_TMP_DIR=$$(mktemp -d) \
	&& curl -L $(LIBGIT2_DOWNLOAD_URL) -o $$SETUP_LIBGIT2_TMP_DIR/archive.tar.gz \
	&& mkdir -p $$SETUP_LIBGIT2_TMP_DIR/src \
	&& tar xzf $$SETUP_LIBGIT2_TMP_DIR/archive.tar.gz --strip 1 -C $$SETUP_LIBGIT2_TMP_DIR/src \
	&& cmake -S $$SETUP_LIBGIT2_TMP_DIR/src -B $$SETUP_LIBGIT2_TMP_DIR/build \
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
	  -DUSE_HTTPS:STRING=OpenSSL \
	  -DUSE_SSH:BOOL=ON \
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
