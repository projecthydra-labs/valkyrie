# frozen_string_literal: true
module Valkyrie::Persistence::Postgres
  class QueryService
    attr_reader :adapter
    delegate :resource_factory, to: :adapter
    delegate :orm_class, to: :resource_factory
    def initialize(adapter:)
      @adapter = adapter
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_all)
    def find_all
      orm_class.all.lazy.map do |orm_object|
        resource_factory.to_resource(object: orm_object)
      end
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_all_of_model)
    def find_all_of_model(model:)
      orm_class.where(internal_resource: model.to_s).lazy.map do |orm_object|
        resource_factory.to_resource(object: orm_object)
      end
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_by)
    def find_by(id:)
      resource_factory.to_resource(object: orm_class.find(id))
    rescue ActiveRecord::RecordNotFound
      raise Valkyrie::Persistence::ObjectNotFoundError
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_all_by_checksum)
    def find_all_by_checksum(checksum:)
      # TODO write the query
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_members)
    def find_members(resource:, model: nil)
      return [] if resource.id.blank?
      if model
        run_query(find_members_with_type_query, resource.id.to_s, model.to_s)
      else
        run_query(find_members_query, resource.id.to_s)
      end
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_parents)
    def find_parents(resource:)
      find_inverse_references_by(resource: resource, property: :member_ids)
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_references_by)
    def find_references_by(resource:, property:)
      return [] if resource.id.blank? || resource[property].blank?
      run_query(find_references_query, property, resource.id.to_s)
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_inverse_references_by)
    def find_inverse_references_by(resource:, property:)
      internal_array = "[{\"id\": \"#{resource.id}\"}]"
      run_query(find_inverse_references_query, property, internal_array)
    end

    def run_query(query, *args)
      orm_class.find_by_sql(([query] + args)).lazy.map do |object|
        resource_factory.to_resource(object: object)
      end
    end

    def find_members_query
      <<-SQL
        SELECT member.* FROM orm_resources a,
        jsonb_array_elements(a.metadata->'member_ids') WITH ORDINALITY AS b(member, member_pos)
        JOIN orm_resources member ON (b.member->>'id')::uuid = member.id WHERE a.id = ?
        ORDER BY b.member_pos
      SQL
    end

    def find_members_with_type_query
      <<-SQL
        SELECT member.* FROM orm_resources a,
        jsonb_array_elements(a.metadata->'member_ids') WITH ORDINALITY AS b(member, member_pos)
        JOIN orm_resources member ON (b.member->>'id')::uuid = member.id WHERE a.id = ?
        AND member.internal_resource = ?
        ORDER BY b.member_pos
      SQL
    end

    def find_inverse_references_query
      <<-SQL
        SELECT * FROM orm_resources WHERE
        metadata->? @> ?
      SQL
    end

    def find_references_query
      <<-SQL
        SELECT member.* FROM orm_resources a,
        jsonb_array_elements(a.metadata->?) AS b(member)
        JOIN orm_resources member ON (b.member->>'id')::uuid = member.id WHERE a.id = ?
      SQL
    end

    def custom_queries
      @custom_queries ||= ::Valkyrie::Persistence::CustomQueryContainer.new(query_service: self)
    end
  end
end
