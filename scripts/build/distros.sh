#!/usr/bin/env bash
# Declaration of every distribution this repository publishes an image for:
# which upstream image each platform builds on, and which platforms it offers.
#
# Two references per distribution, because a distribution does not always
# publish both platforms from one repository. Docker Hub's `archlinux` is amd64
# only; arm64 comes from Arch Linux ARM, a separate project with its own
# maintainers and package repositories. Everything else serves both platforms
# from the same multi-platform upstream, and declares it twice so the resolver
# has one shape.
#
# Sourced by image.sh, publish.sh and the contract test; prints nothing on its own.
set -euo pipefail

: "${BASE_IMAGE_ARCH_AMD64:=archlinux:latest}"
: "${BASE_IMAGE_ARCH_ARM64:=menci/archlinuxarm:base}"
: "${BASE_IMAGE_MANJARO:=manjarolinux/base:latest}"
: "${BASE_IMAGE_DEBIAN:=debian:stable-slim}"
: "${BASE_IMAGE_UBUNTU:=ubuntu:latest}"
: "${BASE_IMAGE_FEDORA:=fedora:latest}"
: "${BASE_IMAGE_CENTOS:=quay.io/centos/centos:stream9}"

resolve_base_image() {
	local distro="$1" arch="$2"
	case "${distro}:${arch}" in
	arch:amd64) echo "${BASE_IMAGE_ARCH_AMD64}" ;;
	arch:arm64) echo "${BASE_IMAGE_ARCH_ARM64}" ;;
	manjaro:*) echo "${BASE_IMAGE_MANJARO}" ;;
	debian:*) echo "${BASE_IMAGE_DEBIAN}" ;;
	ubuntu:*) echo "${BASE_IMAGE_UBUNTU}" ;;
	fedora:*) echo "${BASE_IMAGE_FEDORA}" ;;
	centos:*) echo "${BASE_IMAGE_CENTOS}" ;;
	*)
		echo "ERROR: unknown distro '${distro}' or architecture '${arch}'" >&2
		exit 1
		;;
	esac
}

# Whether a distribution rolls rather than releases. A rolling image carries a
# snapshot stamp where the others carry a release number, and a tag built from
# it would change on every rebuild and never come back, so nobody could pin it.
# Rolling distributions therefore publish `latest` alone.
is_rolling() {
	local distro="$1"
	case "${distro}" in
	arch | manjaro) return 0 ;;
	debian | ubuntu | fedora | centos) return 1 ;;
	*)
		echo "ERROR: unknown distro '${distro}'" >&2
		exit 1
		;;
	esac
}

# The major of a VERSION_ID, which is what a consumer pins: Debian 13, Ubuntu
# 24, Fedora 41, CentOS 9. The minor moves under it with every rebuild, and a
# tag that carries it would pin a build rather than a release.
major_of() {
	local version_id="$1"
	echo "${version_id%%.*}"
}

resolve_platforms() {
	local distro="$1"
	case "${distro}" in
	arch | manjaro | debian | ubuntu | fedora | centos) echo "linux/amd64,linux/arm64" ;;
	*)
		echo "ERROR: unknown distro '${distro}'" >&2
		exit 1
		;;
	esac
}
