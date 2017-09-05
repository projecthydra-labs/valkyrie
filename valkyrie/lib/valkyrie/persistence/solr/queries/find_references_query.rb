# frozen_string_literal: true
module Valkyrie::Persistence::Solr::Queries
  class FindReferencesQuery
    attr_reader :resource, :property, :connection, :resource_factory
    def initialize(resource:, property:, connection:, resource_factory:)
      @resource = resource
      @property = property
      @connection = connection
      @resource_factory = resource_factory
    end

    def run
      enum_for(:each)
    end

    def each
      docs = DefaultPaginator.new
      while docs.has_next?
        docs = connection.paginate(docs.next_page, docs.per_page, "select", params: { q: query })["response"]["docs"]
        docs.each do |doc|
          yield resource_factory.to_resource(object: doc)
        end
      end
    end

    def query
      "{!join from=#{property}_ssim to=id}id:#{id}"
    end

    def id
      "id-#{resource.id}"
    end
  end
end
