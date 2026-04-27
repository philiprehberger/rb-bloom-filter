# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::BloomFilter do
  describe 'VERSION' do
    it 'has a version number' do
      expect(Philiprehberger::BloomFilter::VERSION).not_to be_nil
    end
  end

  describe '.new' do
    it 'creates a filter with expected parameters' do
      filter = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      expect(filter).to be_a(Philiprehberger::BloomFilter::Filter)
    end

    it 'raises on non-positive expected_items' do
      expect { described_class.new(expected_items: 0, false_positive_rate: 0.01) }
        .to raise_error(Philiprehberger::BloomFilter::Error)
    end

    it 'raises on invalid false_positive_rate' do
      expect { described_class.new(expected_items: 100, false_positive_rate: 0.0) }
        .to raise_error(Philiprehberger::BloomFilter::Error)
    end

    it 'raises when false_positive_rate is 1.0 or above' do
      expect { described_class.new(expected_items: 100, false_positive_rate: 1.0) }
        .to raise_error(Philiprehberger::BloomFilter::Error)
    end

    it 'defaults false_positive_rate to 0.01' do
      filter = described_class.new(expected_items: 100)
      expect(filter.count).to eq(0)
    end
  end

  describe '.optimal_size' do
    it 'returns a positive Integer' do
      size = described_class.optimal_size(expected_items: 1000, false_positive_rate: 0.01)
      expect(size).to be_a(Integer)
      expect(size).to be > 0
    end

    it 'matches the textbook formula for known inputs' do
      n = 1000
      p = 0.01
      expected = (-(n * Math.log(p)) / (Math.log(2)**2)).ceil
      expect(described_class.optimal_size(expected_items: n, false_positive_rate: p)).to eq(expected)
    end

    it 'grows as expected_items grows' do
      small = described_class.optimal_size(expected_items: 100, false_positive_rate: 0.01)
      large = described_class.optimal_size(expected_items: 10_000, false_positive_rate: 0.01)
      expect(large).to be > small
    end

    it 'grows as false_positive_rate tightens' do
      loose = described_class.optimal_size(expected_items: 1000, false_positive_rate: 0.1)
      tight = described_class.optimal_size(expected_items: 1000, false_positive_rate: 0.001)
      expect(tight).to be > loose
    end

    it 'defaults false_positive_rate to 0.01' do
      default = described_class.optimal_size(expected_items: 1000)
      explicit = described_class.optimal_size(expected_items: 1000, false_positive_rate: 0.01)
      expect(default).to eq(explicit)
    end

    it 'raises ArgumentError for zero expected_items' do
      expect { described_class.optimal_size(expected_items: 0, false_positive_rate: 0.01) }
        .to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for negative expected_items' do
      expect { described_class.optimal_size(expected_items: -5, false_positive_rate: 0.01) }
        .to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for non-Integer expected_items' do
      expect { described_class.optimal_size(expected_items: 1.5, false_positive_rate: 0.01) }
        .to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for zero false_positive_rate' do
      expect { described_class.optimal_size(expected_items: 100, false_positive_rate: 0.0) }
        .to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for false_positive_rate of 1.0' do
      expect { described_class.optimal_size(expected_items: 100, false_positive_rate: 1.0) }
        .to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for false_positive_rate above 1' do
      expect { described_class.optimal_size(expected_items: 100, false_positive_rate: 1.5) }
        .to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for negative false_positive_rate' do
      expect { described_class.optimal_size(expected_items: 100, false_positive_rate: -0.1) }
        .to raise_error(ArgumentError)
    end
  end

  describe '.optimal_hash_count' do
    it 'returns a positive Integer' do
      k = described_class.optimal_hash_count(size: 9600, expected_items: 1000)
      expect(k).to be_a(Integer)
      expect(k).to be > 0
    end

    it 'matches the textbook formula for known inputs' do
      m = 9600
      n = 1000
      expected = [(m.to_f / n * Math.log(2)).ceil, 1].max
      expect(described_class.optimal_hash_count(size: m, expected_items: n)).to eq(expected)
    end

    it 'returns at least 1 even when the ratio is tiny' do
      expect(described_class.optimal_hash_count(size: 1, expected_items: 1_000_000)).to eq(1)
    end

    it 'increases with larger size for fixed expected_items' do
      small = described_class.optimal_hash_count(size: 1000, expected_items: 100)
      large = described_class.optimal_hash_count(size: 100_000, expected_items: 100)
      expect(large).to be > small
    end

    it 'raises ArgumentError for zero size' do
      expect { described_class.optimal_hash_count(size: 0, expected_items: 100) }
        .to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for negative size' do
      expect { described_class.optimal_hash_count(size: -10, expected_items: 100) }
        .to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for non-Integer size' do
      expect { described_class.optimal_hash_count(size: 10.5, expected_items: 100) }
        .to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for zero expected_items' do
      expect { described_class.optimal_hash_count(size: 1000, expected_items: 0) }
        .to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for negative expected_items' do
      expect { described_class.optimal_hash_count(size: 1000, expected_items: -3) }
        .to raise_error(ArgumentError)
    end
  end

  describe 'Filter sizing consistency' do
    it 'allocates exactly the bits computed by .optimal_size' do
      expected_items = 1000
      false_positive_rate = 0.01
      filter = described_class.new(expected_items: expected_items, false_positive_rate: false_positive_rate)
      expected_bits = described_class.optimal_size(
        expected_items: expected_items,
        false_positive_rate: false_positive_rate
      )
      expect(filter.memory_usage).to eq((expected_bits + 7) / 8)
    end
  end

  describe '#add and #include?' do
    let(:filter) { described_class.new(expected_items: 1000, false_positive_rate: 0.01) }

    it 'returns true for added items' do
      filter.add('hello')
      expect(filter.include?('hello')).to be true
    end

    it 'returns false for items not added' do
      expect(filter.include?('missing')).to be false
    end

    it 'handles multiple items' do
      %w[alpha beta gamma].each { |item| filter.add(item) }
      expect(filter.include?('alpha')).to be true
      expect(filter.include?('beta')).to be true
      expect(filter.include?('gamma')).to be true
    end

    it 'handles integer items via to_s' do
      filter.add(42)
      expect(filter.include?(42)).to be true
    end

    it 'handles symbol items via to_s' do
      filter.add(:test)
      expect(filter.include?(:test)).to be true
    end
  end

  describe '#count' do
    it 'starts at zero' do
      filter = described_class.new(expected_items: 100)
      expect(filter.count).to eq(0)
    end

    it 'increments with each add' do
      filter = described_class.new(expected_items: 100)
      filter.add('a')
      filter.add('b')
      expect(filter.count).to eq(2)
    end
  end

  describe '#clear' do
    it 'resets the filter' do
      filter = described_class.new(expected_items: 100)
      filter.add('hello')
      filter.clear
      expect(filter.count).to eq(0)
      expect(filter.include?('hello')).to be false
    end
  end

  describe '#memory_usage' do
    it 'returns positive byte count' do
      filter = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      expect(filter.memory_usage).to be > 0
    end

    it 'increases with more expected items' do
      small = described_class.new(expected_items: 100, false_positive_rate: 0.01)
      large = described_class.new(expected_items: 10_000, false_positive_rate: 0.01)
      expect(large.memory_usage).to be > small.memory_usage
    end
  end

  describe '#merge' do
    it 'combines two filters' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      a.add('alpha')
      b.add('beta')
      a.merge(b)
      expect(a.include?('alpha')).to be true
      expect(a.include?('beta')).to be true
    end

    it 'raises on incompatible filters' do
      a = described_class.new(expected_items: 100, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 10_000, false_positive_rate: 0.01)
      expect { a.merge(b) }.to raise_error(Philiprehberger::BloomFilter::Error)
    end
  end

  describe '#serialize and .deserialize' do
    it 'round-trips correctly' do
      filter = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      filter.add('hello')
      filter.add('world')

      data = filter.serialize
      restored = described_class.deserialize(data)

      expect(restored.include?('hello')).to be true
      expect(restored.include?('world')).to be true
      expect(restored.count).to eq(2)
    end

    it 'serializes to a hash with expected keys' do
      filter = described_class.new(expected_items: 100)
      data = filter.serialize
      expect(data).to include('expected_items', 'false_positive_rate', 'bit_size', 'hash_count', 'bits', 'count')
    end
  end

  describe 'false positive rate' do
    it 'stays within expected bounds for fp_rate 0.05' do
      filter = described_class.new(expected_items: 1000, false_positive_rate: 0.05)
      1000.times { |i| filter.add("item-#{i}") }

      false_positives = (1000..1999).count { |i| filter.include?("item-#{i}") }
      rate = false_positives / 1000.0

      expect(rate).to be < 0.10
    end

    it 'stays within expected bounds for fp_rate 0.01' do
      filter = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      1000.times { |i| filter.add("item-#{i}") }

      false_positives = (1000..1999).count { |i| filter.include?("item-#{i}") }
      rate = false_positives / 1000.0

      expect(rate).to be < 0.05
    end

    it 'has lower fp rate with lower configured rate' do
      loose = described_class.new(expected_items: 500, false_positive_rate: 0.1)
      tight = described_class.new(expected_items: 500, false_positive_rate: 0.001)

      500.times do |i|
        loose.add("item-#{i}")
        tight.add("item-#{i}")
      end

      loose_fps = (500..999).count { |i| loose.include?("item-#{i}") }
      tight_fps = (500..999).count { |i| tight.include?("item-#{i}") }

      expect(tight_fps).to be <= loose_fps
    end
  end

  describe 'empty filter queries' do
    it 'returns false for any query on an empty filter' do
      filter = described_class.new(expected_items: 100)
      expect(filter.include?('anything')).to be false
      expect(filter.include?(42)).to be false
      expect(filter.include?(:symbol)).to be false
    end
  end

  describe 'duplicate adds' do
    it 'increments count for each add even if duplicate' do
      filter = described_class.new(expected_items: 100)
      filter.add('same')
      filter.add('same')
      filter.add('same')
      expect(filter.count).to eq(3)
    end

    it 'still reports include? as true after duplicate adds' do
      filter = described_class.new(expected_items: 100)
      filter.add('dup')
      filter.add('dup')
      expect(filter.include?('dup')).to be true
    end
  end

  describe '#add chaining' do
    it 'returns self for method chaining' do
      filter = described_class.new(expected_items: 100)
      result = filter.add('a')
      expect(result).to equal(filter)
    end

    it 'supports chained adds' do
      filter = described_class.new(expected_items: 100)
      filter.add('a').add('b').add('c')
      expect(filter.count).to eq(3)
      expect(filter.include?('a')).to be true
      expect(filter.include?('c')).to be true
    end
  end

  describe '#clear' do
    it 'makes previously added items not found' do
      filter = described_class.new(expected_items: 100)
      filter.add('hello')
      filter.add('world')
      filter.clear
      expect(filter.include?('hello')).to be false
      expect(filter.include?('world')).to be false
    end

    it 'returns self for chaining' do
      filter = described_class.new(expected_items: 100)
      expect(filter.clear).to equal(filter)
    end
  end

  describe '#memory_usage with different fp_rate configurations' do
    it 'uses more memory with lower false positive rate' do
      loose = described_class.new(expected_items: 1000, false_positive_rate: 0.1)
      tight = described_class.new(expected_items: 1000, false_positive_rate: 0.001)
      expect(tight.memory_usage).to be > loose.memory_usage
    end
  end

  describe '#merge' do
    it 'updates count after merge' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      a.add('x')
      b.add('y')
      b.add('z')
      a.merge(b)
      expect(a.count).to eq(3)
    end

    it 'returns self for chaining' do
      a = described_class.new(expected_items: 100, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 100, false_positive_rate: 0.01)
      expect(a.merge(b)).to equal(a)
    end
  end

  describe '#serialize and .deserialize edge cases' do
    it 'round-trips an empty filter' do
      filter = described_class.new(expected_items: 100)
      data = filter.serialize
      restored = described_class.deserialize(data)
      expect(restored.count).to eq(0)
      expect(restored.include?('anything')).to be false
    end

    it 'preserves memory_usage after round-trip' do
      filter = described_class.new(expected_items: 500, false_positive_rate: 0.01)
      10.times { |i| filter.add("item-#{i}") }
      data = filter.serialize
      restored = described_class.deserialize(data)
      expect(restored.memory_usage).to eq(filter.memory_usage)
    end
  end

  describe '#bulk_add' do
    it 'adds all items from an array' do
      filter = described_class.new(expected_items: 100)
      filter.bulk_add(%w[alpha beta gamma])
      expect(filter.include?('alpha')).to be true
      expect(filter.include?('beta')).to be true
      expect(filter.include?('gamma')).to be true
      expect(filter.count).to eq(3)
    end

    it 'returns self for chaining' do
      filter = described_class.new(expected_items: 100)
      expect(filter.bulk_add(%w[a b])).to equal(filter)
    end

    it 'works with ranges' do
      filter = described_class.new(expected_items: 100)
      filter.bulk_add(1..10)
      expect(filter.include?(5)).to be true
    end
  end

  describe '#bulk_include?' do
    it 'returns an array of booleans aligned with the input items' do
      filter = described_class.new(expected_items: 100)
      filter.bulk_add(%w[a b c])
      results = filter.bulk_include?(%w[a b c unseen])
      expect(results).to eq([true, true, true, false])
    end
  end

  describe '#count_estimate' do
    it 'returns zero for empty filter' do
      filter = described_class.new(expected_items: 1000)
      expect(filter.count_estimate).to eq(0.0)
    end

    it 'estimates cardinality within reasonable range' do
      filter = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      100.times { |i| filter.add("item-#{i}") }
      estimate = filter.count_estimate
      expect(estimate).to be_within(30).of(100)
    end
  end

  describe '#intersection' do
    it 'returns filter matching both' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      a.add('shared')
      a.add('only-a')
      b.add('shared')
      b.add('only-b')

      result = a.intersection(b)
      expect(result.include?('shared')).to be true
      expect(result.include?('only-a')).to be false
      expect(result.include?('only-b')).to be false
    end

    it 'raises on incompatible filters' do
      a = described_class.new(expected_items: 100, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 10_000, false_positive_rate: 0.01)
      expect { a.intersection(b) }.to raise_error(Philiprehberger::BloomFilter::Error)
    end

    it 'returns empty filter for non-overlapping sets' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.001)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.001)
      a.add('alpha')
      b.add('beta')
      result = a.intersection(b)
      expect(result.include?('alpha')).to be false
      expect(result.include?('beta')).to be false
    end
  end

  describe '#==' do
    it 'returns true for filters with identical state' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      a.add('hello')
      b.add('hello')
      expect(a).to eq(b)
    end

    it 'returns false for filters with different items' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      a.add('hello')
      b.add('world')
      expect(a).not_to eq(b)
    end

    it 'returns false for filters with different sizes' do
      a = described_class.new(expected_items: 100, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 10_000, false_positive_rate: 0.01)
      expect(a).not_to eq(b)
    end

    it 'returns false when compared with non-filter' do
      a = described_class.new(expected_items: 100)
      expect(a).not_to eq('not a filter')
    end
  end

  describe '#copy' do
    it 'returns an equal filter' do
      filter = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      filter.add('hello')
      clone = filter.copy
      expect(clone).to eq(filter)
      expect(clone.count).to eq(filter.count)
    end

    it 'returns an independent filter' do
      filter = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      filter.add('hello')
      clone = filter.copy
      clone.add('world')
      expect(clone.include?('world')).to be true
      expect(filter.include?('world')).to be false
      expect(clone.count).not_to eq(filter.count)
    end

    it 'is not the same object' do
      filter = described_class.new(expected_items: 100)
      expect(filter.copy).not_to equal(filter)
    end
  end

  describe '#false_positive_rate' do
    it 'returns zero for empty filter' do
      filter = described_class.new(expected_items: 1000)
      expect(filter.false_positive_rate).to eq(0.0)
    end

    it 'returns a rate between 0 and 1 for non-empty filter' do
      filter = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      100.times { |i| filter.add("item-#{i}") }
      rate = filter.false_positive_rate
      expect(rate).to be > 0.0
      expect(rate).to be < 1.0
    end

    it 'increases as more items are added' do
      filter = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      10.times { |i| filter.add("item-#{i}") }
      rate_low = filter.false_positive_rate
      500.times { |i| filter.add("extra-#{i}") }
      rate_high = filter.false_positive_rate
      expect(rate_high).to be > rate_low
    end
  end

  describe '#to_json / .from_json' do
    it 'round-trips correctly' do
      filter = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      filter.add('hello')
      filter.add('world')
      json = filter.to_json
      restored = described_class.from_json(json)
      expect(restored.include?('hello')).to be true
      expect(restored.include?('world')).to be true
      expect(restored.count).to eq(2)
    end

    it 'produces valid JSON string' do
      filter = described_class.new(expected_items: 100)
      json = filter.to_json
      expect { JSON.parse(json) }.not_to raise_error
    end

    it 'round-trips an empty filter' do
      filter = described_class.new(expected_items: 100)
      restored = described_class.from_json(filter.to_json)
      expect(restored.count).to eq(0)
      expect(restored.include?('anything')).to be false
    end
  end

  describe '#superset?' do
    it 'returns true when self contains all bits of other' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      a.add('alpha')
      a.add('beta')
      b.add('alpha')
      expect(a.superset?(b)).to be true
    end

    it 'returns false when other has bits not in self' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      a.add('alpha')
      b.add('alpha')
      b.add('beta')
      expect(a.superset?(b)).to be false
    end

    it 'returns true for two empty filters' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      expect(a.superset?(b)).to be true
    end

    it 'raises on incompatible filters' do
      a = described_class.new(expected_items: 100, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 10_000, false_positive_rate: 0.01)
      expect { a.superset?(b) }.to raise_error(Philiprehberger::BloomFilter::Error)
    end
  end

  describe '#empty?' do
    it 'returns true for a new filter' do
      filter = described_class.new(expected_items: 100)
      expect(filter.empty?).to be true
    end

    it 'returns false after adding an item' do
      filter = described_class.new(expected_items: 100)
      filter.add('hello')
      expect(filter.empty?).to be false
    end

    it 'returns true after clearing' do
      filter = described_class.new(expected_items: 100)
      filter.add('hello')
      filter.clear
      expect(filter.empty?).to be true
    end
  end

  describe '#fill_rate' do
    it 'returns zero for empty filter' do
      filter = described_class.new(expected_items: 100)
      expect(filter.fill_rate).to eq(0.0)
    end

    it 'increases as items are added' do
      filter = described_class.new(expected_items: 100)
      rate1 = filter.fill_rate
      filter.add('item')
      rate2 = filter.fill_rate
      expect(rate2).to be > rate1
    end

    it 'stays between 0 and 1' do
      filter = described_class.new(expected_items: 100)
      50.times { |i| filter.add("item-#{i}") }
      expect(filter.fill_rate).to be_between(0.0, 1.0)
    end
  end

  describe '#union' do
    it 'returns a new filter containing items from both' do
      a = described_class.new(expected_items: 1000)
      b = described_class.new(expected_items: 1000)
      a.add('alpha')
      b.add('beta')
      result = a.union(b)
      expect(result.include?('alpha')).to be(true)
      expect(result.include?('beta')).to be(true)
    end

    it 'does not mutate the receiver' do
      a = described_class.new(expected_items: 1000)
      b = described_class.new(expected_items: 1000)
      b.add('beta')
      a.union(b)
      expect(a.include?('beta')).to be(false)
    end

    it 'raises on incompatible bit sizes' do
      a = described_class.new(expected_items: 100)
      b = described_class.new(expected_items: 100_000)
      expect { a.union(b) }.to raise_error(Philiprehberger::BloomFilter::Error)
    end
  end

  describe '#compatible?' do
    it 'returns true for filters with same parameters' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      expect(a.compatible?(b)).to be(true)
    end

    it 'returns false for filters with different parameters' do
      a = described_class.new(expected_items: 100)
      b = described_class.new(expected_items: 100_000)
      expect(a.compatible?(b)).to be(false)
    end

    it 'returns false for non-filter values' do
      a = described_class.new(expected_items: 100)
      expect(a.compatible?('not a filter')).to be(false)
    end
  end

  describe '#saturated?' do
    it 'returns false for an empty filter' do
      filter = described_class.new(expected_items: 1000)
      expect(filter.saturated?).to be(false)
    end

    it 'returns true once fill rate reaches threshold' do
      filter = described_class.new(expected_items: 100)
      200.times { |i| filter.add("item-#{i}") }
      expect(filter.saturated?(threshold: 0.1)).to be(true)
    end

    it 'accepts a custom threshold' do
      filter = described_class.new(expected_items: 1000)
      filter.add('one')
      expect(filter.saturated?(threshold: 0.99)).to be(false)
    end
  end

  describe '#hash' do
    it 'is consistent with #== for equal filters' do
      a = described_class.new(expected_items: 1000)
      b = described_class.new(expected_items: 1000)
      a.add('hello')
      b.add('hello')
      expect(a == b).to be(true)
      expect(a.hash).to eq(b.hash)
    end

    it 'allows filters to be used as Hash keys' do
      a = described_class.new(expected_items: 1000)
      b = described_class.new(expected_items: 1000)
      a.add('x')
      b.add('x')
      h = { a => :value }
      expect(h[b]).to eq(:value)
    end
  end

  describe '#subset?' do
    it 'returns true when self is a subset of other' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b.add('alpha')
      b.add('beta')
      a.add('alpha')
      expect(a.subset?(b)).to be true
    end

    it 'returns false when self has bits not in other' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      a.add('alpha')
      a.add('beta')
      b.add('alpha')
      expect(a.subset?(b)).to be false
    end

    it 'returns true for two empty filters' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      expect(a.subset?(b)).to be true
    end

    it 'raises on incompatible filters' do
      a = described_class.new(expected_items: 100, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 10_000, false_positive_rate: 0.01)
      expect { a.subset?(b) }.to raise_error(Philiprehberger::BloomFilter::Error)
    end
  end

  describe '#| (union operator)' do
    it 'returns a new filter containing items from both' do
      a = described_class.new(expected_items: 1000)
      b = described_class.new(expected_items: 1000)
      a.add('alpha')
      b.add('beta')
      result = a | b
      expect(result.include?('alpha')).to be true
      expect(result.include?('beta')).to be true
    end

    it 'does not mutate the receiver' do
      a = described_class.new(expected_items: 1000)
      b = described_class.new(expected_items: 1000)
      b.add('beta')
      a | b
      expect(a.include?('beta')).to be false
    end
  end

  describe '#& (intersection operator)' do
    it 'returns filter matching both' do
      a = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      b = described_class.new(expected_items: 1000, false_positive_rate: 0.01)
      a.add('shared')
      a.add('only-a')
      b.add('shared')
      b.add('only-b')
      result = a & b
      expect(result.include?('shared')).to be true
      expect(result.include?('only-a')).to be false
    end
  end

  describe '#inspect' do
    it 'returns a readable representation including key fields' do
      filter = described_class.new(expected_items: 1000)
      filter.add('hello')
      str = filter.inspect
      expect(str).to include('Philiprehberger::BloomFilter::Filter')
      expect(str).to include('count=1')
      expect(str).to include('bit_size=')
      expect(str).to include('hash_count=')
      expect(str).to include('fill_rate=')
    end
  end
end
