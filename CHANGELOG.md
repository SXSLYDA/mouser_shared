# Changelog

Add notes for the next release under **Unreleased** as you work. `bump-version.ps1` turns that heading into the version number and date when you release, and CI publishes a GitHub release with those notes when the tag is pushed.

## Unreleased

- Release tooling: `CHANGELOG.md`, `bump-version.ps1` stamps it and makes an annotated tag, and CI (`.github/workflows/ci.yml`) checks every push compiles and, on a `vX.Y.Z` tag, that the tag matches `version.py` and this changelog before publishing a GitHub release.

## 0.1.1

- First tagged release (no notes recorded).
