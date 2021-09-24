ARG BASE_VARIANT=bullseye
ARG GO_VERSION=1.16.8
ARG XX_VERSION=1.0.0-rc.2

FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-${BASE_VARIANT} as gostable
FROM --platform=$BUILDPLATFORM golang:1.17rc1-${BASE_VARIANT} AS golatest

FROM gostable AS go-linux

FROM go-${TARGETOS} AS build-base-bullseye

COPY --from=xx / /

RUN apt-get update && apt-get install --no-install-recommends -y clang
ARG CMAKE_VERSION=3.21.3
RUN curl -sL -o cmake-linux.sh "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-$(xx-info march).sh" \
    && sh cmake-linux.sh -- --skip-license --prefix=/usr \
    && rm cmake-linux.sh

FROM build-base-bullseye AS build-bullseye
ARG TARGETPLATFORM
RUN xx-apt install --no-install-recommends -y binutils gcc libc6-dev dpkg-dev

FROM build-${BASE_VARIANT} AS build-dependencies-bullseye

# Install libssh2 for $TARGETPLATFORM from "sid", as the version in "bullseye"
# has been linked against gcrypt, which causes issues with PKCS* formats.
# We pull (sub)dependencies from there as well, to ensure all versions are aligned,
# and not accidentially linked to e.g. mbedTLS (which has limited support for
# certain key formats).
# Ref: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=668271
# Ref: https://github.com/ARMmbed/mbedtls/issues/2452#issuecomment-802683144
ARG TARGETPLATFORM
RUN echo "deb http://deb.debian.org/debian sid main" >> /etc/apt/sources.list \
    && echo "deb-src http://deb.debian.org/debian sid main" >> /etc/apt/sources.list
RUN xx-apt update \
    && xx-apt -t sid install --no-install-recommends -y zlib1g-dev libssl-dev libssh2-1-dev

FROM build-dependencies-${BASE_VARIANT} as build-libgit2-bullseye

# Compile libgit2 as a dynamic build
# We compile it ourselves to ensure they are properly linked with the above packages,
# and to allow room for customizations (or more rapid updates than the OS).
ARG LIBGIT2_PATH=/libgit2
ENV LIBGIT2_PATH=${LIBGIT2_PATH}
COPY hack/Makefile ${LIBGIT2_PATH}/Makefile
RUN set -e; \
    echo "/usr/lib/$(xx-info triple)" > ${LIBGIT2_PATH}/INSTALL_LIBDIR \
    && INSTALL_LIBDIR=$(cat ${LIBGIT2_PATH}/INSTALL_LIBDIR) \
    FLAGS=$(xx-clang --print-cmake-defines) \
    make -C ${LIBGIT2_PATH} \
    && xx-verify $(cat ${LIBGIT2_PATH}/INSTALL_LIBDIR)/libgit2.so \
    && mkdir -p ${LIBGIT2_PATH}/lib/ \
    && cp -d $(cat ${LIBGIT2_PATH}/INSTALL_LIBDIR)/libgit2.so* ${LIBGIT2_PATH}/lib/
