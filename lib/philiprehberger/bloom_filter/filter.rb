# frozen_string_literal: true

module Philiprehberger
  module BloomFilter
    # A space-efficient probabilistic set membership data structure.
    class Filter
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
        @bit_size = optimal_bit_size(expected_items, false_positive_rate)
        @hash_count = optimal_hash_count(@bit_size, expected_items)
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

      def optimal_bit_size(n, p)
        (-(n * Math.log(p)) / (Math.log(2)**2)).ceil
      end

      def optimal_hash_count(m, n)
        [(m.to_f / n * Math.log(2)).ceil, 1].max
      end

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

      def get_bit(index)
        byte_index = index / 8
        bit_offset = index % 8
        @bits.getbyte(byte_index).anybits?(1 << bit_offset)
      end
    end
  end
end
