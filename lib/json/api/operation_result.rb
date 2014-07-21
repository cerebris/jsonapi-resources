module JSON
  module API
    class OperationResult
      attr_accessor(:code, :result, :errors, :resource)

      def initialize(code, resource = nil, result = {} , errors = [])
        @code = code
        @result = result
        @errors = errors
        @resource = resource
      end

      def has_errors?
        errors.count > 0
      end
    end
  end
end