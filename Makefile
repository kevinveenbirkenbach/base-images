.PHONY: build check check-all test test-all manifest publish lint

# Param DISTRO: which distribution to act on (default: debian)
DISTRO ?= debian
# Param DISTROS: the set every *-all target walks
DISTROS ?= arch manjaro debian ubuntu fedora centos
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

# Build and contract-test every distribution on the host's platform.
test-all:
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

lint:
	@shellcheck -e SC1091 scripts/build/*.sh scripts/test/*.sh scripts/installation/*.sh scripts/installation/*/*.sh
	@if command -v hadolint >/dev/null; then hadolint Dockerfile; \
	else echo "hadolint is not installed here; .github/workflows/call-lint.yml runs it on every push"; fi
	@if command -v markdownlint-cli2 >/dev/null; then markdownlint-cli2; \
	else echo "markdownlint-cli2 is not installed here; .github/workflows/call-lint.yml runs it on every push"; fi
