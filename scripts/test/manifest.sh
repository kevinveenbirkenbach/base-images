#!/usr/bin/env bash
# Prove a distribution's published tags are what they promise.
#
# Two failures this catches, neither visible in a green build:
#
#   * `latest` carrying fewer platforms than the distribution declares, which
#     nobody notices until a consumer on the missing platform pulls it;
#   * `latest` and a release-prefix tag (13, 13.2) drifting apart, so a consumer
#     that pinned one quietly stops receiving what `latest` gets.
#
# Usage:
#   manifest.sh <distro> <repository-ref-without-tag>
#
# Example:
#   manifest.sh debian ghcr.io/kevinveenbirkenbach/base-debian
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/build/distros.sh
source "${SCRIPT_DIR}/../build/distros.sh"

DISTRO="${1:?usage: manifest.sh <distro> <repository-ref>}"
REPO="${2:?usage: manifest.sh <distro> <repository-ref>}"

platforms_of() {
	docker buildx imagetools inspect "$1" --raw |
		jq -r '.manifests[]
			| select(.platform.os != "unknown")
			| "\(.platform.os)/\(.platform.architecture)"' |
		sort -u | tr '\n' ' '
}

digest_of() {
	docker buildx imagetools inspect "$1" --format '{{json .Manifest.Digest}}'
}

expected="$(resolve_platforms "${DISTRO}" | tr ',' '\n' | sort | tr '\n' ' ')"
actual="$(platforms_of "${REPO}:latest")"

echo "[manifest] ${REPO}:latest"
echo "[manifest] declared: ${expected}"
echo "[manifest] found:    ${actual}"

if [[ "${expected}" != "${actual}" ]]; then
	echo "[manifest] ❌ ${DISTRO}: latest does not carry the declared platforms." >&2
	echo "[manifest]    A consumer on a missing platform pulls this tag and fails at exec." >&2
	exit 1
fi

if is_rolling "${DISTRO}"; then
	echo "[manifest] ✅ ${DISTRO} (rolling: latest only)"
	exit 0
fi

version="$(
	docker run --rm "${REPO}:latest" bash -lc "$(full_version_cmd "${DISTRO}")"
)"
latest_digest="$(digest_of "${REPO}:latest")"

while read -r prefix; do
	if [[ "${latest_digest}" != "$(digest_of "${REPO}:${prefix}")" ]]; then
		echo "[manifest] ❌ ${DISTRO}: latest and :${prefix} point at different images." >&2
		echo "[manifest]    Whoever pinned ${prefix} stopped receiving what latest gets." >&2
		exit 1
	fi
done < <(version_prefixes "${version}")

echo "[manifest] ✅ ${DISTRO} (latest == every prefix of ${version}, ${expected})"
