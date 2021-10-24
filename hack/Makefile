# This determines if we are building while making use of xx. Ensuring
# the package directives target the right manager and inject (OS) vendor
# specific configurations.
IS_XX := $(shell command -v xx-info 2> /dev/null)
ifdef IS_XX
XX_VENDOR ?= $(shell xx-info vendor)
endif

# Libgit2 build configuration flags.
INSTALL_PREFIX ?= /usr
ifndef IS_XX
INSTALL_LIBDIR ?= $(INSTALL_PREFIX)/lib
else
INSTALL_LIBDIR ?= $(INSTALL_PREFIX)/lib/$(shell xx-info triple)
endif
BUILD_TYPE ?= "RelWithDebInfo"
FLAGS ?=
USE_HTTPS ?= OFF
USE_SSH ?= OFF
BUILD_SHARED_LIBS ?= ON

# Cmake version to be installed.
CMAKE_VERSION ?= 3.21.3

# Libgit2 version to be compiled and installed.
LIBGIT2_VERSION ?= 1.3.0
# In some scenarios libgit2 needs to be checked out to a specific commit.
# This takes presidence over LIBGIT_VERSION if defined.
# Ref: https://github.com/libgit2/git2go/issues/834
LIBGIT2_REVISION ?=

# Set the download URL based on the above information.
ifeq (,$(LIBGIT2_REVISION))
LIBGIT2_DOWNLOAD_URL ?= https://github.com/libgit2/libgit2/archive/refs/tags/v$(LIBGIT2_VERSION).tar.gz
else
LIBGIT2_DOWNLOAD_URL ?= https://github.com/libgit2/libgit2/archive/$(LIBGIT2_REVISION).tar.gz
endif

# OS specific expected lib output.
LIBGIT2 := $(INSTALL_LIBDIR)/libgit2.so.$(LIBGIT2_VERSION)
ifeq (Darwin,$(shell uname -s))
	LIBGIT2 := $(INSTALL_LIBDIR)/libgit2.$(LIBGIT2_VERSION).dylib
	HAS_BREW := $(shell brew --version 2>/dev/null)
endif

cmake:
ifeq (debian,$(XX_VENDOR))
cmake:
	apt-get update && apt-get install --no-install-recommends -y clang cmake
endif
.PHONY: cmake

base:
ifeq (debian,$(XX_VENDOR))
base:
	xx-apt update && xx-apt install --no-install-recommends -y binutils gcc libc6-dev dpkg-dev
endif
.PHONY: base

dependencies: base
ifeq (debian,$(XX_VENDOR))
# Install libssh2 for $TARGETPLATFORM from "sid", as the version in "bullseye"
# has been linked against gcrypt, which causes issues with PKCS* formats.
# We pull (sub)dependencies from there as well, to ensure all versions are aligned,
# and not accidentially linked to e.g. mbedTLS (which has limited support for
# certain key formats).
# Ref: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=668271
# Ref: https://github.com/ARMmbed/mbedtls/issues/2452#issuecomment-802683144
DEPENDENCIES = zlib1g-dev
ifneq ("OFF",$(USE_HTTPS))
DEPENDENCIES += libssl-dev
endif
ifneq ("OFF",$(USE_SSH))
DEPENDENCIES += libssh2-1-dev
endif
dependencies:
	set -e; \
	echo "deb http://deb.debian.org/debian sid main" > /etc/apt/sources.list.d/sid.list \
	&& echo "deb-src http://deb.debian.org/debian sid main" /etc/apt/sources.list.d/sid.list \
	&& xx-apt update \
	&& xx-apt -t sid install --no-install-recommends -y $(DEPENDENCIES)
endif
.PHONY: dependencies

libgit2: $(LIBGIT2)
.PHONY: libgit2

ifdef HAS_BREW
ifneq ("OFF",$(USE_HTTPS))
HAS_OPENSSL := $(shell brew --prefix openssl@1.1)
# NB: the OPENSSL_LDFLAGS ensures the path is included in the libgit2.pc
# file. As a standard brew installation doesn't appear to be system wide
# on most macOS instances, and we thus have to explicitly tell where
# it can be found.
ifdef HAS_OPENSSL
	PKG_CONFIG_PATH := $(PKG_CONFIG_PATH):$(HAS_OPENSSL)/lib/pkgconfig
	FLAGS += -DOPENSSL_LDFLAGS:STRING='-L $(HAS_OPENSSL)/lib'
endif
endif
ifneq ("OFF",$(USE_SSH))
HAS_LIBSSH2 := $(shell brew --prefix libssh2)
ifdef HAS_LIBSSH2
	PKG_CONFIG_PATH := $(PKG_CONFIG_PATH):$(HAS_LIBSSH2)/lib/pkgconfig
endif
endif
endif

$(LIBGIT2):
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
		-DBUILD_SHARED_LIBS:BOOL=$(BUILD_SHARED_LIBS) \
		-DUSE_BUNDLED_ZLIB:BOOL=OFF \
		-DUSE_HTTP_PARSER:STRING=builtin  \
		-DREGEX_BACKEND:STRING=builtin \
		-DUSE_HTTPS:STRING=$(USE_HTTPS) \
		-DUSE_SSH:BOOL=$(USE_SSH) \
		$(FLAGS) \
	&& cmake --build $$SETUP_LIBGIT2_TMP_DIR/build --target install \
	&& rm -rf $$SETUP_LIBGIT2_TMP_DIR
