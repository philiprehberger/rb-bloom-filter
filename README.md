# philiprehberger-bloom_filter

[![Tests](https://github.com/philiprehberger/rb-bloom-filter/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-bloom-filter/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-bloom_filter.svg)](https://rubygems.org/gems/philiprehberger-bloom_filter)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-bloom-filter)](https://github.com/philiprehberger/rb-bloom-filter/commits/main)

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

### Pre-sizing

Compute the optimal bit-array size and hash-function count before allocating a filter — useful for budgeting memory or sharing parameters between processes.

```ruby
bits = Philiprehberger::BloomFilter.optimal_size(expected_items: 10_000, false_positive_rate: 0.01)
# => 95851

hash_count = Philiprehberger::BloomFilter.optimal_hash_count(size: bits, expected_items: 10_000)
# => 7
```

### Expected False Positive Rate

Estimate the false-positive rate for any custom size, expected-item count, and hash-function count — useful when you've fixed the bit budget or hash count and want to see what FPR you'll actually get.

```ruby
Philiprehberger::BloomFilter.expected_false_positive_rate(
  size: 95_851,
  expected_items: 10_000,
  hash_count: 7
)
# => ~0.01
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

### Bulk Add

```ruby
filter = Philiprehberger::BloomFilter.new(expected_items: 10_000)
filter.bulk_add(%w[alpha beta gamma delta])
filter.include?('beta')  # => true
```

### Bulk Membership

```ruby
filter = Philiprehberger::BloomFilter.new(expected_items: 10_000)
filter.bulk_add(%w[alpha beta gamma])
filter.bulk_include?(%w[alpha beta unseen])  # => [true, true, false]
```

### Cardinality Estimation

```ruby
filter.count_estimate  # => ~4.0 (estimated unique items)
```

### Intersection

```ruby
a = Philiprehberger::BloomFilter.new(expected_items: 1000)
b = Philiprehberger::BloomFilter.new(expected_items: 1000)
a.bulk_add(%w[shared only-a])
b.bulk_add(%w[shared only-b])

result = a.intersection(b)
result.include?('shared')  # => true
result.include?('only-a')  # => false
```

### Fill Rate

```ruby
filter.fill_rate  # => 0.023 (proportion of set bits)
```

### Equality and Copying

```ruby
a = Philiprehberger::BloomFilter.new(expected_items: 1000)
b = Philiprehberger::BloomFilter.new(expected_items: 1000)
a.add('hello')
b.add('hello')
a == b  # => true

clone = a.copy
clone.add('world')
a.include?('world')  # => false (independent copy)
```

### False Positive Rate

```ruby
filter = Philiprehberger::BloomFilter.new(expected_items: 1000, false_positive_rate: 0.01)
100.times { |i| filter.add("item-#{i}") }
filter.false_positive_rate  # => ~0.0001 (actual rate based on current fill)
```

### Superset Check

```ruby
a = Philiprehberger::BloomFilter.new(expected_items: 1000)
b = Philiprehberger::BloomFilter.new(expected_items: 1000)
a.bulk_add(%w[alpha beta gamma])
b.add('alpha')
a.superset?(b)  # => true
```

### Empty Check

```ruby
filter = Philiprehberger::BloomFilter.new(expected_items: 1000)
filter.empty?  # => true
filter.add('hello')
filter.empty?  # => false
```

### Union (Non-Mutating)

```ruby
a = Philiprehberger::BloomFilter.new(expected_items: 1000)
b = Philiprehberger::BloomFilter.new(expected_items: 1000)
a.add('alpha')
b.add('beta')

result = a.union(b)
result.include?('alpha')  # => true
result.include?('beta')   # => true
a.include?('beta')        # => false (a is unchanged)
```

### Subset Check

```ruby
a = Philiprehberger::BloomFilter.new(expected_items: 1000)
b = Philiprehberger::BloomFilter.new(expected_items: 1000)
a.add('alpha')
b.bulk_add(%w[alpha beta gamma])
a.subset?(b)  # => true
```

### Operator Aliases

```ruby
a = Philiprehberger::BloomFilter.new(expected_items: 1000)
b = Philiprehberger::BloomFilter.new(expected_items: 1000)
a.add('alpha')
b.add('beta')

union = a | b              # same as a.union(b)
intersection = a & b       # same as a.intersection(b)
```

### Compatibility Check

```ruby
a = Philiprehberger::BloomFilter.new(expected_items: 1000)
b = Philiprehberger::BloomFilter.new(expected_items: 1000)
a.compatible?(b)  # => true, safe to merge / intersect / union
```

### Saturation Check

```ruby
filter = Philiprehberger::BloomFilter.new(expected_items: 100)
filter.saturated?  # => false
200.times { |i| filter.add("item-#{i}") }
filter.saturated?(threshold: 0.5)  # => true
```

### Serialization

```ruby
data = filter.serialize
restored = Philiprehberger::BloomFilter.deserialize(data)
restored.include?('hello')  # => true
```

### JSON Serialization

```ruby
json = filter.to_json
restored = Philiprehberger::BloomFilter.from_json(json)
restored.include?('hello')  # => true
```

## API

| Method | Description |
|--------|-------------|
| `.new(expected_items:, false_positive_rate:)` | Create a new bloom filter |
| `.optimal_size(expected_items:, false_positive_rate:)` | Compute optimal bit-array size for a target false positive rate |
| `.optimal_hash_count(size:, expected_items:)` | Compute optimal hash-function count for a given bit-array size |
| `.expected_false_positive_rate(size:, expected_items:, hash_count:)` | Estimate FPR for a custom size, item count, and hash-function count |
| `#add(item)` | Add an item to the filter |
| `#include?(item)` | Check if an item might be in the filter |
| `#merge(other)` | Merge another compatible filter into this one |
| `#clear` | Reset the filter |
| `#count` | Number of items added |
| `#memory_usage` | Bit array size in bytes |
| `#serialize` | Serialize to a hash |
| `#bulk_add(items)` | Add all items from an enumerable |
| `#bulk_include?(items)` | Check membership for many items, returning an array of booleans |
| `#count_estimate` | Estimate unique item count from fill rate |
| `#intersection(other)` | Create filter matching items in both |
| `#fill_rate` | Proportion of set bits (0.0 to 1.0) |
| `#==(other)` | Structural equality comparison |
| `#copy` | Create an independent deep clone |
| `#false_positive_rate` | Actual FP rate based on current fill |
| `#to_json` | Serialize to JSON string |
| `#superset?(other)` | Check if self contains all bits of other |
| `#empty?` | Check if no items have been added |
| `#union(other)` | Non-mutating OR returning a new filter |
| `#subset?(other)` | Check if every set bit in self is also set in other |
| `#compatible?(other)` | Check structural compatibility with another filter |
| `#saturated?(threshold:)` | True if fill rate is at/above threshold |
| `#\|(other)` | Operator alias for `#union` |
| `#&(other)` | Operator alias for `#intersection` |
| `#hash` / `#eql?` | Hash key support consistent with `#==` |
| `#inspect` | Human-readable representation |
| `.deserialize(data)` | Restore a filter from serialized data |
| `.from_json(str)` | Restore a filter from a JSON string |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-bloom-filter)

🐛 [Report issues](https://github.com/philiprehberger/rb-bloom-filter/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-bloom-filter/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
