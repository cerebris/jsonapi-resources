module JSONAPI
  class RecordAccessor
    attr_reader :_resource_klass

    # Note: model_base_class, delete_restriction_error_class, record_not_found_error_class could be defined as
    # class attributes but currently all the library files are loaded using 'require', so if we have something like
    # self.model_base_class = ActiveRecord::Base, then ActiveRecord would be required as a dependency. Leaving these
    # as instance methods means we can load in these files at load-time and use them if they so choose.

    def initialize(resource_klass)
      @_resource_klass = resource_klass
    end

    def model_base_class
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    def delete_restriction_error_class
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    def record_not_found_error_class
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    def transaction
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    # Should return an enumerable with the key being the attribute name and value being an array of error messages.
    def model_error_messages(model)
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    def rollback_transaction
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
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