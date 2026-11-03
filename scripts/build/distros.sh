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
# Pinned to one major so an upstream major cannot move under a consumer;
# new-major.sh rewrites these four lines and reads the numbers back out of them.
: "${BASE_IMAGE_DEBIAN:=debian:13-slim}"
: "${BASE_IMAGE_UBUNTU:=ubuntu:26.04}"
: "${BASE_IMAGE_FEDORA:=fedora:44}"
: "${BASE_IMAGE_CENTOS:=quay.io/centos/centos:stream10}"

pin_var_of() {
	local distro="$1"
	case "${distro}" in
	debian) echo BASE_IMAGE_DEBIAN ;;
	ubuntu) echo BASE_IMAGE_UBUNTU ;;
	fedora) echo BASE_IMAGE_FEDORA ;;
	centos) echo BASE_IMAGE_CENTOS ;;
	*)
		echo "ERROR: unknown distro '${distro}'" >&2
		exit 1
		;;
	esac
}

# The reference one major above the pin. Ubuntu counts in LTS steps because its
# `latest` only moves on an LTS; its tag is the year plus `.04`.
next_major_image() {
	local distro="$1" pin
	case "${distro}" in
	debian)
		pin="${BASE_IMAGE_DEBIAN#debian:}"
		echo "debian:$((${pin%%-*} + 1))-slim"
		;;
	ubuntu)
		pin="${BASE_IMAGE_UBUNTU#ubuntu:}"
		echo "ubuntu:$((10#${pin%%.*} + 2)).04"
		;;
	fedora)
		pin="${BASE_IMAGE_FEDORA#fedora:}"
		echo "fedora:$((pin + 1))"
		;;
	centos)
		pin="${BASE_IMAGE_CENTOS##*:stream}"
		echo "quay.io/centos/centos:stream$((pin + 1))"
		;;
	*)
		echo "ERROR: unknown distro '${distro}'" >&2
		exit 1
		;;
	esac
}

resolve_base_image() {
	local distro="$1" arch="$2"
	case "${distro}:${arch}" in
	arch:amd64) echo "${BASE_IMAGE_ARCH_AMD64}" ;;
	arch:arm64) echo "${BASE_IMAGE_ARCH_ARM64}" ;;
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
	arch) return 0 ;;
	debian | ubuntu | fedora | centos) return 1 ;;
	*)
		echo "ERROR: unknown distro '${distro}'" >&2
		exit 1
		;;
	esac
}

# Shell snippet that prints the most complete release a distribution's image
# carries, run inside the image. Debian keeps its point release only in
# /etc/debian_version (VERSION_ID is the bare major) and Ubuntu its patch only
# in the leading number of VERSION; Fedora and CentOS carry the major alone.
full_version_cmd() {
	local distro="$1"
	# shellcheck disable=SC2016
	case "${distro}" in
	debian) echo 'cat /etc/debian_version' ;;
	ubuntu) echo '. /etc/os-release; echo "${VERSION%% *}"' ;;
	fedora | centos) echo '. /etc/os-release; echo "${VERSION_ID:-}"' ;;
	*)
		echo "ERROR: unknown distro '${distro}'" >&2
		exit 1
		;;
	esac
}

# Shell snippet that prints the installed package set, run inside the image.
# Two builds with the same output carry the same distribution state, which a
# manifest digest cannot tell: layer timestamps change it on every rebuild.
package_set_cmd() {
	local distro="$1"
	case "${distro}" in
	debian | ubuntu) echo 'dpkg-query -W' ;;
	fedora | centos) echo 'rpm -qa | sort' ;;
	*)
		echo "ERROR: unknown distro '${distro}'" >&2
		exit 1
		;;
	esac
}

version_prefixes() {
	local -a parts
	IFS=. read -ra parts <<<"$1"
	local acc="${parts[0]}" i
	echo "${acc}"
	for ((i = 1; i < ${#parts[@]}; i++)); do
		acc+=".${parts[i]}"
		echo "${acc}"
	done
}

resolve_platforms() {
	local distro="$1"
	case "${distro}" in
	arch | debian | ubuntu | fedora | centos) echo "linux/amd64,linux/arm64" ;;
	*)
		echo "ERROR: unknown distro '${distro}'" >&2
		exit 1
		;;
	esac
}
