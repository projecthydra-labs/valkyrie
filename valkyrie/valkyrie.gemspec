# coding: utf-8
# frozen_string_literal: true
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'valkyrie/version'

Gem::Specification.new do |spec|
  spec.name          = "valkyrie"
  spec.version       = Valkyrie::VERSION
  spec.authors       = ["Trey Pendragon"]
  spec.email         = ["tpendragon@princeton.edu"]

  spec.summary       = 'An ORM using the Data Mapper pattern, specifically built to solve Digital Repository use cases.'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'dry-struct'
  spec.add_dependency 'draper'
  spec.add_dependency 'activemodel'
  spec.add_dependency 'dry-types'
  spec.add_dependency 'rdf'
  spec.add_dependency 'active-fedora'
  spec.add_dependency 'activesupport'
  spec.add_dependency 'activerecord'
  spec.add_dependency 'reform'
  spec.add_dependency 'reform-rails'
  spec.add_dependency 'pg'
  spec.add_dependency 'json-ld'
  spec.add_dependency 'json'
  spec.add_dependency 'active-triples'
  spec.add_dependency 'hydra-access-controls'
  spec.add_dependency 'hydra-derivatives'
  spec.add_dependency 'ruby_tika_app'
  spec.add_dependency 'redis'

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "database_cleaner"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "bixby"
  spec.add_development_dependency 'rubocop', '~> 0.48.0'
  spec.add_development_dependency 'rubocop-rails'
  spec.add_development_dependency 'yard'
end
