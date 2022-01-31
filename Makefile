IMG ?= ghcr.io/fluxcd/golang-with-libgit2
TAG ?= latest

PLATFORMS ?= linux/amd64,linux/arm/v7,linux/arm64
BUILD_ARGS ?=

REPOSITORY_ROOT := $(shell git rev-parse --show-toplevel)
TARGET_DIR ?= $(REPOSITORY_ROOT)/build/libgit2
BUILD_ROOT_DIR ?= $(REPOSITORY_ROOT)/build/libgit2-src

LIBGIT2_PATH := $(TARGET_DIR)
LIBGIT2_LIB_PATH := $(LIBGIT2_PATH)/lib
LIBGIT2_LIB64_PATH := $(LIBGIT2_PATH)/lib64
LIBGIT2 := $(LIBGIT2_LIB_PATH)/libgit2.a
MUSL-CC =

export CGO_ENABLED=1
export LIBRARY_PATH=$(LIBGIT2_LIB_PATH):$(LIBGIT2_LIB64_PATH)
export PKG_CONFIG_PATH=$(LIBGIT2_LIB_PATH)/pkgconfig:$(LIBGIT2_LIB64_PATH)/pkgconfig
export CGO_CFLAGS=-I$(LIBGIT2_PATH)/include


ifeq ($(shell uname -s),Linux)
	export CGO_LDFLAGS=$(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) pkg-config --libs --static --cflags libssh2 openssl libgit2) -static
else
	export CGO_LDFLAGS=$(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) pkg-config --libs --static --cflags libssh2 openssl libgit2) -Wl,--unresolved-symbols=ignore-in-object-files -Wl,-allow-shlib-undefined -static
endif

ifeq ($(shell uname -s),Linux)
	MUSL-PREFIX=$(REPOSITORY_ROOT)/build/musl/$(shell uname -m)-linux-musl-native/bin/$(shell uname -m)-linux-musl
	MUSL-CC=$(MUSL-PREFIX)-gcc
	export CC=$(MUSL-PREFIX)-gcc
	export CXX=$(MUSL-PREFIX)-g++
	export AR=$(MUSL-PREFIX)-ar
endif

GO_STATIC_FLAGS=-tags 'netgo,osusergo,static_build'


.PHONY: build
build:
	docker buildx build \
		--platform=$(PLATFORMS) \
		--tag $(IMG):$(TAG) \
		--file Dockerfile \
		$(BUILD_ARGS) .

.PHONY: test
test:
	docker buildx build \
		--platform=$(PLATFORMS) \
		--tag $(IMG):$(TAG)-test \
		--build-arg LIBGIT2_IMG=$(IMG) \
		--build-arg LIBGIT2_TAG=$(TAG) \
		--file Dockerfile.test \
		$(BUILD_ARGS) .

.PHONY: builder
builder:
# create local builder
	docker buildx create --name local-builder \
		--platform $(PLATFORMS) \
		--driver-opt network=host \
		--driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=1073741274 \
		--driver-opt env.BUILDKIT_STEP_LOG_MAX_SPEED=5000000000000 \
		--buildkitd-flags '--allow-insecure-entitlement security.insecure' \
		--use
# install qemu emulators
	docker run -it --rm --privileged tonistiigi/binfmt --install all


$(LIBGIT2): $(MUSL-CC)
ifeq ($(shell uname -s),Darwin)
	TARGET_DIR=$(TARGET_DIR) BUILD_ROOT_DIR=$(BUILD_ROOT_DIR) \
		./hack/static.sh all
else
	IMG_TAG=$(IMG):$(TAG) ./hack/extract-libraries.sh
endif

$(MUSL-CC):
ifneq ($(shell uname -s),Darwin)
	./hack/download-musl.sh
endif


# dev-test is a smoke test for development environment
# consuming the libraries generated by this project.
dev-test: $(LIBGIT2)
	cd tests/smoketest; go vet $(GO_STATIC_FLAGS) ./...
	cd tests/smoketest; go run $(GO_STATIC_FLAGS) main.go
