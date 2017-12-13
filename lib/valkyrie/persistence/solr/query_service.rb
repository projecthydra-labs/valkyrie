# frozen_string_literal: true
module Valkyrie::Persistence::Solr
  require 'valkyrie/persistence/solr/queries'
  class QueryService
    attr_reader :connection, :resource_factory
    # @param connection [RSolr::Client]
    # @param resource_factory [Valkyrie::Persistence::Solr::ResourceFactory]
    def initialize(connection:, resource_factory:, query_runner: default_query_runner)
      @connection = connection
      @resource_factory = resource_factory
      @query_runner = query_runner
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_by)
    def find_by(id:)
      validate_id(id)
      query_runner::FindByIdQuery.new(id, connection: connection, resource_factory: resource_factory).run
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_all)
    def find_all
      query_runner::FindAllQuery.new(connection: connection, resource_factory: resource_factory).run
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_all_of_model)
    def find_all_of_model(model:)
      query_runner::FindAllQuery.new(connection: connection, resource_factory: resource_factory, model: model).run
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_parents)
    def find_parents(resource:)
      find_inverse_references_by(resource: resource, property: :member_ids)
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_members)
    def find_members(resource:, model: nil)
      query_runner::FindMembersQuery.new(resource: resource, model: model, connection: connection, resource_factory: resource_factory).run
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_references_by)
    def find_references_by(resource:, property:)
      query_runner::FindReferencesQuery.new(resource: resource, property: property, connection: connection, resource_factory: resource_factory).run
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_inverse_references_by)
    def find_inverse_references_by(resource:, property:)
      query_runner::FindInverseReferencesQuery.new(resource: resource, property: property, connection: connection, resource_factory: resource_factory).run
    end

    def custom_queries
      @custom_queries ||= ::Valkyrie::Persistence::CustomQueryContainer.new(query_service: self)
    end

    private

      attr_reader :query_runner

      def default_query_runner
        Valkyrie::Persistence::Solr::Queries
      end

      def validate_id(id)
        raise ArgumentError, 'id must be a Valkyrie::ID' unless id.is_a? Valkyrie::ID
      end
  end
end
