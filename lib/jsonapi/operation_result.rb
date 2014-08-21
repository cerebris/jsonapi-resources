module JSONAPI
  class OperationResult
    attr_accessor :code, :errors, :resource

    def initialize(code, resource = nil, errors = [])
      @code = code
      @resource = resource
      @errors = errors
    end

    def has_errors?
      errors.count > 0
    end
  end
end
