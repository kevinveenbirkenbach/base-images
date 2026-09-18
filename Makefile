.PHONY: build check check-all test test-all test-host manifest publish ci \
	lint lint-shell lint-docker lint-actions lint-markdown

# Param DISTRO: which distribution to act on (default: debian)
DISTRO ?= debian
# Param DISTROS: the set every *-all target walks
DISTROS ?= arch debian ubuntu fedora centos
# Param PLATFORMS: the platforms test-all walks
PLATFORMS ?= linux/amd64 linux/arm64
# Param IMAGE: image reference the test targets probe (default: the local build)
IMAGE ?= base-$(DISTRO):local
# Param PLATFORM: platform the contract test runs under; empty means the host's
PLATFORM ?=

# Build DISTRO for the host's platform and load it into the local docker daemon.
build:
	@bash scripts/build/image.sh --distro $(DISTRO) --load

# Build every declared platform of DISTRO without publishing; proves the build.
check:
	@bash scripts/build/image.sh --distro $(DISTRO)

# Run `check` for every distribution.
check-all:
	@for distro in $(DISTROS); do bash scripts/build/image.sh --distro $$distro || exit 1; done

# Prove IMAGE keeps the toolchain contract consumers build on.
test:
	@bash scripts/test/contract.sh $(IMAGE) $(PLATFORM)

test-all:
	@for distro in $(DISTROS); do \
		for platform in $(PLATFORMS); do \
			echo "=== $$distro $$platform ==="; \
			LOAD_TAG="base-$$distro:probe" bash scripts/build/image.sh \
				--distro $$distro --load --platform $$platform || exit 1; \
			bash scripts/test/contract.sh "base-$$distro:probe" $$platform || exit 1; \
		done; \
	done

test-host:
	@for distro in $(DISTROS); do \
		bash scripts/build/image.sh --distro $$distro --load || exit 1; \
		bash scripts/test/contract.sh base-$$distro:local || exit 1; \
	done

# Prove DISTRO's published tags carry the declared platforms and agree with each other.
# Param REPO: the published repository, e.g. ghcr.io/<owner>/base-debian
REPO ?= ghcr.io/kevinveenbirkenbach/base-$(DISTRO)
manifest:
	@bash scripts/test/manifest.sh $(DISTRO) $(REPO)

# Publish every distribution: `latest` plus the major release, unless it rolls.
# Param OWNER: required; see scripts/build/publish.sh
publish:
	@bash scripts/build/publish.sh

ci: lint test-all

lint: lint-shell lint-docker lint-actions lint-markdown

lint-shell:
	@if command -v shellcheck >/dev/null; then \
		shellcheck -e SC1091 scripts/build/*.sh scripts/test/*.sh \
			scripts/installation/*.sh scripts/installation/*/*.sh; \
	else \
		docker run --rm -v "$(CURDIR):/mnt" -w /mnt koalaman/shellcheck:stable \
			-e SC1091 scripts/build/*.sh scripts/test/*.sh \
			scripts/installation/*.sh scripts/installation/*/*.sh; \
	fi

lint-docker:
	@if command -v hadolint >/dev/null; then hadolint Dockerfile; \
	else docker run --rm -i hadolint/hadolint:latest hadolint - < Dockerfile; fi

lint-actions:
	@if command -v actionlint >/dev/null; then actionlint; \
	else docker run --rm -v "$(CURDIR):/repo" -w /repo rhysd/actionlint:latest -color; fi

lint-markdown:
	@if command -v markdownlint-cli2 >/dev/null; then markdownlint-cli2; \
	else docker run --rm -v "$(CURDIR):/workdir" davidanson/markdownlint-cli2:latest; fi
