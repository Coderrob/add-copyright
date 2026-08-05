# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-08-05

### Added

- Structured `updated-count`, `skipped-count`, `error-count`, and `changed` action outputs
- Explicit SPDX identity and action-owned header boundaries for safe replacement
- License-specific `standardLicenseHeader` support with placeholder substitution
- Pinned Dev Container CLI and `act` end-to-end validation
- BATS coverage for headers, workflows, releases, and license-database transactions

### Changed

- Require Bash 4.3 or newer for the local CLI
- Preserve shebangs, Python encoding preambles, file modes, and user-maintained SPDX content
- Use concise copyright text when a license definition has no file-header template
- Store bundled SPDX license records as compressed JSON
- Publish release references atomically with noninteractive and dry-run support
- Pin Node 24 GitHub Actions dependencies to immutable commits

### Fixed

- Update the caller's checked-out repository instead of performing an internal checkout
- Surface file-discovery failures through exit status and structured outputs
- Restore the prior license database after validation errors, installation failures, or interruption
- Restore local tags and branches when atomic release publication fails

## [1.0.0] - 2026-01-23

### Added

- Initial release with support for 700+ SPDX licenses
- Multi-language support with automatic comment style detection
- Monthly automatic license database updates
- Git integration with .gitignore support
- Comprehensive test suite and documentation
