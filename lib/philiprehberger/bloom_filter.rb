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
  end
end
