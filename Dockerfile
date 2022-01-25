# This Dockerfile tests the hack/Makefile output against git2go.
ARG BASE_VARIANT=alpine
ARG GO_VERSION=1.17.6
ARG XX_VERSION=1.1.0

FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx

FROM golang:${GO_VERSION}-${BASE_VARIANT} as gostable

FROM gostable AS go-linux

FROM --platform=$BUILDPLATFORM ${BASE_VARIANT} AS build-deps

RUN apk add --no-cache \
        bash \
        curl \
        build-base \
        linux-headers \
        perl \
        cmake \
        pkgconfig \
        gcc \
        musl-dev \
        clang \
        lld

COPY --from=xx / /

ARG TARGETPLATFORM

RUN xx-apk add --no-cache \
        xx-c-essentials 

RUN xx-apk add --no-cache \
        xx-cxx-essentials 

ARG TARGETPLATFORM
RUN xx-apk add --no-cache \
        build-base \
        pkgconfig \
        gcc \
        musl-dev \
        clang \
        lld \
        llvm \
        linux-headers

WORKDIR /build
COPY hack/static.sh .

ARG TARGETPLATFORM
ENV CC=xx-clang
ENV CXX=xx-clang++

RUN CHOST=$(xx-clang --print-target-triple) \
    ./static.sh build_libz

RUN CHOST=$(xx-clang --print-target-triple) \
    ./static.sh build_openssl

RUN export LIBRARY_PATH="/usr/local/$(xx-info triple)/lib:/usr/local/$(xx-info triple)/lib64:${LIBRARY_PATH}" && \
    export PKG_CONFIG_PATH="/usr/local/$(xx-info triple)/lib/pkgconfig:/usr/local/$(xx-info triple)/lib64/pkgconfig" && \
    export OPENSSL_ROOT_DIR="/usr/local/$(xx-info triple)" && \
    export OPENSSL_CRYPTO_LIBRARY="/usr/local/$(xx-info triple)/lib64" && \
    export OPENSSL_INCLUDE_DIR="/usr/local/$(xx-info triple)/include/openssl"

RUN ./static.sh build_libssh2
RUN ./static.sh build_libgit2


FROM go-${TARGETOS} AS build

# Copy cross-compilation tools
COPY --from=xx / /
# Copy compiled libraries
COPY --from=build-deps /usr/local/ /usr/local/

COPY ./hack/Makefile /Makefile
COPY ./hack/static.sh /static.sh
