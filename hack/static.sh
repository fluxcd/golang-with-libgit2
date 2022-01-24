#!/usr/bin/env bash

set -euxo pipefail

LIBGIT2_URL="${LIBGIT2_URL:-https://github.com/libgit2/libgit2/archive/refs/tags/v1.3.0.tar.gz}"
OPENSSL_URL="${OPENSSL_URL:-https://github.com/openssl/openssl/archive/refs/tags/openssl-3.0.1.tar.gz}"
LIBSSH2_URL="${LIBSSH2_URL:-https://github.com/libssh2/libssh2/archive/refs/tags/libssh2-1.10.0.tar.gz}"

# May be worth considering other forks/implementations that either
# provide better performance (i.e. intel/cloudflare) or that are better maintained.
LIBZ_URL="${LIBZ_URL:-https://github.com/madler/zlib/archive/refs/tags/v1.2.11.tar.gz}"

BUILD_ROOT_DIR="/build"
SRC_DIR="${BUILD_ROOT_DIR}/src"

function download_source(){
    mkdir -p "$2"

    curl --max-time 120 -o "$2/source.tar.gz" -LO "$1"
    tar -C "$2" --strip 1 -xzvf "$2/source.tar.gz"
    rm "$2/source.tar.gz"
}

function build_libz(){
    download_source "${LIBZ_URL}" "${SRC_DIR}/libz"    
    pushd "${SRC_DIR}/libz"

    ./configure --static \
        --archs="-arch $(xx-info march)" \
        --prefix="/usr/local/$(xx-info triple)"

    make install

    popd
}

function build_openssl(){
    download_source "${OPENSSL_URL}" "${SRC_DIR}/openssl"    
    pushd "${SRC_DIR}/openssl"

    target_name="$(xx-info march)"
    if [ "${target_name}" = "armv7l" ]; then
        # openssl does not have a specific armv7l
        # using generic32 instead.
        target_name=generic32
    fi

    ./Configure "linux-${target_name}" threads no-shared zlib -fPIC -DOPENSSL_PIC \
        --prefix="/usr/local/$(xx-info triple)" \
        --with-zlib-include="/usr/local/$(xx-info triple)/include" \
        --with-zlib-lib="/usr/local/$(xx-info triple)/lib" \
        --openssldir=/etc/ssl

    make
    make install_sw

    popd    
}

function build_libssh2(){
    download_source "${LIBSSH2_URL}" "${SRC_DIR}/libssh2"
    
    pushd "${SRC_DIR}/libssh2"

    mkdir -p build
    pushd build

    cmake "$(xx-clang --print-cmake-defines)" \
        -DCMAKE_C_COMPILER="/usr/bin/xx-clang" \
        -DCMAKE_INSTALL_PREFIX="/usr/local/$(xx-info triple)" \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_C_FLAGS=-fPIC \
        -DCRYPTO_BACKEND=OpenSSL \
        -DENABLE_ZLIB_COMPRESSION=ON \
        -DCMAKE_BUILD_TYPE="RelWithDebInfo" \
        ..
        
    cmake --build . --target install

    popd
    popd
}

function build_libgit2(){
    download_source "${LIBGIT2_URL}" "${SRC_DIR}/libgit2"
    
    pushd "${SRC_DIR}/libgit2"
    
    mkdir -p build

    pushd build

    cmake "$(xx-clang --print-cmake-defines)" \
        -DCMAKE_C_COMPILER="/usr/bin/xx-clang" \
        -DCMAKE_INSTALL_PREFIX="/usr/local/$(xx-info triple)" \
        -DTHREADSAFE:BOOL=ON \
        -DBUILD_CLAR:BOOL:BOOL=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON \
        -DCMAKE_C_FLAGS=-fPIC \
        -DUSE_SSH:BOOL=ON \
        -DHAVE_LIBSSH2_MEMORY_CREDENTIALS:BOOL=ON \
        -DDEPRECATE_HARD:BOOL=ON \
        -DUSE_BUNDLED_ZLIB:BOOL=ON \
        -DUSE_HTTPS:STRING=OpenSSL \
        -DREGEX_BACKEND:STRING=builtin \
        -DCMAKE_INCLUDE_PATH="/usr/local/$(xx-info triple)/include" \
        -DCMAKE_LIBRARY_PATH="/usr/local/$(xx-info triple)/lib" \
        -DCMAKE_BUILD_TYPE="RelWithDebInfo" \
        .. 
    
    cmake --build . --target install

    popd
    popd
}

"$@"
