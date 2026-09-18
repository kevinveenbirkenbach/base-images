# syntax=docker/dockerfile:1
# check=skip=InvalidDefaultArgInFrom

# The bases carry no default on purpose: a default would build one
# distribution's image under another distribution's tag whenever the build arg
# is forgotten. scripts/build/distros.sh is the only place that resolves them.
ARG BASE_IMAGE_AMD64
ARG BASE_IMAGE_ARM64

# hadolint ignore=DL3006,InvalidDefaultArgInFrom
FROM ${BASE_IMAGE_AMD64} AS upstream-amd64

# hadolint ignore=DL3006,InvalidDefaultArgInFrom
FROM ${BASE_IMAGE_ARM64} AS upstream-arm64

# hadolint ignore=DL3006
FROM upstream-${TARGETARCH}

SHELL ["/bin/bash", "-lc"]

RUN cat /etc/os-release || true

WORKDIR /build

COPY scripts/installation/ scripts/installation/

RUN bash scripts/installation/dependencies.sh

WORKDIR /

CMD ["bash"]
