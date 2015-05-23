module JSONAPI
  class OperationResult
    attr_accessor :code

    def initialize(code)
      @code = code
    end
  end

  class ErrorsOperationResult < OperationResult
    attr_accessor :errors

    def initialize(code, errors)
      @errors = errors
      super(code)
    end
  end

  class ResourceOperationResult < OperationResult
    attr_accessor :resource

    def initialize(code, resource)
      @resource = resource
      super(code)
    end
  end

  class ResourcesOperationResult < OperationResult
    attr_accessor :resources

    def initialize(code, resources)
      @resources = resources
      super(code)
    end
  end

  class LinksObjectOperationResult < OperationResult
    attr_accessor :parent_resource, :association

    def initialize(code, parent_resource, association)
      @parent_resource = parent_resource
      @association = association
      super(code)
    end
  end
end
