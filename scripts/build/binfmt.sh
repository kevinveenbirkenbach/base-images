#!/usr/bin/env bash
# Usage:
#   binfmt.sh linux/amd64,linux/arm64
#   binfmt.sh linux/arm64
set -euo pipefail

PLATFORMS="${1:?usage: binfmt.sh <platform[,platform...]>}"
PROBE_IMAGE="${BINFMT_PROBE_IMAGE:-alpine:3}"

host_arch="$(uname -m)"
case "${host_arch}" in
x86_64 | amd64) host="amd64" ;;
aarch64 | arm64) host="arm64" ;;
*) host="${host_arch}" ;;
esac

can_execute() {
	docker run --rm --platform "linux/$1" "${PROBE_IMAGE}" true >/dev/null 2>&1
}

missing=()
for platform in ${PLATFORMS//,/ }; do
	arch="${platform#linux/}"
	[[ "${arch}" == "${host}" ]] && continue
	can_execute "${arch}" || missing+=("${arch}")
done

if ((${#missing[@]} == 0)); then
	exit 0
fi

echo "[binfmt] registering emulation for: ${missing[*]}"
docker run --privileged --rm tonistiigi/binfmt --install "$(
	IFS=,
	echo "${missing[*]}"
)" >/dev/null

for arch in "${missing[@]}"; do
	if ! can_execute "${arch}"; then
		echo "[binfmt] ❌ linux/${arch} still cannot execute after registering a handler." >&2
		echo "[binfmt]    Check whether this host permits --privileged containers." >&2
		exit 1
	fi
done

echo "[binfmt] ✅ ${missing[*]} ready"
