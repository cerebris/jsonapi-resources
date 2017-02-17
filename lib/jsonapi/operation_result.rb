module JSONAPI
  class OperationResult
    attr_accessor :code
    attr_accessor :meta
    attr_accessor :links
    attr_accessor :options
    attr_accessor :warnings

    def initialize(code, options = {})
      @code = Rack::Utils.status_code(code)
      @options = options
      @meta = options.fetch(:meta, {})
      @links = options.fetch(:links, {})
      @warnings = options.fetch(:warnings, {})
    end

    def to_hash(serializer = nil)
      {}
    end
  end

  class ErrorsOperationResult < OperationResult
    attr_accessor :errors

    def initialize(code, errors, options = {})
      @errors = errors
      super(code, options)
    end

    def to_hash(serializer = nil)
      {
          errors: errors.collect do |error|
            # :nocov:
            error.to_hash
            # :nocov:
          end
      }
    end
  end

  class ResourceOperationResult < OperationResult
    attr_accessor :resource

    def initialize(code, resource, options = {})
      @resource = resource
      super(code, options)
    end

    def to_hash(serializer = nil)
      if serializer
        serializer.serialize_to_hash(resource)
      else
        # :nocov:
        {}
        # :nocov:
      end
    end
  end

  class ResourcesOperationResult < OperationResult
    attr_accessor :resources, :pagination_params, :record_count, :page_count

    def initialize(code, resources, options = {})
      @resources = resources
      @pagination_params = options.fetch(:pagination_params, {})
      @record_count = options[:record_count]
      @page_count = options[:page_count]
      super(code, options)
    end

    def to_hash(serializer)
      if serializer
        serializer.serialize_to_hash(resources)
      else
        # :nocov:
        {}
        # :nocov:
      end
    end
  end

  class RelatedResourcesOperationResult < ResourcesOperationResult
    attr_accessor :source_resource, :_type

    def initialize(code, source_resource, type, resources, options = {})
      @source_resource = source_resource
      @_type = type
      super(code, resources, options)
    end

    def to_hash(serializer = nil)
      if serializer
        serializer.serialize_to_hash(resources)
      else
        # :nocov:
        {}
        # :nocov:
      end
    end
  end

  class LinksObjectOperationResult < OperationResult
    attr_accessor :parent_resource, :relationship

    def initialize(code, parent_resource, relationship, options = {})
      @parent_resource = parent_resource
      @relationship = relationship
      super(code, options)
    end

    def to_hash(serializer = nil)
      if serializer
        serializer.serialize_to_links_hash(parent_resource, relationship)
      else
        # :nocov:
        {}
        # :nocov:
      end
    end
  end
end
