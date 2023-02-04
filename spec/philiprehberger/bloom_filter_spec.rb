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
end
