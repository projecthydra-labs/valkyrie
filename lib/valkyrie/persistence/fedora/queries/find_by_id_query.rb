# frozen_string_literal: true
module Valkyrie::Persistence::Fedora::Queries
  class FindByIdQuery
    attr_reader :id
    def initialize(id)
      @id = id
    end

    def run
      ::Valkyrie::Persistence::Fedora::ResourceFactory.to_model(relation)
    rescue ActiveFedora::ObjectNotFoundError, ::Ldp::Gone
      raise ::Persister::ObjectNotFoundError
    end

    private

      def relation
        orm_model.find(id.to_s)
      end

      def orm_model
        ::Valkyrie::Persistence::Fedora::ORM::Resource
      end
  end
end
