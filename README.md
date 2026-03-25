# philiprehberger-bloom_filter

[![Tests](https://github.com/philiprehberger/rb-bloom-filter/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-bloom-filter/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-bloom_filter.svg)](https://rubygems.org/gems/philiprehberger-bloom_filter)
[![License](https://img.shields.io/github/license/philiprehberger/rb-bloom-filter)](LICENSE)

Space-efficient probabilistic set with configurable false positive rate

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-bloom_filter"
```

Or install directly:

```bash
gem install philiprehberger-bloom_filter
```

## Usage

```ruby
require "philiprehberger/bloom_filter"

filter = Philiprehberger::BloomFilter.new(expected_items: 10_000, false_positive_rate: 0.01)
filter.add('hello')
filter.include?('hello')  # => true
filter.include?('world')  # => false
```

### Merge Filters

```ruby
a = Philiprehberger::BloomFilter.new(expected_items: 1000)
b = Philiprehberger::BloomFilter.new(expected_items: 1000)
a.add('alpha')
b.add('beta')
a.merge(b)
a.include?('beta')  # => true
```

### Serialization

```ruby
data = filter.serialize
restored = Philiprehberger::BloomFilter.deserialize(data)
restored.include?('hello')  # => true
```

## API

| Method | Description |
|--------|-------------|
| `.new(expected_items:, false_positive_rate:)` | Create a new bloom filter |
| `#add(item)` | Add an item to the filter |
| `#include?(item)` | Check if an item might be in the filter |
| `#merge(other)` | Merge another compatible filter into this one |
| `#clear` | Reset the filter |
| `#count` | Number of items added |
| `#memory_usage` | Bit array size in bytes |
| `#serialize` | Serialize to a hash |
| `.deserialize(data)` | Restore a filter from serialized data |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
