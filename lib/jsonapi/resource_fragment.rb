module JSONAPI

  # A ResourceFragment holds a ResourceIdentity and associated partial resource data.
  #
  # The following partial resource data may be stored
  # cache - the value of the cache field for the resource instance
  # related - a hash of arrays of related resource identities, grouped by relationship name
  # related_from - a set of related resource identities that loaded the fragment
  # resource - a resource instance
  #
  # Todo: optionally use these for faster responses by bypassing model instantiation)
  # attributes - resource attributes

  class ResourceFragment
    attr_reader :identity, :attributes, :related_from, :related, :resource

    attr_accessor :primary, :cache

    alias :cache_field :cache #ToDo: Rename one or the other

    def initialize(identity, resource: nil, cache: nil, primary: false)
      @identity = identity
      @cache = cache
      @resource = resource
      @primary = primary

      @attributes = {}
      @related = {}
      @related_from = Set.new
    end

    def initialize_related(relationship_name)
      @related[relationship_name.to_sym] ||= Set.new
    end

    def add_related_identity(relationship_name, identity)
      initialize_related(relationship_name)
      @related[relationship_name.to_sym] << identity if identity
    end

    def merge_related_identities(relationship_name, identities)
      initialize_related(relationship_name)
      @related[relationship_name.to_sym].merge(identities) if identities
    end

    def add_related_from(identity)
      @related_from << identity
    end

    def add_attribute(name, value)
      @attributes[name] = value
    end
  end
end