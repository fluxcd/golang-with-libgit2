# golang-with-libgit2

This repository contains a `Dockerfile` with the statically built libgit2 and its dependency chain.

The `hack` directory contains two main files: `Makefile` and `static.sh`.
Both of which can be used to build the [libgit2][] dependency chain for **AMD64, ARM64 and ARMv7** binaries 
of Go projects that depend on [git2go][]. 

The `Makefile` is useful for development environments and will leverage OS specific packages to build `libgit2`.
The `static.sh` will build all `libgit2` dependencies from source using `musl` toolchain. This enables for a full
static binary with the freedom of configuring each of the dependencies in chain.

Alternatively, the statically built libraries can be pulling from the produced images for Linux or from the github release artifacts for MacOS.

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

This image is an attempt to solve (most of) these issues, by providing the configuration to compile `libgit2` ourselves,
linking it with the required dependencies at specific versions and with specific configuration, and linker options,
while testing these against the git2go code before releasing the image.

### List of known issues

- [ ] [`libssh2-1` in `bullseye` depends on `libgcrypt20`][libssh2-1-misconfiguration] which uses a slimmed down ASN.1
      parser, and does therefore has limited support for PKCS*, including the most universal PKCS#8.
- [ ] `libgit2-1.1` depends on `libmdtls12` which [does not provide support for ED25519 (yet)][mbedtls-ed25519].
- [ ] In some observations, a mix of mbedTLS and OpenSSL linking seemed to happen, making it harder to determine what
      C-dependency  was the cause of a malfunction.
- [ ] There is [no support for ECDSA* and ED25519 hostkey types before `libgit2` `1.2.0`][libgit2-5750]
- [ ] The `1.2` release of `libgit2` in combination with `git2go/v32` does not seem to work properly:
  - [ ] [libgit2/git2go#834](https://github.com/libgit2/git2go/issues/834)
  - [ ] [libgit2/git2go#836](https://github.com/libgit2/git2go/issues/836)
  - [ ] [libgit2/git2go#837](https://github.com/libgit2/git2go/issues/837)


> **NOTE:** The issues above do not affect libgit2 built with `static.sh` as all its
dependencies have been configured to be optimal for its use, as the first supported version of libgit2 is `1.3.0`.


## Usage

The [Dockerfile.test](./Dockerfile.test) file provides a working example on how to statically build a golang application that has a dependency on libgit2 and git2go.

The example will statically build all dependencies based on the versions specified on `static.sh`.
Then statically build the golang application and deploy it into an image based off `gcr.io/distroless/static`.

## Contributing

### Updating the `libgit2` version

Change the default value of `LIBGIT2_VERSION` in `hack/Makefile`. If applicable, change the `GIT2GO_TAG` in the
`Makefile` in the repository root as well to test against another version of [git2go][].

### Updating the test Go version

In the `Dockerfile.test`, update the default value of the `GO_VERSION` to the new target version.

### Updating the test base image variant

In the `Dockerfile.test`, update the `BASE_VARIANT` to the new target base variant. Then, ensure all build stages making use
of (or depending on) the base `${BASE_VARIANT}`, use it in their `AS` stage defined for the new variant.

For example:

```Dockerfile
ARG BASE_VARIANT=awesome-os
...

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-${BASE_VARIANT} as go-awesome-os
...

FROM go-${BASE_VARIANT} AS build-dependencies-awesome-os
```

### Releasing a new image

For the `main` branch, images are pushed automatically to a tag matching the branch name, and a tag in the format of
`sha-<Git sha>`. In addition, images are created for new tags, with as preferred format: `libgit2-<libgit2 SemVer>`.

For example, `libgit2-1.1.1` for an image with **libgit2 1.1.1** included.

In case changes happen to the `Dockerfile` while the `libgit2` version does not change, sequential tags should
be suffixed with `-<seq num in range>`. For example, `libgit2-1.1.1-2` for the **third** container image
with the same version.

### Debugging cross-compilation

Below are a few tips on how to overcome cross-compilation issues:

1) Ensure all qemu emulators are installed:
```sh
docker run -it --rm --privileged tonistiigi/binfmt --install all
```

2) Check that the generated libraries are aligned with the target architecture:

Leveraging `readelf` from `binutils` (i.e. `apk add binutils`), check the target machine
architecture:

```sh
$ readelf -h /usr/local/aarch64-alpine-linux-musl/lib/libcrypto.a | grep Machine |sort -u
  Machine:                           AArch64
$ readelf -h /usr/local/aarch64-alpine-linux-musl/lib/libgit2.a | grep Machine | sort -u
  Machine:                           AArch64
$ readelf -h /usr/local/aarch64-alpine-linux-musl/lib/libssh2.a | grep Machine | sort -u
  Machine:                           AArch64
$ readelf -h /usr/local/aarch64-alpine-linux-musl/lib/libssl.a | grep Machine | sort -u
  Machine:                           AArch64
$ readelf -h /usr/local/aarch64-alpine-linux-musl/lib/libz.a | grep Machine | sort -u
  Machine:                           AArch64
```


[xx]: https://github.com/tonistiigi/xx
[Go container image]: https://hub.docker.com/_/golang
[libgit2]: https://github.com/libgit2/libgit2
[git2go]: https://github.com/libgit2/git2go
[Flux project]: https://github.com/fluxcd
[libgit2-debian-tracker]: https://tracker.debian.org/pkg/libgit2
[libssh2-1-misconfiguration]: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=668271
[mbedtls-ed25519]: https://github.com/ARMmbed/mbedtls/issues/2452
[libgit2-5750]: https://github.com/libgit2/libgit2/pull/5750

## To verify artefacts

Download the following files from the releases section:
1. checksum.txt
2. checksum.txt.pem
3. checksum.txt.sig
4. The compressed library files

You can verify that the `checksum.txt` wasn't tampered with using `cosign` and the downloaded certificate and signature.

```
cosign verify-blob --cert checksums.txt.pem --signature checksums.txt.sig checksums.txt
```

Verify the hashes of the other files using `checksum.txt`:

```
sha256sum --ignore-missing -c checksums.txt
```