FROM golang:1.16.8-bullseye as base

# Install depedencies required to build
RUN set -eux; \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        cmake \
        python3 \
    && apt-get clean \
    && apt-get autoremove --purge -y \
    && rm -rf /var/lib/apt/lists/*

# Copy libgit2 build directives and instructions into container
ARG LIBGIT2_SRC_DIR
ENV LIBGIT2_SRC_DIR=${LIBGIT2_SRC_DIR:-/libgit2}
COPY CMakeLists.txt ${LIBGIT2_SRC_DIR}/CMakeLists.txt

# Set right before build time to not invalidate previous cache layers.
ARG LIBGIT2_DYNAMIC_ROOT_DIR
ENV LIBGIT2_DYNAMIC_ROOT_DIR=${LIBGIT2_DYNAMIC_ROOT_DIR:-${LIBGIT2_SRC_DIR}/dynamic}
ARG LIBGIT2_STATIC_ROOT_DIR
ENV LIBGIT2_STATIC_ROOT_DIR=${LIBGIT2_STATIC_ROOT_DIR:-${LIBGIT2_SRC_DIR}/static}

# Set default to single process
ARG NPROC=1

# Run the libgit2 and dependencies build.
# Produce two sets (dynamic and static) of pre-compiled libraries in /libgit2/,
# and remove the build directory itself to minimize image size.
#
# Note: you can still reproduce the build by making use of /libgit2/CMakeLists.txt.
RUN set -eux; \
    build_dir=$(mktemp -d) \
    && echo "=> Dynamic build" \
    && cmake -S $LIBGIT2_SRC_DIR -B $build_dir \
      -DBUILD_SHARED_LIBS:BOOL=ON \
      -DUSE_EXTERNAL_INSTALL:BOOL=ON \
      -DCMAKE_INSTALL_PREFIX:PATH=$LIBGIT2_DYNAMIC_ROOT_DIR \
    && cmake --build $build_dir -j $NPROC \
    && echo "=> Static build" \
    && cmake -S $LIBGIT2_SRC_DIR -B $build_dir \
      -DBUILD_SHARED_LIBS:BOOL=OFF \
      -DUSE_EXTERNAL_INSTALL:BOOL=ON \
      -DCMAKE_INSTALL_PREFIX:PATH=$LIBGIT2_STATIC_ROOT_DIR  \
    && cmake --build $build_dir -j $NPROC \
    && rm -rf $build_dir
