IMG ?= hiddeco/golang-with-libgit2
TAG ?= latest
STATIC_TEST_TAG := test

PLATFORMS ?= linux/amd64,linux/arm/v7,linux/arm64
BUILD_ARGS ?=

GIT2GO_TAG ?= v33.0.1

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
		--build-arg IMG=$(IMG) \
		--build-arg TAG=$(TAG) \
		--build-arg GIT2GO_TAG=$(GIT2GO_TAG) \
		--build-arg CACHE_BUST="$(shell date --rfc-3339=ns --utc)" \
		--file Dockerfile.test .

.PHONY: builder
builder:
	docker buildx create --name local-builder \
		--platform $(PLATFORMS) \
		--driver-opt network=host \
		--driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=1073741274 \
		--driver-opt env.BUILDKIT_STEP_LOG_MAX_SPEED=5000000000000 \
		--buildkitd-flags '--allow-insecure-entitlement security.insecure' \
		--use
