# syntax=docker/dockerfile:1

# One image per distribution, built for every platform the distribution offers.
# There are no targets: a consumer that needed a second variant would have to
# know which one it is, and the variant that carried a package manager was
# pulled by exactly one test while every runtime ignored it.
#
# Two upstream bases rather than one, selected by TARGETARCH, because a
# distribution does not always publish both platforms from the same repository:
# Arch Linux ARM is a separate project with its own images. Where one upstream
# serves both, scripts/build/distros.sh passes the same reference twice.
#
# hadolint ignore=DL3006,InvalidDefaultArgInFrom
# The bases carry no default on purpose: a default would build one
# distribution's image under another distribution's tag whenever the build arg
# is forgotten. scripts/build/distros.sh is the only place that resolves them.
ARG BASE_IMAGE_AMD64
ARG BASE_IMAGE_ARM64

FROM ${BASE_IMAGE_AMD64} AS upstream-amd64
FROM ${BASE_IMAGE_ARM64} AS upstream-arm64

FROM upstream-${TARGETARCH}

SHELL ["/bin/bash", "-lc"]

RUN cat /etc/os-release || true

WORKDIR /build

COPY scripts/installation/ scripts/installation/

RUN bash scripts/installation/dependencies.sh

WORKDIR /

CMD ["bash"]
