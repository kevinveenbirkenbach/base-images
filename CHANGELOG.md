# Changelog

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
