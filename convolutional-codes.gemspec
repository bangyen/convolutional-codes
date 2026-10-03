# frozen_string_literal: true

require_relative 'lib/convolutional'

Gem::Specification.new do |spec|
  spec.name = 'convolutional-codes'
  spec.version = Conv::VERSION
  spec.authors = ['Bang Yen']
  spec.summary = 'An educational binary convolutional encoder and Viterbi decoder'
  spec.description = 'A dependency-free Ruby library with inspectable trellis transitions and hard-decision decoding.'
  spec.homepage = 'https://github.com/bangyen/convolutional-codes'
  spec.license = 'GPL-3.0-only'
  spec.required_ruby_version = '>= 3.1'
  spec.files = Dir['lib/**/*.rb', 'src/**/*.rb', 'examples/**/*.rb'] + %w[README.md LICENSE]
  spec.require_paths = ['lib']
end
