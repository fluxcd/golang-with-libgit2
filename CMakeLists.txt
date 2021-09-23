cmake_minimum_required(VERSION 3.5.1)

project(Superbuild)

# Set a default build type if none was specified
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

option(BUILD_SHARED_LIBS "Build with shared libs." ON)
option(USE_EXTERNAL_INSTALL "If enabled, install dependencies to CMAKE_INSTALL_PREFIX." OFF)
mark_as_advanced(USE_EXTERNAL_INSTALL)

include(ExternalProject)

set_property(DIRECTORY PROPERTY EP_PREFIX ${Superbuild_BINARY_DIR})
set(install_prefix ${Superbuild_BINARY_DIR}/install)
if (USE_EXTERNAL_INSTALL)
  set(install_prefix ${CMAKE_INSTALL_PREFIX})
else()
  mark_as_advanced(CMAKE_INSTALL_PREFIX)
endif()

#[[
Default Cmake configuration flags.
Ref: https://cmake.org/cmake/help/latest/manual/cmake-variables.7.html
]]
set(default_cmake_args
    "-DCMAKE_PREFIX_PATH:PATH=${install_prefix};${DRAKE_SUPERBUILD_PREFIX_PATH};${CMAKE_PREFIX_PATH}"
    "-DCMAKE_INSTALL_PREFIX:PATH=${install_prefix}"
    "-DCMAKE_FIND_ROOT_PATH:PATH=${install_prefix}"
    "-DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}"
    "-DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON"
    "-DBUILD_SHARED_LIBS:BOOL=${BUILD_SHARED_LIBS}"
    "-DENABLE_TESTING:BOOL=OFF"
    "-DENABLE_PROGRAMS:BOOL=OFF"
    "-DBUILD_DOCUMENTATION:BOOL=OFF"
    "-DBUILD_EXAMPLES:BOOL=OFF"
    "-DBUILD_TESTING:BOOL=OFF"
    "-DCMAKE_C_FLAGS:STRING=-fPIC"
)

#[[
Build zlib-ng with zlib compatible API enabled.
]]
ExternalProject_Add(zlib
	URL https://github.com/zlib-ng/zlib-ng/archive/refs/tags/2.0.5.tar.gz
    URL_HASH SHA256=eca3fe72aea7036c31d00ca120493923c4d5b99fe02e6d3322f7c88dbdcd0085
    CMAKE_ARGS
        ${default_cmake_args}
        #[[ Build with ZLIB compatible API ]]
        -DZLIB_COMPAT:BOOL=ON
        -DZLIB_ENABLE_TESTS:BOOL=OFF
        #[[ Required to ensure the current ${install_prefix} is always taken into account,
         as ${CMAKE_INSTALL_PREFIX} is cached persistently.
         Ref: https://github.com/zlib-ng/zlib-ng/blob/2.0.5/cmake/detect-install-dirs.cmake ]]
        -DBIN_INSTALL_DIR:PATH=${install_prefix}/bin
        -DLIB_INSTALL_DIR:PATH=${install_prefix}/lib
        -DINC_INSTALL_DIR:PATH=${install_prefix}/include
        -DPKGCONFIG_INSTALL_DIR:PATH=${install_prefix}/lib/pkgconfig
)

#[[
mbedTLS does at present not support https://github.com/zlib-ng/zlib-ng/blob/2.0.5/cmake/detect-install-dirs.cmakeED25519, making it unsuitable for some SSH setups, and at present not a decent
dependency option for libssh2.

Target review of ED25519 support is Q3 2021.
Ref: https://github.com/ARMmbed/mbedtls/issues/2452#issuecomment-802683144
Ref: https://github.com/ARMmbed/mbedtls/pull/3245

