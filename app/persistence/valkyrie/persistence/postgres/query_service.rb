# frozen_string_literal: true
module Valkyrie::Persistence::Postgres
  class QueryService
    class << self
      def find_all
        Valkyrie::Persistence::Postgres::Queries::FindAllQuery.new.run
      end

      def find_by(id:)
        Valkyrie::Persistence::Postgres::Queries::FindByIdQuery.new(id).run
      end

      def find_members(model:)
        Valkyrie::Persistence::Postgres::Queries::FindMembersQuery.new(model).run
      end

      def find_parents(model:)
        Valkyrie::Persistence::Postgres::Queries::FindParentsQuery.new(model).run
      end

      def find_references_by(model:, property:)
        Valkyrie::Persistence::Postgres::Queries::FindReferencesQuery.new(model, property).run
      end
    end
  end
end
