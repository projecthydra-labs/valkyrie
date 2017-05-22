# frozen_string_literal: true
module Valkyrie
  def config
    Config.new(
      YAML.safe_load(ERB.new(File.read(Rails.root.join("config", "valkyrie.yml"))).result)[Rails.env]
    )
  end

  class Config < OpenStruct
    def adapter
      Valkyrie::Adapter.find(super.to_sym)
    end

    def storage_adapter
      Valkyrie::FileRepository.find(super.to_sym)
    end
  end

  module_function :config
  module Model
    def self.included(base)
      base.include Virtus.model
      base.include Draper::Decoratable
      base.extend ClassMethods
    end

    def has_attribute?(name)
      respond_to?(name)
    end

    def column_for_attribute(name)
      name
    end

    def persisted?
      to_param.present?
    end

    def to_key
      [id]
    end

    def to_param
      id
    end

    def to_model
      self
    end

    def model_name
      ::ActiveModel::Name.new(self.class)
    end

    def resource_class
      self.class
    end

    def to_s
      "#{resource_class}: #{id}"
    end

    module ClassMethods
      def fields
        attribute_set.map(&:name)
      end
    end
  end
end
