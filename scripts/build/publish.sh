#!/usr/bin/env bash
# Publish every distribution's base image, each as one multi-platform tag.
#
# Each distribution is published as `latest` plus, unless it rolls, the major
# release read out of the built image.
#
# Env:
#   OWNER      registry namespace (required)
#   REGISTRY   default: ghcr.io
#   DISTROS    default: arch manjaro debian ubuntu fedora centos
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${OWNER:?OWNER must be set}"

REGISTRY="${REGISTRY:-ghcr.io}"
DISTROS="${DISTROS:-arch manjaro debian ubuntu fedora centos}"

failed=()
for distro in ${DISTROS}; do
	if bash "${SCRIPT_DIR}/image.sh" \
		--distro "${distro}" \
		--publish \
		--registry "${REGISTRY}" \
		--owner "${OWNER}"; then
		echo "✅ ${distro}"
	else
		echo "❌ ${distro}"
		failed+=("${distro}")
	fi
done

if ((${#failed[@]} > 0)); then
	echo "❌ Failed: ${failed[*]}"
	exit 1
fi

echo "🎉 Published ${DISTROS}"
