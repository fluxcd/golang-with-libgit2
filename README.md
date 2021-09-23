# golang-with-libgit2

This repository contains [CMake][] directives and instructions, and a `Dockerfile`; to produce a [Go container image][]
with a dynamic and static set of [libgit2][] and its dependencies. The image can be used to build binaries of Go
projects  that depend on [git2go][].

## Rationale

The [Flux project][] uses `libgit2` and/or `git2go` in several places to perform clone and push operations on remote
Git repositories. OS package releases (including but not limited to Debian) [are slow](https://tracker.debian.org/pkg/libgit2),
even if [acknowledged to include a wrong set of dependencies](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=668271).

In addition, user feedback on the Flux project, and a history of build complexity and random failures, has made it clear
that producing a set of dependencies that work for all end-users using OS packages can be difficult:

- [fluxcd/image-automation-controller#210](https://github.com/fluxcd/image-automation-controller/issues/210)
- [fluxcd/source-controller#433](https://github.com/fluxcd/source-controller/issues/433)
- [fluxcd/image-automation-controller#207](https://github.com/fluxcd/image-automation-controller/issues/207)
- [fluxcd/source-controller#399](https://github.com/fluxcd/source-controller/issues/399)
- [fluxcd/image-automation-controller#186](https://github.com/fluxcd/image-automation-controller/issues/186)
- [fluxcd/source-controller#439](https://github.com/fluxcd/source-controller/issues/439)

This image is an attempt to resolve (most of) these issues, by pre-compiling the required dependencies at pinned
versions and with specific configuration and linker options, while testing these against the git2go code before
releasing the image.

[CMake]: https://cmake.org
[Go container image]: https://hub.docker.com/_/golang
[libgit2]: https://github.com/libgit2/libgit2
[git2go]: https://github.com/libgit2/git2go
[Flux project]: https://github.com/fluxcd
