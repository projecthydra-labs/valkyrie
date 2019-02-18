# frozen_string_literal: true
begin
  gem 'pg'
rescue Gem::LoadError => e
  raise Gem::LoadError,
        "You are using the Postgres adapter without installing the #{e.name} gem.  "\
        "Add `gem '#{e.name}'` to your Gemfile."
end
module Valkyrie::Persistence
  # Implements the DataMapper Pattern to store metadata into Postgres
  module Postgres
    # Deprecation to allow us to make pg an optional dependency
    path = Bundler.definition.gemfiles.first
    matches = File.readlines(path).select { |l| l =~ /gem ['"]pg\b/ }
    if matches.empty?
      warn "[DEPRECATION] pg will not be included as a dependency in Valkyrie's gemspec as of the next major release. Please add the gem directly to your Gemfile if you use a postgres adapter."
    end

    require 'valkyrie/persistence/postgres/metadata_adapter'
  end
end
