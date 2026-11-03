# base-images 🏗️

Distribution base images for [Infinito.Nexus](https://github.com/infinito-nexus/core)
and [package-manager](https://github.com/kevinveenbirkenbach/package-manager).

One image per distribution, one variant, every platform the upstream base
offers, published to GHCR:

```text
ghcr.io/kevinveenbirkenbach/base-<distro>:latest      # always the newest build
ghcr.io/kevinveenbirkenbach/base-<distro>:<major>     # pinned to one release
```

Both move on every push, so a security update reaches whoever pinned the major
as well as whoever follows `latest`. The major comes out of the built image's
own `/etc/os-release` (`13` for Debian, `24` for Ubuntu, `41` for Fedora, `9`
for CentOS), not from a list maintained here that could drift from what the
image actually is.

A rolling distribution publishes `latest` alone: Arch carries a snapshot stamp
where the others carry a release, and a tag built from it would change on every
rebuild and never come back, so nobody could pin it.

## What is in them

The distribution, upgraded to the newest package its repositories carry at build
time, plus the build dependencies every consumer needs before it can install
anything of its own: a compiler toolchain, `git`, `curl`,
`ca-certificates`, `python3` with `venv` and `pip`, and the distribution's own
packaging tools. Nothing else — a consumer installs what it needs on top.

## Distributions and platforms

Every distribution ships both platforms. Most take them from one
multi-platform upstream; Arch takes each from its own, because Docker Hub's
`archlinux` is amd64 only and arm64 comes from Arch Linux ARM, a separate
project with its own maintainers and package repositories.

| Distribution | amd64 upstream | arm64 upstream |
| --- | --- | --- |
| arch | `archlinux:latest` | `menci/archlinuxarm:base` |
| debian | `debian:stable-slim` | `debian:stable-slim` |
| ubuntu | `ubuntu:latest` | `ubuntu:latest` |
| fedora | `fedora:latest` | `fedora:latest` |
| centos | `quay.io/centos/centos:latest` | `quay.io/centos/centos:latest` |

The Dockerfile selects the upstream by `TARGETARCH`, so one build command
produces both legs. The set is declared in
[scripts/build/distros.sh](scripts/build/distros.sh), and
[scripts/test/manifest.sh](scripts/test/manifest.sh) asserts after every
publish that the tag really carries it: a silently single-architecture image
under a tag that promises both is the failure this repository is shaped
against.

## Usage

```bash
make check DISTRO=debian          # build every declared platform, publish nothing
make build DISTRO=debian          # build for this host and load it locally
make test  DISTRO=debian          # run the contract against the local build
make test-all                     # build and contract-test every distribution
make check-all                    # the multi-platform build for every distribution
OWNER=<ns> VERSION=1.2.3 make publish
```

`make build` loads a single-platform image, because a manifest list cannot live
in the local docker daemon. Use it for local work; use `check` to prove the
multi-platform build.

## Tests

Every test runs the built image rather than reading a declaration, because a
dependency script that still names a package proves nothing about an upstream
that stopped shipping it.

| Test | What it catches |
| --- | --- |
| [contract.sh](scripts/test/contract.sh) | a consumer's toolchain missing or broken: `git`, `curl`, `gpg`, `rsync`, a compiler, `python3` **with** a working `venv` and `pip`, and a trust store TLS actually succeeds through |
| [manifest.sh](scripts/test/manifest.sh) | a published tag carrying fewer platforms than the distribution declares |

The contract runs per distribution **and** per platform in
[call-test.yml](.github/workflows/call-test.yml), so an arm64 leg that builds
but produces something unusable fails there rather than in a consumer.

Lint covers shell (shellcheck), the Dockerfile (hadolint), the workflows
(actionlint) and this file (markdownlint); `make lint` runs whichever of them is
installed locally and names the ones that are not.

## Publishing

[.github/workflows/ci.yml](.github/workflows/ci.yml) is the single entry point.
It runs the lint and the contract tests first, and **publishes only once both
are green**: a published tag is what every consumer pulls, and an image that
failed its contract would break them at build time rather than here.

A pull request stops after lint and test. A push to `main` publishes `latest`
and the major, then asserts through
[manifest.sh](scripts/test/manifest.sh) that both carry every declared platform
and point at the same image.

The same chain runs **daily at 00:00 UTC**. Nothing in this repository changes
when a distribution publishes a security update, so without a scheduled rebuild
the tags would age with the last commit rather than with the distribution they
carry.

## License

[MIT](LICENSE).
