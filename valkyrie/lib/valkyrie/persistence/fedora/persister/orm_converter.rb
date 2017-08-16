# frozen_string_literal: true
module Valkyrie::Persistence::Fedora
  class Persister
    class OrmConverter
      attr_reader :object, :adapter
      delegate :graph, to: :object
      def initialize(object:, adapter:)
        @object = object
        @adapter = adapter
      end

      def convert
        Valkyrie::Types::Anything[attributes]
      end

      def attributes
        GraphToAttributes.new(graph: graph, adapter: adapter).convert.merge(id:
                                                                            id)
      end

      def id
        id_property.present? ? Valkyrie::ID.new(id_property) : adapter.uri_to_id(object.subject_uri)
      end

      def id_property
        return unless object.subject_uri.to_s.include?("#")
        object.graph.query([RDF::URI(""), RDF::URI("http://example.com/predicate/id"), nil]).to_a.first.try(:object).to_s
      end

      class GraphToAttributes
        attr_reader :graph, :adapter
        def initialize(graph:, adapter:)
          @graph = graph
          @adapter = adapter
        end

        def convert
          graph.each do |statement|
            FedoraValue.for(Property.new(statement: statement, scope: graph, adapter: adapter)).result.apply_to(attributes)
          end
          attributes
        end

        def attributes
          @attributes ||= {}
        end

        class FedoraValue < ::Valkyrie::ValueMapper
          def result
            Applicator.new(value)
          end
        end

        class BlacklistedValue < ::Valkyrie::ValueMapper
          FedoraValue.register(self)
          def self.handles?(value)
            value.statement.object.to_s.start_with?("http://www.w3.org/ns/ldp", "http://fedora.info")
          end

          def result
            NullApplicator
          end
        end

        class DifferentSubject < ::Valkyrie::ValueMapper
          FedoraValue.register(self)
          def self.handles?(value)
            value.statement.subject.to_s.include?("#")
          end

          def result
            NullApplicator
          end
        end

        class CompositeApplicator
          attr_reader :applicators
          def initialize(applicators)
            @applicators = applicators
          end

          def apply_to(hsh)
            applicators.each do |applicator|
              applicator.apply_to(hsh)
            end
            hsh
          end
        end

        class MemberID < ::Valkyrie::ValueMapper
          delegate :scope, :adapter, to: :value
          FedoraValue.register(self)
          def self.handles?(value)
            value.statement.predicate == ::RDF::Vocab::IANA.first
          end

          def result
            value.statement.predicate = ::RDF::URI("http://example.com/predicate/member_ids")
            values = OrderedList.new(scope, head, tail, adapter).to_a.map(&:proxy_for)
            values = values.map do |val|
              calling_mapper.for(Property.new(statement: RDF::Statement.new(value.statement.subject, value.statement.predicate, val), scope: value.scope, adapter: value.adapter)).result
            end
            CompositeApplicator.new(values)
          end

          def head
            scope.query([value.statement.subject, RDF::Vocab::IANA.first]).to_a.first.object
          end

          def tail
            scope.query([value.statement.subject, RDF::Vocab::IANA.last]).to_a.first.object
          end
        end

        class NestedValue < ::Valkyrie::ValueMapper
          FedoraValue.register(self)
          def self.handles?(value)
            value.statement.object.is_a?(RDF::URI) && value.statement.object.to_s.include?("#") &&
              (value.statement.object.to_s.start_with?("#") ||
               value.statement.object.to_s.start_with?(value.adapter.connection_prefix))
          end

          def result
            value.scope.each do |statement|
              next unless statement.subject.to_s.include?("#")
              subject = new_subject(statement)
              graph << RDF::Statement.new(subject, statement.predicate, statement.object)
            end
            value.statement.object = resource
            Applicator.new(Property.new(statement: value.statement, scope: value.scope, adapter: value.adapter))
          end

          def container
            GraphContainer.new(graph, value.statement.object)
          end

          def resource
            OrmConverter.new(object: container, adapter: value.adapter).convert
          end

          def new_subject(statement)
            if statement.subject == value.statement.object
              RDF::URI("")
            else
              statement.subject
            end
          end

          def graph
            @graph ||= RDF::Graph.new
          end

          class GraphContainer
            attr_reader :graph, :subject_uri
            def initialize(graph, subject_uri)
              @graph = graph
              @subject_uri = subject_uri
            end
          end
        end

        class IntegerValue < ::Valkyrie::ValueMapper
          FedoraValue.register(self)
          def self.handles?(value)
            value.statement.object.is_a?(RDF::Literal) && value.statement.object.datatype == RDF::URI("http://www.w3.org/2001/XMLSchema#integer")
          end

          def result
            value.statement.object = value.statement.object.to_i
            calling_mapper.for(Property.new(statement: value.statement, scope: value.scope, adapter: value.adapter)).result
          end
        end

        class DateTimeValue < ::Valkyrie::ValueMapper
          FedoraValue.register(self)
          def self.handles?(value)
            value.statement.object.is_a?(RDF::Literal::DateTime)
          end

          def result
            value.statement.object = ::DateTime.iso8601(value.statement.object.to_s).utc
            calling_mapper.for(Property.new(statement: value.statement, scope: value.scope, adapter: value.adapter)).result
          end
        end

        class LiteralValue < ::Valkyrie::ValueMapper
          FedoraValue.register(self)
          def self.handles?(value)
            value.statement.object.is_a?(RDF::Literal) && value.statement.object.language.blank? && value.statement.object.datatype == RDF::URI("http://www.w3.org/2001/XMLSchema#string")
          end

          def result
            value.statement.object = value.statement.object.to_s
            calling_mapper.for(Property.new(statement: value.statement, scope: value.scope, adapter: value.adapter)).result
          end
        end

        class ValkyrieIDValue < ::Valkyrie::ValueMapper
          FedoraValue.register(self)
          def self.handles?(value)
            value.statement.object.is_a?(RDF::Literal) && value.statement.object.datatype == RDF::URI("http://example.com/predicate/valkyrie_id")
          end

          def result
            value.statement.object = Valkyrie::ID.new(value.statement.object.to_s)
            calling_mapper.for(Property.new(statement: value.statement, scope: value.scope, adapter: value.adapter)).result
          end
        end

        class InternalURI < ::Valkyrie::ValueMapper
          FedoraValue.register(self)
          def self.handles?(value)
            value.statement.object.is_a?(RDF::URI) && value.statement.object.to_s.start_with?(value.adapter.connection_prefix)
          end

          def result
            value.statement.object = value.adapter.uri_to_id(value.statement.object)
            calling_mapper.for(Property.new(statement: value.statement, scope: value.scope, adapter: value.adapter)).result
          end
        end

        class InternalModelValue < ::Valkyrie::ValueMapper
          FedoraValue.register(self)
          def self.handles?(value)
            value.statement.predicate.to_s == "http://example.com/predicate/internal_resource"
          end

          def result
            SingleApplicator.new(value)
          end
        end

        class CreatedAtValue < ::Valkyrie::ValueMapper
          FedoraValue.register(self)
          def self.handles?(value)
            value.statement.predicate.to_s == "http://example.com/predicate/created_at"
          end

          def result
            NonStringSingleApplicator.new(value)
          end
        end

        class UpdatedAtValue < ::Valkyrie::ValueMapper
          FedoraValue.register(self)
          def self.handles?(value)
            value.statement.predicate.to_s == "http://example.com/predicate/updated_at"
          end

          def result
            NonStringSingleApplicator.new(value)
          end
        end

        class NullApplicator
          def self.apply_to(_hsh); end
        end

        class Applicator
          attr_reader :property
          delegate :statement, to: :property
          def initialize(property)
            @property = property
          end

          def apply_to(hsh)
            return if blacklist?(key)
            hsh[key.to_sym] ||= []
            hsh[key.to_sym] += cast_array(values)
          end

          def key
            key = statement.predicate.to_s
            namespaces.each do |namespace|
              key = key.gsub(/^#{namespace}/, '')
            end
            key
          end

          def blacklist?(key)
            blacklist.each do |blacklist_item|
              return true if key.start_with?(blacklist_item)
            end
            false
          end

          def cast_array(values)
            if values.is_a?(Time)
              [values]
            else
              Array(values)
            end
          end

          def blacklist
            [
              "http://fedora.info/definitions",
              "http://www.iana.org/assignments/relation/last"
            ]
          end

          def namespaces
            [
              "http://www.fedora.info/definitions/v4/",
              "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
              "http://example.com/predicate/"
            ]
          end

          def values
            statement.object
          end
        end

        class SingleApplicator < Applicator
          def apply_to(hsh)
            hsh[key.to_sym] = values.to_s
          end
        end

        class NonStringSingleApplicator < Applicator
          def apply_to(hsh)
            hsh[key.to_sym] = values
          end
        end

        class Property
          attr_reader :statement, :scope, :adapter
          def initialize(statement:, scope:, adapter:)
            @statement = statement
            @scope = scope
            @adapter = adapter
          end
        end
      end
    end
  end
end