ExternalProject_Add(mbedtls
	URL https://github.com/ARMmbed/mbedtls/archive/refs/tags/v2.27.0.tar.gz
	URL_HASH SHA256=2a07856e541f0e5f6eaee4f78018c52f25bd244ed76f9020dea54a8b02cac6ea
	PATCH_COMMAND
		./scripts/config.pl set MBEDTLS_THREADING_C &&
		./scripts/config.pl set MBEDTLS_THREADING_PTHREAD &&
		./scripts/config.pl set MBEDTLS_MD4_C
	CMAKE_ARGS
		${default_cmake_args}
		-DUSE_SHARED_MBEDTLS_LIBRARY:BOOL=${BUILD_SHARED_LIBS}
)
]]

#[[
Build OpenSSL.
OpenSSL does not publish any cmake directives, and we have to configure everything ourselves.
Ref: https://github.com/openssl/openssl/blob/openssl-3.0.0/INSTALL.md
]]
set(default_openssl_args
    "--prefix=${install_prefix}"
    #[[ Path on the TARGET system where we expect the (certificate) configuration to live.
     The current allows to piggy back off Debian's ca-certificate package  while maintaining our own OpenSSL version. ]]
    "--openssldir=/etc/ssl"
    #[[ Enforce the directory to ${install_prefix}/lib. As depending on the build system, Configure may otherwise choose
     to use /lib64. Which makes locating the libraries more difficult. ]]
    "--libdir=lib"
    "--with-zlib-include=${install_prefix}/include"
    "--with-zlib-lib=${install_prefix}/lib"
    "--release"
    "--banner=Configured"
)
if(NOT BUILD_SHARED_LIBS)
    list(APPEND default_openssl_args "no-shared")
    list(APPEND default_openssl_args "-static")
endif()
ExternalProject_Add(openssl
    DEPENDS zlib
	URL https://www.openssl.org/source/openssl-3.0.0.tar.gz
	URL_HASH SHA256=59eedfcb46c25214c9bd37ed6078297b4df01d012267fe9e9eee31f61bc70536
    CONFIGURE_COMMAND <SOURCE_DIR>/Configure ${default_openssl_args}
    BUILD_COMMAND make build_sw
    INSTALL_COMMAND make install_sw
)

#[[
Build libssh2.
At present with OpenSSL as a backend, see mbedTLS doc block for reasoning.
]]
set(default_libssh2_args
    "-DENABLE_ZLIB_COMPRESSION:BOOL=ON"
	"-DCRYPTO_BACKEND:STRING=OpenSSL"
    #[[ -DCRYPTO_BACKEND:STRING=mbedTLS ]]
)
if(NOT BUILD_SHARED_LIBS)
    list(APPEND default_libssh2_args "-DOPENSSL_USE_STATIC_LIBS:BOOL=TRUE")
endif()
ExternalProject_Add(libssh2
    DEPENDS zlib
	DEPENDS openssl
	URL https://github.com/libssh2/libssh2/archive/refs/tags/libssh2-1.10.0.tar.gz
	URL_HASH SHA256=31469ccfc71a5247c926e3f0938e122cbb7a7a4a1bdf1cf2d3121f78b558d261
	CMAKE_ARGS
		${default_cmake_args}
		${default_libssh2_args}
)

#[[
Build libgit2 with the above dependencies, or explicit defined builtins.
]]
ExternalProject_Add(libgit2
    DEPENDS zlib
    DEPENDS openssl
	DEPENDS libssh2
	URL https://github.com/libgit2/libgit2/archive/109b4c887ffb63962c7017a66fc4a1f48becb48e.tar.gz
	URL_HASH SHA256=bc4ef7d6628d2248995bbd86ad77eb96376d683e7121779c7abde480928ae21a
	CMAKE_ARGS
        ${default_cmake_args}
        -DBUILD_CLAR:BOOL:BOOL=OFF
		-DTHREADSAFE:BOOL=ON
		-DUSE_BUNDLED_ZLIB:BOOL=OFF
        -DUSE_HTTP_PARSER:STRING=builtin
        -DREGEX_BACKEND:STRING=builtin
		-DUSE_HTTPS:STRING=OpenSSL
		#[[ -DUSE_HTTPS:STRING=mbedTLS ]]
)
