# frozen_string_literal: true
module Valkyrie::Persistence::Fedora
  # Query Service for Fedora MetadataAdapter
  class QueryService
    attr_reader :adapter
    delegate :connection, :resource_factory, to: :adapter

    # @note (see Valkyrie::Persistence::Memory::QueryService#initialize)
    def initialize(adapter:)
      @adapter = adapter
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_by)
    def find_by(id:)
      validate_id(id)
      uri = adapter.id_to_uri(id)

      resource_from_uri(uri)
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_by_alternate_identifier)
    def find_by_alternate_identifier(alternate_identifier:)
      validate_id(alternate_identifier)
      uri = adapter.id_to_uri(alternate_identifier)
      alternate_id = resource_from_uri(uri).references

      find_by(id: alternate_id)
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_many_by_ids)
    def find_many_by_ids(ids:)
      ids = ids.uniq if adapter.standardize_query_result?
      ids.map do |id|
        begin
          find_by(id: id)
        rescue ::Valkyrie::Persistence::ObjectNotFoundError
          nil
        end
      end.reject(&:nil?)
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_parents)
    def find_parents(resource:)
      content = content_with_inbound(id: resource.id)
      parent_ids = content.graph.query([nil, RDF::Vocab::ORE.proxyFor, nil]).map(&:subject).map { |x| x.to_s.gsub(/#.*/, '') }.map { |x| adapter.uri_to_id(x) }
      parent_ids.uniq! if adapter.standardize_query_result?
      parent_ids.lazy.map do |id|
        find_by(id: id)
      end
    end

    # Specify the URIs used in triples directly related to the requested resource
    # @see https://wiki.duraspace.org/display/FEDORA4x/RESTful+HTTP+API#RESTfulHTTPAPI-GETRetrievethecontentoftheresource
    # @return [Array<RDF::URI>]
    def include_uris
      [
        adapter.fedora_version == 5 ? "http://fedora.info/definitions/fcrepo#PreferInboundReferences" : ::RDF::Vocab::Fcrepo4.InboundReferences
      ]
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_members)
    def find_members(resource:, model: nil)
      return [] unless resource.respond_to? :member_ids
      result = Array(resource.member_ids).lazy.map do |id|
        find_by(id: id)
      end.select(&:present?)
      return result unless model
      result.select { |obj| obj.is_a?(model) }
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_all)
    def find_all
      resource = Ldp::Resource.for(connection, adapter.base_path, connection.get(adapter.base_path))
      ids = resource.graph.query([nil, RDF::Vocab::LDP.contains, nil]).map(&:object).map { |x| adapter.uri_to_id(x) }
      ids.lazy.map do |id|
        find_by(id: id)
      end
    rescue ::Ldp::NotFound
      []
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_all_of_model)
    def find_all_of_model(model:)
      find_all.select do |m|
        m.is_a?(model)
      end
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_references_by)
    def find_references_by(resource:, property:)
      (resource[property] || []).select { |x| x.is_a?(Valkyrie::ID) }.lazy.map do |id|
        find_by(id: id)
      end
    end

    # Retrieves the RDF graph for the LDP container for a resource
    # This includes inbound links
    # @see https://wiki.duraspace.org/display/FEDORA4x/RESTful+HTTP+API#RESTfulHTTPAPI-GETRetrievethecontentoftheresource
    # @param id [Valkyrie::ID]
    # @return [Faraday::Response]
    def content_with_inbound(id:)
      uri = adapter.id_to_uri(id)
      connection.get(uri) do |req|
        prefer_headers = Ldp::PreferHeaders.new(req.headers["Prefer"])
        prefer_headers.include = prefer_headers.include | include_uris
        req.headers["Prefer"] = prefer_headers.to_s
      end
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_inverse_references_by)
    # Find all resources referencing a given resource (e. g. parents)
    # *This is done by iterating through the ID of each resource referencing the resource in the query, and requesting each resource over the HTTP*
    # *Also, an initial request is made to find the URIs of the resources referencing the resource in the query*
    def find_inverse_references_by(resource:, property:)
      ensure_persisted(resource)
      if ordered_property?(resource: resource, property: property)
        find_inverse_references_by_ordered(resource: resource, property: property)
      else
        find_inverse_references_by_unordered(resource: resource, property: property)
      end
    end

    # (see Valkyrie::Persistence::Memory::QueryService#custom_queries)
    def custom_queries
      @custom_queries ||= ::Valkyrie::Persistence::CustomQueryContainer.new(query_service: self)
    end

    private

      def find_inverse_references_by_unordered(resource:, property:)
        content = content_with_inbound(id: resource.id)
        property_uri = adapter.schema.predicate_for(property: property, resource: nil)
        ids = content.graph.query([nil, property_uri, adapter.id_to_uri(resource.id)]).map(&:subject).map { |x| x.to_s.gsub(/#.*/, '') }.map { |x| adapter.uri_to_id(x) }
        ids.uniq! if adapter.standardize_query_result?
        ids.lazy.map { |id| find_by(id: id) }
      end

      def find_inverse_references_by_ordered(resource:, property:)
        content = content_with_inbound(id: resource.id)
        ids = content.graph.query([nil, ::RDF::Vocab::ORE.proxyFor, adapter.id_to_uri(resource.id)]).map(&:subject).map { |x| x.to_s.gsub(/#.*/, '') }.map { |x| adapter.uri_to_id(x) }
        ids.uniq! if adapter.standardize_query_result?
        ids.lazy.map { |id| find_by(id: id) }.select { |o| o[property].include?(resource.id) }
      end

      # Ensures that an object is (or can be cast into a) Valkyrie::ID
      # @return [Valkyrie::ID]
      # @raise [ArgumentError]
      def validate_id(id)
        id = Valkyrie::ID.new(id.to_s) if id.is_a?(String)
        raise ArgumentError, 'id must be a Valkyrie::ID' unless id.is_a? Valkyrie::ID
      end

      # Resolve a URI for an LDP resource in Fedora and construct a Valkyrie::Resource
      # @param uri [RDF::URI]
      # @return [Valkyrie::Resource]
      # @raise [Valkyrie::Persistence::ObjectNotFoundError]
      def resource_from_uri(uri)
        resource = Ldp::Resource.for(connection, uri, connection.get(uri))
        resource_factory.to_resource(object: resource)
      rescue ::Ldp::Gone, ::Ldp::NotFound
        raise ::Valkyrie::Persistence::ObjectNotFoundError
      end

      # Ensures that a Valkyrie::Resource has been persisted
      # @param resource [Valkyrie::Resource]
      # @raise [ArgumentError]
      def ensure_persisted(resource)
        raise ArgumentError, 'resource is not saved' unless resource.persisted?
      end

      def ordered_property?(resource:, property:)
        resource.class.schema[property].meta.try(:[], :ordered)
      end
  end
end
