# This Dockerfile tests the hack/Makefile output against git2go.
ARG BASE_VARIANT=alpine
ARG GO_VERSION=1.17
ARG XX_VERSION=1.1.0

FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx

FROM --platform=$BUILDPLATFORM ${BASE_VARIANT} AS build-base

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

FROM build-base AS build-cross

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


# trimmed removes all non necessary files (i.e. openssl binary).
FROM build-cross AS trimmed

ARG TARGETPLATFORM
RUN mkdir -p /trimmed/usr/local/$(xx-info triple)/ && \
        mkdir -p /trimmed/usr/local/$(xx-info triple)/share

RUN cp -r /usr/local/$(xx-info triple)/lib/ /trimmed/usr/local/$(xx-info triple)/ && \
        cp -r /usr/local/$(xx-info triple)/lib64/ /trimmed/usr/local/$(xx-info triple)/ | true && \
        cp -r /usr/local/$(xx-info triple)/include/ /trimmed/usr/local/$(xx-info triple)/ && \
        cp -r /usr/local/$(xx-info triple)/share/doc/ /trimmed/usr/local/$(xx-info triple)/share/

FROM scratch as libs-arm64
COPY --from=trimmed /trimmed/ /

FROM scratch as libs-amd64
COPY --from=trimmed /trimmed/ /

FROM scratch as libs-armv7
COPY --from=trimmed /trimmed/ /

FROM libs-$TARGETARCH$TARGETVARIANT as libs
