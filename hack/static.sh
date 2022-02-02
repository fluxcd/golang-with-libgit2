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

C_COMPILER="${CC:-/usr/bin/gcc}"
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

    # if target architecture is the same as current, no cross compiling is required
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

    export OPENSSL_ROOT_DIR="${TARGET_DIR}"
    export OPENSSL_LIBRARIES="${TARGET_DIR}/lib"

    target_arch=""
    if [ "${TARGET_ARCH}" = "armv7l" ]; then
        # openssl does not have a specific armv7l
        # using generic32 instead.
        target_arch="linux-generic32"
    elif [ "${TARGET_ARCH}" = "arm64" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
        target_arch="linux-aarch64"  
    elif [ "${TARGET_ARCH}" = "x86_64" ]; then
        target_arch="linux-x86_64"
    else
        echo "Architecture currently not supported: ${TARGET_ARCH}"
        exit 1
    fi

    ./Configure "${target_arch}" threads no-shared zlib -fPIC -DOPENSSL_PIC \
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

    OPENSSL_LIBRARIES="${TARGET_DIR}/lib"
    if [ "${TARGET_ARCH}" = "x86_64" ]; then
        OPENSSL_LIBRARIES="${TARGET_DIR}/lib64"
    fi


    cmake "${CMAKE_PARAMS}" \
        -DCMAKE_C_COMPILER="${C_COMPILER}" \
        -DCMAKE_INSTALL_PREFIX="${TARGET_DIR}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DLINT=OFF \
        -DCMAKE_C_FLAGS=-fPIC \
        -DCRYPTO_BACKEND=OpenSSL \
        -DENABLE_ZLIB_COMPRESSION=ON \
        -DCMAKE_BUILD_TYPE="RelWithDebInfo" \
        -DOPENSSL_CRYPTO_LIBRARY="${OPENSSL_LIBRARIES}/libcrypto.a" \
        -DOPENSSL_SSL_LIBRARY="${OPENSSL_LIBRARIES}/libssl.a" \
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

    SSL_LIBRARY="${TARGET_DIR}/lib/libssl.a"
    CRYPTO_LIBRARY="${TARGET_DIR}/lib/libcrypto.a"
    if [ "${TARGET_ARCH}" = "x86_64" ]; then
        SSL_LIBRARY="${TARGET_DIR}/lib64/libssl.a"
        CRYPTO_LIBRARY="${TARGET_DIR}/lib64/libcrypto.a"
    fi

    cmake "${CMAKE_PARAMS}" \
        -DCMAKE_C_COMPILER="${C_COMPILER}" \
        -DCMAKE_INSTALL_PREFIX="${TARGET_DIR}" \
        -DTHREADSAFE:BOOL=ON \
        -DBUILD_CLAR:BOOL=OFF \
        -DBUILD_TESTS:BOOL=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON \
        -DCMAKE_C_FLAGS=-fPIC \
        -DUSE_SSH:BOOL=ON \
        -DHAVE_LIBSSH2_MEMORY_CREDENTIALS:BOOL=ON \
        -DDEPRECATE_HARD:BOOL=ON \
        -DUSE_BUNDLED_ZLIB:BOOL=ON \
        -DUSE_HTTPS:STRING=OpenSSL \
        -DREGEX_BACKEND:STRING=builtin \
        -DOPENSSL_SSL_LIBRARY="${SSL_LIBRARY}" \
        -DOPENSSL_CRYPTO_LIBRARY="${CRYPTO_LIBRARY}" \
        -DZLIB_LIBRARY="${TARGET_DIR}/lib/libz.a" \
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
