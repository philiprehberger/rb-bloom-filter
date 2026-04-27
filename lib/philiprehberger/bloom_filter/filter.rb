# frozen_string_literal: true

require 'json'

module Philiprehberger
  module BloomFilter
    # A space-efficient probabilistic set membership data structure.
    class Filter
      POPCOUNT = (0..255).map { |b| b.digits(2).sum }.freeze
      private_constant :POPCOUNT

      attr_reader :count

      # @param expected_items [Integer] expected number of items
      # @param false_positive_rate [Float] desired false positive rate
      def initialize(expected_items:, false_positive_rate: 0.01)
        raise Error, 'expected_items must be positive' unless expected_items.is_a?(Integer) && expected_items.positive?
        unless false_positive_rate.positive? && false_positive_rate < 1
          raise Error,
                'false_positive_rate must be between 0 and 1'
        end

        @expected_items = expected_items
        @false_positive_rate = false_positive_rate
        @bit_size = BloomFilter.optimal_size(
          expected_items: expected_items,
          false_positive_rate: false_positive_rate
        )
        @hash_count = BloomFilter.optimal_hash_count(
          size: @bit_size,
          expected_items: expected_items
        )
        @bits = "\0".b * ((@bit_size + 7) / 8)
        @count = 0
      end

      # Add an item to the filter.
      #
      # @param item [Object] the item to add (uses #to_s for hashing)
      # @return [self]
      def add(item)
        hash_indices(item.to_s).each { |i| set_bit(i) }
        @count += 1
        self
      end

      # Check if an item might be in the filter.
      #
      # @param item [Object] the item to check
      # @return [Boolean] true if the item might be present, false if definitely absent
      def include?(item)
        hash_indices(item.to_s).all? { |i| get_bit(i) }
      end

      # Merge another bloom filter into this one.
      #
      # @param other [Filter] another bloom filter with the same parameters
      # @return [self]
      # @raise [Error] if the filters have different bit sizes
      def merge(other)
        unless @bit_size == other.instance_variable_get(:@bit_size)
          raise Error,
                'cannot merge filters with different bit sizes'
        end

        other_bits = other.instance_variable_get(:@bits)
        @bits.bytesize.times do |i|
          @bits.setbyte(i, @bits.getbyte(i) | other_bits.getbyte(i))
        end
        @count += other.count
        self
      end

      # Reset the filter, removing all items.
      #
      # @return [self]
      def clear
        @bits = "\0".b * ((@bit_size + 7) / 8)
        @count = 0
        self
      end

      # Return the memory usage of the bit array in bytes.
      #
      # @return [Integer] memory usage in bytes
      def memory_usage
        @bits.bytesize
      end

      # Add all items from an enumerable
      #
      # @param items [Enumerable] items to add
      # @return [self]
      def bulk_add(items)
        items.each { |item| add(item) }
        self
      end

      # Check membership for many items at once.
      #
      # @param items [Enumerable] items to test
      # @return [Array<Boolean>] one boolean per input item, in order
      def bulk_include?(items)
        items.map { |item| include?(item) }
      end

      # Estimate the number of unique items using the fill rate
      #
      # @return [Float] estimated cardinality
      def count_estimate
        bits_set = count_set_bits
        return 0.0 if bits_set.zero?

        -(@bit_size.to_f / @hash_count) * Math.log(1.0 - (bits_set.to_f / @bit_size))
      end

      # Create a new filter containing only elements present in both filters (AND)
      #
      # @param other [Filter] another bloom filter with the same parameters
      # @return [Filter] new intersection filter
      # @raise [Error] if the filters have different bit sizes
      def intersection(other)
        unless @bit_size == other.instance_variable_get(:@bit_size)
          raise Error,
                'cannot intersect filters with different bit sizes'
        end

        result = self.class.new(expected_items: @expected_items, false_positive_rate: @false_positive_rate)
        other_bits = other.instance_variable_get(:@bits)
        result_bits = result.instance_variable_get(:@bits)

        @bits.bytesize.times do |i|
          result_bits.setbyte(i, @bits.getbyte(i) & other_bits.getbyte(i))
        end

        result
      end

      # Return the proportion of set bits in the bit array
      #
      # @return [Float] fill rate between 0.0 and 1.0
      def fill_rate
        count_set_bits.to_f / @bit_size
      end

      # Check structural equality with another filter.
      #
      # @param other [Filter] another bloom filter
      # @return [Boolean] true if both filters have the same structure and bit array
      def ==(other)
        return false unless other.is_a?(self.class)

        @bit_size == other.instance_variable_get(:@bit_size) &&
          @hash_count == other.instance_variable_get(:@hash_count) &&
          @bits == other.instance_variable_get(:@bits)
      end

      # Create an independent deep copy of this filter.
      #
      # @return [Filter] a new filter with the same state
      def copy
        result = self.class.allocate
        result.instance_variable_set(:@expected_items, @expected_items)
        result.instance_variable_set(:@false_positive_rate, @false_positive_rate)
        result.instance_variable_set(:@bit_size, @bit_size)
        result.instance_variable_set(:@hash_count, @hash_count)
        result.instance_variable_set(:@bits, @bits.dup)
        result.instance_variable_set(:@count, @count)
        result
      end

      # Calculate the actual false positive rate based on current fill rate.
      #
      # Uses the formula: (1 - e^(-k*n/m))^k
      # where k = hash_count, n = count, m = bit_size.
      #
      # @return [Float] estimated false positive rate
      def false_positive_rate
        return 0.0 if @count.zero?

        (1.0 - Math.exp(-@hash_count.to_f * @count / @bit_size))**@hash_count
      end

      # Serialize the filter to a JSON string.
      #
      # @return [String] JSON representation
      def to_json(*_args)
        JSON.generate(serialize)
      end

      # Deserialize a filter from a JSON string.
      #
      # @param str [String] JSON string
      # @return [Filter]
      def self.from_json(str)
        deserialize(JSON.parse(str))
      end

      # Check if this filter is a superset of another.
      #
      # Returns true if every set bit in `other` is also set in `self`.
      #
      # @param other [Filter] another bloom filter with the same parameters
      # @return [Boolean]
      # @raise [Error] if the filters have different bit sizes
      def superset?(other)
        unless @bit_size == other.instance_variable_get(:@bit_size)
          raise Error,
                'cannot compare filters with different bit sizes'
        end

        other_bits = other.instance_variable_get(:@bits)
        @bits.bytesize.times do |i|
          ob = other_bits.getbyte(i)
          return false unless @bits.getbyte(i) & ob == ob
        end
        true
      end

      # Check if the filter is empty (no items added).
      #
      # @return [Boolean] true if count is zero
      def empty?
        @count.zero?
      end

      # Create a new filter containing all items present in either filter (OR).
      #
      # Non-mutating counterpart to {#merge}.
      #
      # @param other [Filter] another bloom filter with the same parameters
      # @return [Filter] new union filter
      # @raise [Error] if the filters have different bit sizes
      def union(other)
        unless @bit_size == other.instance_variable_get(:@bit_size)
          raise Error,
                'cannot union filters with different bit sizes'
        end

        result = self.class.new(expected_items: @expected_items, false_positive_rate: @false_positive_rate)
        other_bits = other.instance_variable_get(:@bits)
        result_bits = result.instance_variable_get(:@bits)

        @bits.bytesize.times do |i|
          result_bits.setbyte(i, @bits.getbyte(i) | other_bits.getbyte(i))
        end
        result.instance_variable_set(:@count, @count + other.count)
        result
      end

      # Check whether another filter has compatible structure for merge,
      # intersection, union, and superset operations.
      #
      # @param other [Object] candidate filter
      # @return [Boolean]
      def compatible?(other)
        other.is_a?(self.class) &&
          @bit_size == other.instance_variable_get(:@bit_size) &&
          @hash_count == other.instance_variable_get(:@hash_count)
      end

      # Check if this filter is a subset of another.
      #
      # Returns true if every set bit in `self` is also set in `other`.
      #
      # @param other [Filter] another bloom filter with the same parameters
      # @return [Boolean]
      # @raise [Error] if the filters have different bit sizes
      def subset?(other)
        other.superset?(self)
      end

      # @return [Filter] alias for {#union}
      alias | union

      # @return [Filter] alias for {#intersection}
      alias & intersection

      # Check whether the filter has reached or exceeded a fill threshold.
      #
      # @param threshold [Float] fill rate threshold between 0.0 and 1.0
      # @return [Boolean]
      def saturated?(threshold: 0.5)
        fill_rate >= threshold
      end

      # Hash code consistent with {#==}, allowing filters to be used as
      # Hash keys or Set members.
      #
      # @return [Integer]
      def hash
        [self.class, @bit_size, @hash_count, @bits].hash
      end

      # @see #==
      alias eql? ==

      # Human-readable representation for debugging.
      #
      # @return [String]
      def inspect
        format(
          '#<%<class>s count=%<count>d bit_size=%<bit_size>d hash_count=%<hash_count>d fill_rate=%<fill>.4f>',
          class: self.class.name, count: @count, bit_size: @bit_size,
          hash_count: @hash_count, fill: fill_rate
        )
      end

      # Serialize the filter to a hash.
      #
      # @return [Hash] serialized representation
      def serialize
        {
          'expected_items' => @expected_items,
          'false_positive_rate' => @false_positive_rate,
          'bit_size' => @bit_size,
          'hash_count' => @hash_count,
          'bits' => @bits.unpack1('H*'),
          'count' => @count
        }
      end

      # Deserialize a filter from a hash.
      #
      # @param data [Hash] serialized filter data
      # @return [Filter]
      def self.deserialize(data)
        filter = allocate
        filter.instance_variable_set(:@expected_items, data['expected_items'])
        filter.instance_variable_set(:@false_positive_rate, data['false_positive_rate'])
        filter.instance_variable_set(:@bit_size, data['bit_size'])
        filter.instance_variable_set(:@hash_count, data['hash_count'])
        filter.instance_variable_set(:@bits, [data['bits']].pack('H*'))
        filter.instance_variable_set(:@count, data['count'])
        filter
      end

      private

      def hash_indices(key)
        h1 = murmur_hash(key, 0)
        h2 = murmur_hash(key, h1)
        Array.new(@hash_count) { |i| (h1 + (i * h2)) % @bit_size }
      end

      def murmur_hash(key, seed)
        h = seed & 0xFFFFFFFF
        key.each_byte do |byte|
          h ^= byte
          h = (h * 0x5bd1e995) & 0xFFFFFFFF
          h ^= h >> 15
        end
        h
      end

      def set_bit(index)
        byte_index = index / 8
        bit_offset = index % 8
        @bits.setbyte(byte_index, @bits.getbyte(byte_index) | (1 << bit_offset))
      end

      def count_set_bits
        total = 0
        @bits.each_byte { |byte| total += POPCOUNT[byte] }
        total
      end

      def get_bit(index)
        byte_index = index / 8
        bit_offset = index % 8
        @bits.getbyte(byte_index).anybits?(1 << bit_offset)
      end
    end
  end
end
