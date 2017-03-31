# frozen_string_literal: true
class ResourceFactory
  class_attribute :adapter
  self.adapter = Penguin.config.adapter
  class << self
    delegate :to_model, :from_model, to: :default_adapter

    def default_adapter
      new(adapter: adapter)
    end
  end

  attr_reader :adapter
  delegate :to_model, :from_model, to: :adapter_class
  def initialize(adapter:)
    @adapter = adapter
  end

  def adapter_class
    adapter.resource_factory
  end
end
