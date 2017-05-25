# frozen_string_literal: true
module Valkyrie::Persistence::Solr
  class Repository
    attr_reader :model, :connection, :resource_factory
    def initialize(model:, connection:, resource_factory:)
      @model = model
      @connection = connection
      @resource_factory = resource_factory
    end

    def persist
      generate_id if model.id.blank?
      connection.add solr_document, params: { softCommit: true }
      model
    end

    def delete
      connection.delete_by_id "id-#{model.id}", params: { softCommit: true }
      model
    end

    def solr_document
      resource_factory.from_model(model).to_h
    end

    def inner_model
      if model.respond_to?(:model)
        model.model
      else
        model
      end
    end

    def generate_id
      Rails.logger.warn "The Solr adapter is not meant to persist new resources, but is now generating an ID."
      inner_model.id = SecureRandom.uuid
    end
  end
end
