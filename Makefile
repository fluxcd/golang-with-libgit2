IMG ?= hiddeco/golang-with-libgit2
TAG ?= latest
ARCHS ?= linux/amd64,linux/arm/v7,linux/arm64
GIT2GO_TAG ?= v32.0.4
STATIC_TEST_TAG := test

.PHONY: build
build:
	docker build -t $(IMG):$(TAG) -f Dockerfile  --build-arg NPROC=$(shell nproc) .

.PHONY: build-multi-arch
build-multi-arch:
	docker buildx build \
		--platform=$(ARCHS) \
		--tag $(IMG):$(TAG) \
		--file Dockerfile \
		--build-arg NPROC=$(shell nproc) .

.PHONY: test
test: test-dynamic test-static

.PHONY: test-dynamic
test-dynamic: Dockerfile.test
	docker run --rm $(IMG):$(STATIC_TEST_TAG) sh -c 'PKG_CONFIG_PATH=$$LIBGIT2_DYNAMIC_ROOT_DIR/lib/pkgconfig \
		LD_LIBRARY_PATH=$$LIBGIT2_DYNAMIC_ROOT_DIR/lib/ \
		go test --count=1 ./...'

.PHONY: test-static
test-static: Dockerfile.test
	docker run --rm $(IMG):$(STATIC_TEST_TAG) sh -c 'PKG_CONFIG_PATH=$$LIBGIT2_STATIC_ROOT_DIR/lib/pkgconfig \
		LD_LIBRARY_PATH=$$LIBGIT2_STATIC_ROOT_DIR/lib/ \
		go test -tags "static,system_libgit2" --count=1 ./...'

.PHONY: Dockerfile.test
Dockerfile.test:
	docker build -t $(IMG):$(STATIC_TEST_TAG) \
		-f Dockerfile.test \
		--build-arg IMG=$(IMG) --build-arg TAG=$(TAG) --build-arg GIT2GO_TAG=$(GIT2GO_TAG) .
