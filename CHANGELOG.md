# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - 2026-04-21

### Added
- `Philiprehberger::BloomFilter.optimal_size` — compute bit-array size for a target false-positive rate
- `Philiprehberger::BloomFilter.optimal_hash_count` — compute optimal hash-function count for a given size

## [0.5.1] - 2026-04-15

### Fixed
- Correct homepage URL in gemspec to use hyphenated `philiprehberger-bloom-filter` path
- Add missing `gem-version` input and `placeholder` code block to bug report issue template
- Require Ruby version input on bug reports
- Add missing `alternatives` field and `placeholder` code block to feature request issue template

## [0.5.0] - 2026-04-10

### Added
- `#subset?(other)` for checking if every set bit in self is also set in other
- `#|` operator alias for `#union`
- `#&` operator alias for `#intersection`

### Changed
- Optimize `count_set_bits` with a popcount lookup table for faster `#fill_rate`, `#count_estimate`, `#saturated?`, and `#false_positive_rate`

## [0.4.0] - 2026-04-09

### Added
- `#union(other)` for non-mutating OR returning a new filter
- `#compatible?(other)` for checking structural compatibility before merge/intersection/union
- `#saturated?(threshold:)` for detecting when fill rate reaches a threshold
- `#hash` and `#eql?` so filters work as Hash keys and Set members
- `#inspect` with a readable representation including count, bit_size, hash_count, and fill_rate

## [0.3.0] - 2026-04-03

### Added
- `#==(other)` for structural equality comparison
- `#copy` for creating an independent deep clone
- `#false_positive_rate` for calculating actual FP rate based on fill rate and hash count
- `#to_json` / `.from_json(str)` for JSON serialization convenience
- `#superset?(other)` for checking if every set bit in other is also set in self
- `#empty?` for checking if the filter has no items added

## [0.2.0] - 2026-04-01

### Added
- `#bulk_add(items)` for adding all items from an enumerable
- `#count_estimate` for estimating cardinality using the fill rate formula
- `#intersection(other)` for creating a filter matching items present in both
- `#fill_rate` for checking the proportion of set bits

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
