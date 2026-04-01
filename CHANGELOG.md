# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.6] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.1.5] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.1.4] - 2026-03-26

### Changed

- Add Sponsor badge and fix License link format in README

## [0.1.3] - 2026-03-24

### Fixed
- Fix README one-liner to remove trailing period

## [0.1.2] - 2026-03-24

### Fixed
- Remove inline comments from Development section to match template

## [0.1.1] - 2026-03-22

### Changed

- Expand test coverage to 30+ examples covering false positive rate approximation, empty filter queries, duplicate adds, chaining, clear behavior, memory usage with different fp_rate configurations, merge edge cases, and serialization round-trips

## [0.1.0] - 2026-03-22

### Added
- Initial release
- Bloom filter with configurable expected items and false positive rate
- Add and membership check operations
- Merge two compatible bloom filters
- Serialize and deserialize for persistence
- Memory usage reporting
- Automatic optimal bit array size and hash function count calculation
