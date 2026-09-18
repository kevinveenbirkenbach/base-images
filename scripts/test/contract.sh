#!/usr/bin/env bash
# Prove one image keeps the promise its consumers build on.
#
# Every check runs the tool rather than reading a package list: a dependency
# script that still names a package proves nothing about an upstream base that
# stopped shipping it, and a `python3` that exists without `venv` is a Debian
# split package away from breaking every consumer that builds one.
#
# Usage:
#   contract.sh <image-ref> [platform]
#
# Example:
#   contract.sh base-debian:local
#   contract.sh ghcr.io/kevinveenbirkenbach/base-debian:13 linux/arm64
set -euo pipefail

IMAGE="${1:?usage: contract.sh <image-ref> [platform]}"
PLATFORM="${2:-}"

run_args=(--rm)
if [[ -n "${PLATFORM}" ]]; then
	run_args+=(--platform "${PLATFORM}")
	bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../build" && pwd)/binfmt.sh" "${PLATFORM}"
fi

echo "[contract] ${IMAGE}${PLATFORM:+ (${PLATFORM})}"

docker run "${run_args[@]}" "${IMAGE}" bash -lc '
set -euo pipefail

fail() { echo "[contract] ❌ $*" >&2; exit 1; }

# The toolchain every consumer installs on top of.
for binary in git curl gpg rsync python3; do
    command -v "${binary}" >/dev/null || fail "missing: ${binary}"
    "${binary}" --version >/dev/null 2>&1 || fail "not runnable: ${binary}"
done

# A compiler, under whichever name the distribution ships it.
command -v cc >/dev/null || command -v gcc >/dev/null || fail "missing: cc/gcc"

# python3 alone does not prove venv: Debian and Ubuntu ship it separately, and
# every consumer here builds a virtualenv as its first step.
python3 -m venv /tmp/contract-venv >/dev/null || fail "python3 -m venv does not work"
/tmp/contract-venv/bin/python -m pip --version >/dev/null || fail "pip missing inside a fresh venv"
rm -rf /tmp/contract-venv

# ca-certificates being installed is not the same as the trust store being
# usable; a consumer discovers the difference on its first clone or pip install.
curl -sSf https://github.com >/dev/null || fail "TLS to github.com fails: trust store unusable"

echo "[contract] ✅ $(. /etc/os-release && echo "${PRETTY_NAME}") on $(uname -m)"
'
