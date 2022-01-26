#!/usr/bin/env bash

set -euxo pipefail

LIBGIT2_URL="${LIBGIT2_URL:-https://github.com/libgit2/libgit2/archive/refs/tags/v1.1.1.tar.gz}"
OPENSSL_URL="${OPENSSL_URL:-https://github.com/openssl/openssl/archive/refs/tags/openssl-3.0.1.tar.gz}"
LIBSSH2_URL="${LIBSSH2_URL:-https://github.com/libssh2/libssh2/archive/refs/tags/libssh2-1.10.0.tar.gz}"

# May be worth considering other forks/implementations that either
# provide better performance (i.e. intel/cloudflare) or that are better maintained.
LIBZ_URL="${LIBZ_URL:-https://github.com/madler/zlib/archive/refs/tags/v1.2.11.tar.gz}"

TARGET_DIR="${TARGET_DIR:-/usr/local/$(xx-info triple)}"
BUILD_ROOT_DIR="${BUILD_ROOT_DIR:-/build}"
SRC_DIR="${BUILD_ROOT_DIR}/src"


TARGET_ARCH="$(uname -m)"
if command -v xx-info; then 
    TARGET_ARCH="$(xx-info march)"
fi

C_COMPILER="/usr/bin/gcc"
CMAKE_PARAMS=""
if command -v xx-clang; then 
    C_COMPILER="/usr/bin/xx-clang"
    CMAKE_PARAMS="$(xx-clang --print-cmake-defines)"
fi


function download_source(){
    mkdir -p "$2"

    curl --max-time 120 -o "$2/source.tar.gz" -LO "$1"
    tar -C "$2" --strip 1 -xzvf "$2/source.tar.gz"
    rm "$2/source.tar.gz"
}

function build_libz(){
    download_source "${LIBZ_URL}" "${SRC_DIR}/libz"    
    pushd "${SRC_DIR}/libz"

    if [ "${TARGET_ARCH}" = "$(uname -m)" ]; then
        ./configure --static --prefix="${TARGET_DIR}"
    else
        ./configure --static --prefix="${TARGET_DIR}" \
            --archs="-arch ${TARGET_ARCH}"            
    fi

    make install

    popd
}

function build_openssl(){
    download_source "${OPENSSL_URL}" "${SRC_DIR}/openssl"    
    pushd "${SRC_DIR}/openssl"

    target_name="${TARGET_ARCH}"
    if [ "${target_name}" = "armv7l" ]; then
        # openssl does not have a specific armv7l
        # using generic32 instead.
        target_name=generic32
    fi

    ./Configure "linux-${target_name}" threads no-shared zlib -fPIC -DOPENSSL_PIC \
        --prefix="${TARGET_DIR}" \
        --with-zlib-include="${TARGET_DIR}/include" \
        --with-zlib-lib="${TARGET_DIR}/lib" \
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

    cmake "${CMAKE_PARAMS}" \
        -DCMAKE_C_COMPILER="${C_COMPILER}" \
        -DCMAKE_INSTALL_PREFIX="${TARGET_DIR}" \
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

    cmake "${CMAKE_PARAMS}" \
        -DCMAKE_C_COMPILER="${C_COMPILER}" \
        -DCMAKE_INSTALL_PREFIX="${TARGET_DIR}" \
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
        -DCMAKE_INCLUDE_PATH="${TARGET_DIR}/include" \
        -DCMAKE_LIBRARY_PATH="${TARGET_DIR}/lib" \
        -DCMAKE_BUILD_TYPE="RelWithDebInfo" \
        .. 
    
    cmake --build . --target install

    popd
    popd
}

function all(){
    build_libz
    build_openssl
    build_libssh2
    build_libgit2
}

"$@"
