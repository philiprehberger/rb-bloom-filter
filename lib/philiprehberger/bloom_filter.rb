# frozen_string_literal: true

require_relative 'bloom_filter/version'
require_relative 'bloom_filter/filter'

module Philiprehberger
  module BloomFilter
    class Error < StandardError; end

    # Create a new Bloom filter.
    #
    # @param expected_items [Integer] expected number of items
    # @param false_positive_rate [Float] desired false positive rate (0.0 to 1.0)
    # @return [Filter] a new bloom filter instance
    def self.new(expected_items:, false_positive_rate: 0.01)
      Filter.new(expected_items: expected_items, false_positive_rate: false_positive_rate)
    end

    # Deserialize a bloom filter from a hash.
    #
    # @param data [Hash] serialized bloom filter data
    # @return [Filter] a restored bloom filter instance
    def self.deserialize(data)
      Filter.deserialize(data)
    end

    # Deserialize a bloom filter from a JSON string.
    #
    # @param str [String] JSON string
    # @return [Filter] a restored bloom filter instance
    def self.from_json(str)
      Filter.from_json(str)
    end

    # Compute the optimal bit-array size for a target false positive rate.
    #
    # Uses the formula: m = -(n * ln(p)) / (ln(2)^2)
    # where n = expected_items and p = false_positive_rate.
    #
    # @param expected_items [Integer] expected number of items (must be positive)
    # @param false_positive_rate [Float] desired false positive rate in (0.0, 1.0) exclusive
    # @return [Integer] optimal number of bits
    # @raise [ArgumentError] if expected_items is not a positive Integer
    # @raise [ArgumentError] if false_positive_rate is not within (0.0, 1.0) exclusive
    def self.optimal_size(expected_items:, false_positive_rate: 0.01)
      unless expected_items.is_a?(Integer) && expected_items.positive?
        raise ArgumentError, 'expected_items must be a positive Integer'
      end
      unless false_positive_rate.is_a?(Numeric) && false_positive_rate > 0.0 && false_positive_rate < 1.0
        raise ArgumentError, 'false_positive_rate must be between 0 and 1 (exclusive)'
      end

      (-(expected_items * Math.log(false_positive_rate)) / (Math.log(2)**2)).ceil
    end

    # Compute the optimal number of hash functions for a given bit-array size.
    #
    # Uses the formula: k = (m / n) * ln(2)
    # where m = size and n = expected_items. Returns at least 1.
    #
    # @param size [Integer] size of the bit array in bits (must be positive)
    # @param expected_items [Integer] expected number of items (must be positive)
    # @return [Integer] optimal hash function count (minimum 1)
    # @raise [ArgumentError] if size is not a positive Integer
    # @raise [ArgumentError] if expected_items is not a positive Integer
    def self.optimal_hash_count(size:, expected_items:)
      raise ArgumentError, 'size must be a positive Integer' unless size.is_a?(Integer) && size.positive?
      unless expected_items.is_a?(Integer) && expected_items.positive?
        raise ArgumentError, 'expected_items must be a positive Integer'
      end

      [(size.to_f / expected_items * Math.log(2)).ceil, 1].max
    end
  end
end
