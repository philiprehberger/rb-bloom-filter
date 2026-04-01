# frozen_string_literal: true

require_relative 'lib/philiprehberger/bloom_filter/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-bloom_filter'
  spec.version = Philiprehberger::BloomFilter::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']

  spec.summary = 'Space-efficient probabilistic set with configurable false positive rate'
  spec.description = 'Bloom filter implementation using a bit array with double hashing. ' \
                       'Supports configurable expected items and false positive rate, merge, ' \
                       'serialization, and memory usage reporting.'
  spec.homepage = 'https://philiprehberger.com/open-source-packages/ruby/philiprehberger-bloom_filter'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/philiprehberger/rb-bloom-filter'
  spec.metadata['changelog_uri'] = 'https://github.com/philiprehberger/rb-bloom-filter/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/philiprehberger/rb-bloom-filter/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
