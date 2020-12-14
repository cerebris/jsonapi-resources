module JSONAPI

  # ResourceIdentity describes a unique identity of a resource in the system.
  # This consists of a Resource class and an identifier that is unique within
  # that Resource class. ResourceIdentities are intended to be used as hash
  # keys to provide ordered mixing of resource types in result sets.
  #
  #
  # == Creating a ResourceIdentity
  #
  # rid = ResourceIdentity.new(PostResource, 12)
  #
  class ResourceIdentity
    attr_reader :resource_klass, :id, :custom_id

    def initialize(resource_klass, id, custom_id = nil)
      @resource_klass = resource_klass
      @id = id
      @custom_id = custom_id
    end

    def ==(other)
      # :nocov:
      eql?(other)
      # :nocov:
    end

    def eql?(other)
      other.is_a?(ResourceIdentity) && other.resource_klass == @resource_klass && other.id == @id && other.custom_id == @custom_id
    end

    def hash
      [@resource_klass, @id, @custom_id].hash
    end

    # Creates a string representation of the identifier.
    def to_s
      # :nocov:
      [resource_klass, id, custom_id].compact.join(':')
      # :nocov:
    end
  end
end
