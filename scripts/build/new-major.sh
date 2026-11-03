#!/usr/bin/env bash
# Report every distribution whose upstream published the major above the pin in
# distros.sh, and optionally open one pull request per distribution that raises
# the pin. A human merges it; nothing here moves a pin by itself.
#
# Usage:
#   new-major.sh [--open-pr]
#
# --open-pr needs a clean checkout of main, `origin` with push rights, and `gh`
# authenticated with permission to open pull requests.
#
# Exit: 0 when the check ran, whether or not a new major exists; 2 when a
# registry answered something other than "tag exists" or "tag does not exist".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/build/distros.sh
source "${SCRIPT_DIR}/distros.sh"

OPEN_PR=0
case "${1:-}" in
"") ;;
--open-pr) OPEN_PR=1 ;;
*)
	echo "ERROR: unknown argument '$1'" >&2
	exit 2
	;;
esac

registry_has() {
	local ref="$1" repo tag code
	case "${ref}" in
	quay.io/*)
		repo="${ref#quay.io/}"
		tag="${repo##*:}"
		repo="${repo%:*}"
		curl -fsS "https://quay.io/api/v1/repository/${repo}/tag/?specificTag=${tag}&onlyActiveTags=true" |
			jq -e '.tags | length > 0' >/dev/null
		;;
	*)
		repo="${ref%:*}"
		tag="${ref##*:}"
		code="$(curl -sS -o /dev/null -w '%{http_code}' \
			"https://hub.docker.com/v2/repositories/library/${repo}/tags/${tag}")"
		case "${code}" in
		200) return 0 ;;
		404) return 1 ;;
		*)
			echo "ERROR: Docker Hub answered ${code} for ${ref}" >&2
			exit 2
			;;
		esac
		;;
	esac
}

open_pr() {
	local distro="$1" current="$2" next="$3" branch
	branch="bump/${distro}-${next##*:}"

	if git ls-remote --exit-code --heads origin "${branch}" >/dev/null 2>&1; then
		echo "[new-major] ${branch} already exists, no second pull request."
		return 0
	fi

	git switch -c "${branch}"
	sed -i "s|:=${current}}|:=${next}}|" "${SCRIPT_DIR}/distros.sh"
	git add "${SCRIPT_DIR}/distros.sh"
	git commit -m "chore(${distro}): pin ${next}"
	git push origin "${branch}"
	gh pr create --base main --head "${branch}" \
		--title "chore(${distro}): pin ${next}" \
		--body "Upstream published \`${next}\`; the pin is \`${current}\`. Merging moves every consumer of \`base-${distro}:latest\` to the new major. Check that the contract tests pass first: a pull request opened with the workflow token does not start them by itself, so close and reopen it."
	git switch -
}

for distro in debian ubuntu fedora centos; do
	var="$(pin_var_of "${distro}")"
	current="${!var}"
	next="$(next_major_image "${distro}")"
	if registry_has "${next}"; then
		echo "[new-major] ${distro}: ${current} -> ${next}"
		if ((OPEN_PR == 1)); then
			open_pr "${distro}" "${current}" "${next}"
		fi
	else
		echo "[new-major] ${distro}: ${current} is the newest major"
	fi
done
