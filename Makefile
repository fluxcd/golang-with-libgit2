IMG ?= hiddeco/golang-with-libgit2
TAG ?= latest
STATIC_TEST_TAG := test

PLATFORMS ?= linux/amd64,linux/arm/v7,linux/arm64
BUILD_ARGS ?=

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
		--tag $(IMG):$(TAG) \
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
