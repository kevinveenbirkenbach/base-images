#!/usr/bin/env bash
# Build one distribution's base image for every platform it declares.
#
# Usage:
#   image.sh --distro debian [--load | --publish --registry R --owner O]
#
# Options:
#   --distro <id>     arch | debian | ubuntu | fedora | centos (required)
#   --load            build a single-platform image into the local docker
#                     daemon, because a manifest list cannot be loaded there
#   --platform <p>    with --load: which platform to build (default: the host's)
#   LOAD_TAG          env; overrides the tag --load writes (default base-<distro>:local)
#   --publish         push every declared platform, tagged `latest` and, unless
#                     the distribution rolls, every prefix of the release inside
#                     the image plus `<release>.<unix-timestamp>`; skipped when
#                     the package set equals the published one
#   --registry <r>    registry for --publish (default: ghcr.io)
#   --owner <o>       registry namespace for --publish
#   --no-cache        build without the layer cache
#
# Without --load and --publish the build runs and is discarded, which is what
# CI wants for a pull request: it proves every platform still builds without
# publishing anything.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=scripts/build/distros.sh
source "${SCRIPT_DIR}/distros.sh"

DISTRO=""
MODE="check"
ONE_PLATFORM=""
REGISTRY="ghcr.io"
OWNER=""
NO_CACHE=0

while [[ $# -gt 0 ]]; do
	case "$1" in
	--distro)
		DISTRO="${2:-}"
		shift 2
		;;
	--load)
		MODE="load"
		shift
		;;
	--platform)
		ONE_PLATFORM="${2:-}"
		shift 2
		;;
	--publish)
		MODE="publish"
		shift
		;;
	--registry)
		REGISTRY="${2:-}"
		shift 2
		;;
	--owner)
		OWNER="${2:-}"
		shift 2
		;;
	--no-cache)
		NO_CACHE=1
		shift
		;;
	*)
		echo "ERROR: unknown argument '$1'" >&2
		exit 2
		;;
	esac
done

: "${DISTRO:?--distro is required}"

BASE_AMD64="$(resolve_base_image "${DISTRO}" amd64)"
BASE_ARM64="$(resolve_base_image "${DISTRO}" arm64)"
build_args=(
	--build-arg "BASE_IMAGE_AMD64=${BASE_AMD64}"
	--build-arg "BASE_IMAGE_ARM64=${BASE_ARM64}"
)
((NO_CACHE == 1)) && build_args+=(--no-cache)
PLATFORMS="$(resolve_platforms "${DISTRO}")"

bash "${SCRIPT_DIR}/binfmt.sh" "${ONE_PLATFORM:-${PLATFORMS}}"

# The default `docker` driver cannot build a manifest list; only a
# docker-container builder can. CI installs one through setup-buildx-action,
# and a workstation gets the same one here rather than an error telling the
# operator to read a docs page.
BUILDER="${BUILDX_BUILDER:-base-images}"
if ! docker buildx inspect "${BUILDER}" >/dev/null 2>&1; then
	echo "[build] creating buildx builder '${BUILDER}' (docker-container driver)"
	docker buildx create --name "${BUILDER}" --driver docker-container >/dev/null
fi
build_args+=(--builder "${BUILDER}")

exit_no_version() {
	echo "[build] ❌ $1 declares a release but its image reports '$2', not a dotted number." >&2
	echo "[build]    Either the upstream base changed, or $1 rolls and belongs in is_rolling()." >&2
	exit 1
}

echo "------------------------------------------------------------"
echo "[build] distro    = ${DISTRO}"
echo "[build] amd64     = ${BASE_AMD64}"
echo "[build] arm64     = ${BASE_ARM64}"
echo "[build] platforms = ${PLATFORMS}"
echo "[build] mode      = ${MODE}"
echo "------------------------------------------------------------"

case "${MODE}" in
publish)
	: "${OWNER:?--publish requires --owner}"

	tag_base="${REGISTRY}/${OWNER}/base-${DISTRO}"
	tags=(-t "${tag_base}:latest")

	# The release lives inside the image, so it cannot be a tag until something
	# has been built. The host platform is loaded first and read; the
	# multi-platform push that follows reuses those layers from the cache.
	if ! is_rolling "${DISTRO}"; then
		docker buildx build \
			-t "base-${DISTRO}:version-probe" \
			"${build_args[@]}" \
			--load \
			"${REPO_ROOT}"

		version="$(
			docker run --rm "base-${DISTRO}:version-probe" \
				bash -lc "$(full_version_cmd "${DISTRO}")"
		)"
		[[ "${version}" =~ ^[0-9]+(\.[0-9]+)*$ ]] ||
			exit_no_version "${DISTRO}" "${version}"

		package_set="$(package_set_cmd "${DISTRO}")"
		built_set="$(docker run --rm "base-${DISTRO}:version-probe" bash -lc "${package_set}" | sha256sum)"
		published_set="$(docker run --rm "${tag_base}:latest" bash -lc "${package_set}" 2>/dev/null | sha256sum || true)"
		if [[ "${built_set}" == "${published_set}" ]] &&
			docker buildx imagetools inspect "${tag_base}:${version}" >/dev/null 2>&1; then
			echo "[build] ${DISTRO} unchanged since the published ${version}, nothing to push."
			exit 0
		fi

		while read -r prefix; do
			tags+=(-t "${tag_base}:${prefix}")
		done < <(version_prefixes "${version}")
		stamp="$(date -u +%s)"
		tags+=(-t "${tag_base}:${version}.${stamp}")
		echo "[build] release   = ${version} -> :${version}.${stamp} and its prefixes"
	else
		echo "[build] release   = rolling, latest only"
	fi

	docker buildx build \
		--platform "${PLATFORMS}" \
		"${tags[@]}" \
		"${build_args[@]}" \
		--push \
		"${REPO_ROOT}"
	;;
load)
	# One platform per load: a manifest list has no place in the local daemon.
	platform_args=()
	[[ -n "${ONE_PLATFORM}" ]] && platform_args+=(--platform "${ONE_PLATFORM}")

	docker buildx build \
		-t "${LOAD_TAG:-base-${DISTRO}:local}" \
		"${platform_args[@]}" \
		"${build_args[@]}" \
		--load \
		"${REPO_ROOT}"
	;;
check)
	docker buildx build \
		--platform "${PLATFORMS}" \
		"${build_args[@]}" \
		"${REPO_ROOT}"
	;;
esac

echo "[build] ${DISTRO} done."
