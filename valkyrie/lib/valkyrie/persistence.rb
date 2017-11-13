# frozen_string_literal: true
module Valkyrie
  module Persistence
    require 'valkyrie/persistence/custom_query_container'
    require 'valkyrie/persistence/memory'
    require 'valkyrie/persistence/postgres'
    require 'valkyrie/persistence/solr'
    require 'valkyrie/persistence/fedora'
    require 'valkyrie/persistence/composite_persister'
    require 'valkyrie/persistence/delete_tracking_buffer'
    require 'valkyrie/persistence/buffered_persister'
    require 'valkyrie/persistence/redis'
    require 'valkyrie/persistence/write_cached'
    class ObjectNotFoundError < StandardError
    end
  end
end
