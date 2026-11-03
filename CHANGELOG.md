# Changelog

## [2.0.0] - 2026-11-03

Added:

* Tags: every release prefix, such as *13* and *13.7*, follows each build
* Tags: a build tag such as *13.7.1767225600* ends in the unix timestamp
* Tags: pushed only when the installed package set changed
* Bases: a daily check opens a pull request when a new upstream major exists

Changed:

* Bases: Debian 13, Ubuntu 26.04, Fedora 44 and CentOS Stream 10 are pinned
* Tags: *latest* follows these majors instead of the upstream *latest*

Upgrade notes:

* Fedora: *base-fedora* moves from 45 back to 44 until OpenZFS ships fc45
* Ubuntu, CentOS: the old *24* and *9* tags receive no new builds

## [1.1.2] - 2026-11-03

Fixed:

* Debian, Ubuntu: images now build with *apt-get dist-upgrade*
* Debian, Ubuntu: patched packages such as *tzdata* are no longer stale
* CentOS, Fedora, Arch: unchanged; their builds already upgraded

## [1.1.1] - 2026-09-22

* Security scans run again; the scanner pins named unresolvable versions.
* Every action is pinned to a commit SHA that Dependabot keeps current.
* *SECURITY.md* names private channels for reporting a vulnerability.
* The images themselves are unchanged; upstream bases still track tags.

## [1.1.0] - 2026-09-22

* CentOS builds on *quay.io/centos/centos:latest* instead of the pinned *stream9*, which is CentOS Stream 10 today.
* Stream 9 ships Python 3.9, and consumers that require 3.10 or newer failed on it.
* Stream 10 ships Python 3.12 and serves amd64 and arm64 from the same upstream.
* The major tag comes from */etc/os-release*, so *base-centos:10* is new.
* *base-centos:9* is no longer rebuilt, and *latest* moves to EL10 with this release.
* On amd64, EL10 needs an x86-64-v3 CPU (AVX2).
* The next Stream release reaches *latest* without a change here, the same way fedora and ubuntu do.

## [1.0.2] - 2026-09-20

* The images publish again: hadolint no longer fails the *Dockerfile* lint job.
* *InvalidDefaultArgInFrom* is a BuildKit check, not a hadolint rule.
* hadolint 2.12.0 discards a whole ignore directive that names an unknown rule.
* Both *FROM* lines were therefore unguarded and reported *DL3006*.
* The BuildKit check stays covered by the *check=skip* directive on line 2.
* Publishing waits on lint, so this one job kept the registry empty.

## [1.0.1] - 2026-09-18

* Arch builds for arm64 again: *DisableSandbox* in */etc/pacman.conf*.
* pacman 7 confines its downloader with Landlock, which qemu does not emulate.
* *hadolint* directives sit on the *FROM* they cover, not in the file header.
* *check=skip=InvalidDefaultArgInFrom* silences BuildKit's own warning.
* *pkgmgr release* left a trailing blank line in *CHANGELOG.md*, MD012.
* manjaro is gone: its arm64 upstream is stale and Manjaro ARM is discontinued.
* *make lint* no longer skips a linter that is missing; it pulls its image.
* *make lint-actions* runs *actionlint*, which had no local target before.
* *make test-all* walks *PLATFORMS* too, matching the CI matrix.
* *make test-host* keeps the old host-only sweep for quick iteration.
* *make ci* runs what the CI workflow runs, without publishing.
* *scripts/build/binfmt.sh* registers emulation before a build or a test uses it.
* Both workflows carry a concurrency group, cancelling pull request runs only.

## [1.0.0] - 2026-09-18

Official Release 🥳
