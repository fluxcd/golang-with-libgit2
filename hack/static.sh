#!/usr/bin/env bash

set -euxo pipefail

LIBGIT2_URL="${LIBGIT2_URL:-https://github.com/libgit2/libgit2/archive/refs/tags/v1.3.1.tar.gz}"
OPENSSL_URL="${OPENSSL_URL:-https://github.com/openssl/openssl/archive/refs/tags/openssl-3.0.2.tar.gz}"
LIBSSH2_URL="${LIBSSH2_URL:-https://github.com/libssh2/libssh2/archive/refs/tags/libssh2-1.10.0.tar.gz}"

# May be worth considering other forks/implementations that either
# provide better performance (i.e. intel/cloudflare) or that are better maintained.
LIBZ_URL="${LIBZ_URL:-https://github.com/madler/zlib/archive/refs/tags/v1.2.12.tar.gz}"

TARGET_DIR="${TARGET_DIR:-/usr/local/$(xx-info triple)}"
BUILD_ROOT_DIR="${BUILD_ROOT_DIR:-/build}"
SRC_DIR="${BUILD_ROOT_DIR}/src"

TARGET_ARCH="${TARGET_ARCH:-$(uname -m)}"
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

    export KERNEL_BITS=64
    target_arch=""
    if [[ ! $OSTYPE == darwin* ]]; then
        if [ "${TARGET_ARCH}" = "armv7l" ]; then
            # openssl does not have a specific armv7l
            # using generic32 instead.
            target_arch="linux-generic32"
            export KERNEL_BITS=32
        elif [ "${TARGET_ARCH}" = "arm64" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
            target_arch="linux-aarch64"
        elif [ "${TARGET_ARCH}" = "x86_64" ]; then
            target_arch="linux-x86_64"
        fi
    else
        SUFFIX=""
        if [ ! "${TARGET_ARCH}" = "$(uname -m)" ]; then
            SUFFIX="-cc"
        fi

        if [ "${TARGET_ARCH}" = "arm64" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
            target_arch="darwin64-arm64${SUFFIX}"
        elif [ "${TARGET_ARCH}" = "x86_64" ]; then
            target_arch="darwin64-x86_64${SUFFIX}"
        fi
        # if none of the above, let openssl figure it out.
    fi

    ./Configure "${target_arch}" threads no-shared no-tests zlib -fPIC -DOPENSSL_PIC \
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
    if [ "${TARGET_ARCH}" = "x86_64" ] && [[ ! $OSTYPE == darwin* ]]; then
        OPENSSL_LIBRARIES="${TARGET_DIR}/lib64"
    fi

    # Set osx arch only when cross compiling on darwin
    if [[ $OSTYPE == darwin* ]] && [ ! "${TARGET_ARCH}" = "$(uname -m)" ]; then
        CMAKE_PARAMS=-DCMAKE_OSX_ARCHITECTURES="${TARGET_ARCH}"
    fi

    # Building examples allow for validating against missing symbols at compilation time.
    cmake "${CMAKE_PARAMS}" \
        -DCMAKE_C_COMPILER="${C_COMPILER}" \
        -DCMAKE_INSTALL_PREFIX="${TARGET_DIR}" \
        -DBUILD_SHARED_LIBS:BOOL=OFF \
        -DLINT:BOOL=OFF \
        -DBUILD_EXAMPLES:BOOL=ON \
        -DBUILD_TESTING:BOOL=OFF \
        -DCMAKE_C_FLAGS=-fPIC \
        -DCRYPTO_BACKEND=OpenSSL \
        -DENABLE_ZLIB_COMPRESSION:BOOL=ON \
        -DCMAKE_BUILD_TYPE="RelWithDebInfo" \
        -DZLIB_LIBRARY="${TARGET_DIR}/lib/libz.a" \
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
    if [[ ! $OSTYPE == darwin* ]] && [ "${TARGET_ARCH}" = "x86_64" ]; then
        SSL_LIBRARY="${TARGET_DIR}/lib64/libssl.a"
        CRYPTO_LIBRARY="${TARGET_DIR}/lib64/libcrypto.a"
    fi

    # Set osx arch only when cross compiling on darwin
    if [[ $OSTYPE == darwin* ]] && [ ! "${TARGET_ARCH}" = "$(uname -m)" ]; then
        CMAKE_PARAMS=-DCMAKE_OSX_ARCHITECTURES="${TARGET_ARCH}"
    fi

    cmake "${CMAKE_PARAMS}" \
        -DCMAKE_C_COMPILER="${C_COMPILER}" \
        -DCMAKE_INSTALL_PREFIX="${TARGET_DIR}" \
        -DTHREADSAFE:BOOL=ON \
        -DBUILD_CLAR:BOOL=OFF \
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
        -DCMAKE_INCLUDE_PATH="${TARGET_DIR}/include" \
        -DCMAKE_LIBRARY_PATH="${TARGET_DIR}/lib" \
        -DCMAKE_PREFIX_PATH="${TARGET_DIR}" \
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
