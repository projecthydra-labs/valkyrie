# frozen_string_literal: true
module Valkyrie::Persistence::Fedora
  class MetadataAdapter
    attr_reader :connection, :base_path
    def initialize(connection:, base_path: "/")
      @connection = connection
      @base_path = base_path
    end

    def query_service
      Valkyrie::Persistence::Fedora::QueryService.new(adapter: self)
    end

    def persister
      Valkyrie::Persistence::Fedora::Persister.new(adapter: self)
    end

    def uri_to_id(uri)
      Valkyrie::ID.new(uri.to_s.gsub(/^.*\//, ''))
    end

    def id_to_uri(id)
      RDF::URI("#{connection_prefix}/#{pair_path(id)}/#{id}")
    end

    def pair_path(id)
      id.to_s.split("-").first.split("").each_slice(2).map(&:join).join("/")
    end

    def connection_prefix
      "#{connection.options}/#{base_path}"
    end

    def wipe!
      connection.delete(base_path)
      connection.delete("#{base_path}/fcr:tombstone")
    rescue => error
      Valkyrie.logger.debug("Failed to wipe Fedora for some reason.") unless error.is_a?(::Ldp::NotFound)
    end
  end
end
