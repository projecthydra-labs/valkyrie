# frozen_string_literal: true
module Valkyrie::Persistence::Memory
  class Persister
    attr_reader :adapter
    delegate :cache, to: :adapter
    # @param adapter [Valkyrie::Persistence::Memory::Adapter] The memory adapter which
    #   holds the cache for this persister.
    def initialize(adapter)
      @adapter = adapter
    end

    # @param model [Valkyrie::Model] The model to save.
    # @return [Valkyrie::Model] The model with an `#id` value generated by the
    #   persistence backend.
    def save(model:)
      generate_id(model) if model.id.blank?
      model.updated_at = Time.current
      normalize_dates!(model)
      cache[model.id] = model
    end

    # @param models [Array<Valkyrie::Model>] List of models to save.
    # @return [Array<Valkyrie::Model>] List of models with an `#id` value
    #   generated by the persistence backend.
    def save_all(models:)
      models.map do |model|
        save(model: model)
      end
    end

    # @param model [Valkyrie::Model] The model to delete from the persistence
    #   backend.
    def delete(model:)
      cache.delete(model.id)
    end

    private

      def generate_id(model)
        model.id = SecureRandom.uuid
        model.created_at = Time.current
      end

      def normalize_dates!(model)
        model.attributes.each { |k, v| model.send("#{k}=", normalize_date_values(v)) }
      end

      def normalize_date_values(v)
        return v.map { |val| normalize_date_value(val) } if v.is_a?(Array)
        normalize_date_value(v)
      end

      def normalize_date_value(value)
        return value.utc if value.is_a?(DateTime)
        return value.to_datetime.utc if value.is_a?(Time)
        value
      end
  end
end
