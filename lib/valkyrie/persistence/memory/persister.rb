# frozen_string_literal: true
module Valkyrie::Persistence::Memory
  # Persister for the memory metadata adapter.
  # @see Valkyrie::Persistence::Memory
  # @note Documentation for persisters in general is maintained here.
  class Persister
    attr_reader :adapter
    delegate :cache, to: :adapter

    # @param adapter [Valkyrie::Persistence::Memory::MetadataAdapter] The memory adapter which
    #   holds the cache for this persister.
    # @note Many persister methods are part of Valkyrie's public API, but instantiation itself is not
    def initialize(adapter)
      @adapter = adapter
    end

    # Save a single resource.
    # @param resource [Valkyrie::Resource] The resource to save.
    # @return [Valkyrie::Resource] The resource with an `#id` value generated by the
    #   persistence backend.
    # @raise [Valkyrie::Persistence::StaleObjectError]
    def save(resource:)
      raise Valkyrie::Persistence::StaleObjectError, "The object #{resource.id} has been updated by another process." unless valid_lock?(resource)

      # duplicate the resource so we are not creating side effects on the caller's resource
      internal_resource = resource.dup

      internal_resource = generate_id(internal_resource) if internal_resource.id.blank?
      internal_resource.created_at ||= Time.current
      internal_resource.updated_at = Time.current
      internal_resource.new_record = false
      generate_lock_token(internal_resource)
      normalize_dates!(internal_resource)
      cache[internal_resource.id] = internal_resource
    end

    # Save a batch of resources.
    # @param resources [Array<Valkyrie::Resource>] List of resources to save.
    # @return [Array<Valkyrie::Resource>] List of resources with an `#id` value
    #   generated by the persistence backend.
    # @raise [Valkyrie::Persistence::StaleObjectError]
    def save_all(resources:)
      resources.map do |resource|
        save(resource: resource)
      end
    rescue Valkyrie::Persistence::StaleObjectError
      # Re-raising with no error message to prevent confusion
      raise Valkyrie::Persistence::StaleObjectError, "One or more resources have been updated by another process."
    end

    # Delete a resource.
    # @param resource [Valkyrie::Resource] The resource to delete from the persistence
    #   backend.
    def delete(resource:)
      cache.delete(resource.id)
    end

    # Removes all data from the persistence backend.
    def wipe!
      cache.clear
    end

    private

      def generate_id(resource)
        resource.new(id: SecureRandom.uuid)
      end

      # Convert all dates to DateTime in the UTC time zone for consistency.
      def normalize_dates!(resource)
        resource.attributes.each { |k, v| resource.send("#{k}=", normalize_date_values(v)) }
      end

      def normalize_date_values(v)
        return v.map { |val| normalize_date_value(val) } if v.is_a?(Array)
        normalize_date_value(v)
      end

      def normalize_date_value(value)
        return value.new_offset(0) if value.is_a?(DateTime)
        return value.to_datetime.new_offset(0) if value.is_a?(Time)
        value
      end

      # Create a new lock token based on the current timestamp.
      def generate_lock_token(resource)
        token = Valkyrie::Persistence::OptimisticLockToken.new(adapter_id: adapter.id, token: Time.now.to_r)
        cache[:versions] ||= {}
        cache[:versions][resource.id] = token
        return unless resource.optimistic_locking_enabled?
        resource.set_value(Valkyrie::Persistence::Attributes::OPTIMISTIC_LOCK, token)
      end

      # Check whether a resource is current.
      def valid_lock?(resource)
        return true unless resource.optimistic_locking_enabled?

        cached_resource = cache[resource.id]
        return true if cached_resource.blank?

        resource_lock_tokens = resource[Valkyrie::Persistence::Attributes::OPTIMISTIC_LOCK] || []
        resource_value = resource_lock_tokens.find { |lock_token| lock_token.adapter_id == adapter.id }
        cached_token = cached_resource[Valkyrie::Persistence::Attributes::OPTIMISTIC_LOCK] || []
        cached_value = cached_token.find { |lock_token| lock_token.adapter_id == adapter.id }
        return true if resource_value.nil?

        cached_value == resource_value
      end
  end
end
