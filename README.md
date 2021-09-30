# golang-with-libgit2

This repository contains a `Dockerfile` which makes use of [`tonistiigi/xx`][xx] to produce a [Go container image][]
with a dynamic set of [libgit2][] dependencies. The image can be used to build **AMD64, ARM64 and ARMv7** binaries of Go
projects that depend on [git2go][].

### :warning: **Public usage discouraged**

The set of dependencies was handpicked for the Flux project, based on the issue list documented below. While this setup
may work for you(r project) as well, this may change at any moment in time, and depending on this image for non-Flux
projects is because of this discouraged. Forks are welcome! :-)

## Rationale

The [Flux project][] uses `libgit2` and/or `git2go` in several places to perform clone and push operations on remote
Git repositories. OS package releases (including but not limited to Debian) [are slow][libgit2-debian-tracker],
even if [acknowledged to include a wrong set of dependencies][libssh2-1-misconfiguration].

In addition, user feedback on the Flux project, and a history of build complexity and random failures, has made it clear
that producing a set of dependencies that work for all end-users using OS packages can be difficult:

- [fluxcd/image-automation-controller#210](https://github.com/fluxcd/image-automation-controller/issues/210)
- [fluxcd/source-controller#433](https://github.com/fluxcd/source-controller/issues/433)
- [fluxcd/image-automation-controller#207](https://github.com/fluxcd/image-automation-controller/issues/207)
- [fluxcd/source-controller#399](https://github.com/fluxcd/source-controller/issues/399)
- [fluxcd/image-automation-controller#186](https://github.com/fluxcd/image-automation-controller/issues/186)
- [fluxcd/source-controller#439](https://github.com/fluxcd/source-controller/issues/439)

This image is an attempt to solve (most of) these issues, by compiling `libgit2` ourselves, linking it with
the required dependencies at specific versions and with specific configuration, and linker options,
while testing these against the git2go code before releasing the image.

### List of known issues

- [ ] [`libssh2-1` in `bullseye` depends on `libgcrypt20`][libssh2-1-misconfiguration] which uses a slimmed down ASN.1
      parser, and does therefore has limited support for PKCS*, including the most universal PKCS#8.
- [ ] `libgit2-1.1` depends on `libmdtls12` which [does not provide support for ED25519 (yet)][mbedtls-ed25519].
- [ ] In some observations, a mix of mbedTLS and OpenSSL linking seemed to happen, making it harder to determine what
      C-dependency  was the cause of a malfunction.
- [ ] The `1.2` release of `libgit2` in combination with `git2go/v32` does not seem to work properly:
  - [ ] [libgit2/git2go#834](https://github.com/libgit2/git2go/issues/834)
  - [ ] [libgit2/git2go#836](https://github.com/libgit2/git2go/issues/836)
  - [ ] [libgit2/git2go#837](https://github.com/libgit2/git2go/issues/837)

## Usage

To make use of the image published by the `Dockerfile`, use it as a base image for your Go build. In your application
container, ensure the [runtime dependencies](#Runtime-dependencies) are present, and copy over the `libgit2` shared
libraries from `$LIBGIT2_PATH/lib/*` (default `/libgit2/lib`).

### libgit2

The `libgit2` library is installed to the expected path for the `$TARGETPLATFORM`, and building a dynamically linked Go
binary should be possible by just running `xx-go build`. For the application image, a copy of the `.so*` files are
available in `$LIBGIT2_PATH/lib`.

In cases where you need to determine the architecture based library installation path without making use of `xx[-info]`,
the destination path is written to `$LIBGIT2_PATH/INSTALL_LIBDIR`.

### Runtime dependencies

The following dependencies should be present in the image running the application:

- `libc6`
- `ca-certificates`
- `zlib1g/sid`
- `libssl1.1/sid`
- `libssh2-1/sid`

**Note:** at present, all dependencies suffixed with `sid` should be installed from Debian's `sid` (unstable) release,
[due to a misconfiguration in `libssh2-1` for earlier versions][libssh2-1-misconfiguration].

### `Dockerfile` example

```Dockerfile
FROM hiddeco/golang-with-libgit2 AS build

# Configure workspace
WORKDIR /workspace

# Copy modules manifests
COPY go.mod go.mod
COPY go.sum go.sum

# Cache modules
RUN go mod download

# Copy source code
COPY main.go main.go

# Build the binary
ENV CGO_ENABLED=1
ARG TARGETPLATFORM
RUN xx-go build -o app \
    main.go

FROM debian:buster-slim as controller

# Install runtime dependencies
RUN echo "deb http://deb.debian.org/debian sid main" >> /etc/apt/sources.list \
    && echo "deb-src http://deb.debian.org/debian sid main" >> /etc/apt/sources.list \
    && apt update \
    && apt install --no-install-recommends -y zlib1g/sid libssl1.1/sid libssh2-1/sid \
    && apt install --no-install-recommends -y ca-certificates \
    && apt clean \
    && apt autoremove --purge -y \
    && rm -rf /var/lib/apt/lists/*

# Copy libgit2.so*
COPY --from=build /libgit2/lib/ /usr/local/lib/
RUN ldconfig

# Copy over binary from build
COPY --from=build /workspace/app /usr/local/bin/

ENTRYPOINT [ "app" ]
```

[xx]: https://github.com/tonistiigi/xx
[Go container image]: https://hub.docker.com/_/golang
[libgit2]: https://github.com/libgit2/libgit2
[git2go]: https://github.com/libgit2/git2go
[Flux project]: https://github.com/fluxcd
[libgit2-debian-tracker]: https://tracker.debian.org/pkg/libgit2
[libssh2-1-misconfiguration]: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=668271
[mbedtls-ed25519]: https://github.com/ARMmbed/mbedtls/issues/2452
