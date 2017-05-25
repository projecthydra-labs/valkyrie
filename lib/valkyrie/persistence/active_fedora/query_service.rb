# frozen_string_literal: true
module Valkyrie::Persistence::ActiveFedora
  class QueryService
    class << self
      def find_all
        Valkyrie::Persistence::ActiveFedora::Queries::FindAllQuery.new.run
      end

      def find_all_of_model(model:)
        Valkyrie::Persistence::ActiveFedora::Queries::FindAllQuery.new(model: model).run
      end

      def find_by(id:)
        Valkyrie::Persistence::ActiveFedora::Queries::FindByIdQuery.new(id).run
      end

      def find_members(model:)
        Valkyrie::Persistence::ActiveFedora::Queries::FindMembersQuery.new(model).run
      end

      def find_parents(model:)
        Valkyrie::Persistence::ActiveFedora::Queries::FindParentsQuery.new(model).run
      end

      def find_references_by(model:, property:)
        Valkyrie::Persistence::ActiveFedora::Queries::FindReferencesQuery.new(model, property).run
      end

      def find_inverse_references_by(model:, property:)
        Valkyrie::Persistence::ActiveFedora::Queries::FindInverseReferencesQuery.new(model, property).run
      end
    end
  end
end
