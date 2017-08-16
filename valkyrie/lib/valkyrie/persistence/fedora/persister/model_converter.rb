# frozen_string_literal: true
module Valkyrie::Persistence::Fedora
  class Persister
    class ModelConverter
      attr_reader :resource, :adapter, :subject_uri
      delegate :connection, :connection_prefix, :base_path, to: :adapter
      def initialize(resource:, adapter:, subject_uri: RDF::URI(""))
        @resource = resource
        @adapter = adapter
        @subject_uri = subject_uri
      end

      def convert
        graph_resource.graph.delete([nil, nil, nil])
        resource.attributes.each do |key, values|
          output = FedoraValue.for(Property.new(subject_uri, key, values, adapter)).result
          graph_resource.graph << output.to_graph
        end
        graph_resource
      end

      def graph_resource
        @graph_resource ||= ::Ldp::Container::Basic.new(connection, subject, nil, base_path)
      end

      def subject
        adapter.id_to_uri(resource.id) if resource.try(:id)
      end

      class Property
        attr_reader :key, :value, :subject, :adapter

        def self.to_uri(key)
          RDF::URI.new("http://example.com/predicate/#{key}")
        end

        def initialize(subject, key, value, adapter)
          @subject = subject
          @key = key
          @value = value
          @adapter = adapter
        end

        def to_graph(graph = RDF::Graph.new)
          Array(value).each do |val|
            graph << RDF::Statement.new(subject, self.class.to_uri(key), val)
          end
          graph
        end
      end

      class CompositeProperty
        attr_reader :properties
        def initialize(properties)
          @properties = properties
        end

        def to_graph(graph = RDF::Graph.new)
          properties.each do |property|
            property.to_graph(graph)
          end
          graph
        end
      end

      class GraphProperty
        attr_reader :key, :graph, :subject, :adapter
        def initialize(subject, key, graph, adapter)
          @subject = subject
          @key = key
          @graph = graph
          @adapter = adapter
        end

        def to_graph(passed_graph = RDF::Graph.new)
          passed_graph << graph
        end
      end

      class FedoraValue < ::Valkyrie::ValueMapper
      end

      class OrderedMembers < ::Valkyrie::ValueMapper
        FedoraValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.key == :member_ids && Array(value.value).present?
        end

        def result
          initialize_list
          apply_first_and_last
          GraphProperty.new(value.subject, value.key, graph, value.adapter)
        end

        def graph
          @graph ||= ordered_list.to_graph
        end

        def apply_first_and_last
          return if ordered_list.to_a.empty?
          graph << RDF::Statement.new(value.subject, ::RDF::Vocab::IANA.first, ordered_list.head.next.rdf_subject)
          graph << RDF::Statement.new(value.subject, ::RDF::Vocab::IANA.last, ordered_list.tail.prev.rdf_subject)
        end

        def initialize_list
          Array(value.value).each_with_index do |val, index|
            ordered_list.insert_proxy_for_at(index, calling_mapper.for(Property.new(value.subject, :member_id, val, value.adapter)).result.value)
          end
        end

        def ordered_list
          @ordered_list ||= OrderedList.new(RDF::Graph.new, nil, nil, value.adapter)
        end
      end

      class NestedProperty < ::Valkyrie::ValueMapper
        FedoraValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.is_a?(Hash) && value.value[:internal_resource]
        end

        def result
          nested_graph << RDF::Statement.new(value.subject, Property.to_uri(value.key), subject_uri)
          GraphProperty.new(value.subject, value.key, nested_graph, value.adapter)
        end

        def nested_graph
          @nested_graph ||= ModelConverter.new(resource: Valkyrie::Types::Anything[value.value], adapter: value.adapter, subject_uri: subject_uri).convert.graph
        end

        def subject_uri
          @subject_uri ||= ::RDF::URI(RDF::Node.new.to_s.gsub("_:", "#"))
        end
      end

      class NestedInternalValkyrieID < ::Valkyrie::ValueMapper
        FedoraValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.is_a?(Valkyrie::ID) && value.subject.to_s.include?("#")
        end

        def result
          calling_mapper.for(Property.new(value.subject, value.key, RDF::Literal.new(value.value, datatype: RDF::URI("http://example.com/predicate/valkyrie_id")), value.adapter)).result
        end
      end

      class InternalValkyrieID < ::Valkyrie::ValueMapper
        FedoraValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.is_a?(Valkyrie::ID) && !value.value.to_s.include?("://")
        end

        def result
          calling_mapper.for(Property.new(value.subject, value.key, value.adapter.id_to_uri(value.value), value.adapter)).result
        end
      end

      class TimeValue < ::Valkyrie::ValueMapper
        FedoraValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.is_a?(Time)
        end

        def result
          calling_mapper.for(Property.new(value.subject, value.key, value.value.to_datetime, value.adapter)).result
        end
      end

      class IdentifiableValue < ::Valkyrie::ValueMapper
        FedoraValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.is_a?(Valkyrie::ID)
        end

        def result
          calling_mapper.for(Property.new(value.subject, value.key, RDF::Literal.new(value.value, datatype: RDF::URI("http://example.com/predicate/valkyrie_id")), value.adapter)).result
        end
      end

      class EnumerableValue < ::Valkyrie::ValueMapper
        FedoraValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.is_a?(Array)
        end

        def result
          new_values = value.value.map do |val|
            calling_mapper.for(Property.new(value.subject, value.key, val, value.adapter)).result
          end
          CompositeProperty.new(new_values)
        end
      end
    end
  end
end
