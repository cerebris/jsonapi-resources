module JSONAPI
  class RecordAccessor
    attr_reader :_resource_klass

    def initialize(resource_klass)
      @_resource_klass = resource_klass
    end

    # Resource records
    def find_resource(_filters, _options = {})
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    def find_resource_by_key(_key, options = {})
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    def find_resources_by_keys(_keys, options = {})
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    def find_count(_filters, _options = {})
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    # Relationship records
    def related_resource(_resource, _relationship_name, _options = {})
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    def related_resources(_resource, _relationship_name, _options = {})
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    def count_for_relationship(_resource, _relationship_name, _options = {})
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    # Keys
    def foreign_key(_resource, _relationship_name, options = {})
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    def foreign_keys(_resource, _relationship_name, _options = {})
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end
  end
end