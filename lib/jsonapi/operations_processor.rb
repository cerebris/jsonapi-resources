require 'jsonapi/operation_result'
require 'jsonapi/callbacks'

module JSONAPI
  class OperationsProcessor
    include Callbacks
    define_jsonapi_resources_callbacks :operation, :operations

    def process(request)
      @results = []
      @request = request
      @context = request.context
      @operations = request.operations

      run_callbacks :operations do
        transaction do
          @operations.each do |operation|
            @operation = operation
            @result = nil
            run_callbacks :operation do
              @result = process_operation(@operation)
              @results.push(@result)
              if @result.has_errors?
                rollback
              end
            end
          end
        end
      end
      @results
    end

    private

    # The base OperationsProcessor provides no transaction support
    # Override the transaction and rollback methods to provide transaction support.
    # For ActiveRecord transactions you can use the ActiveRecordOperationsProcessor
    def transaction
      yield
    end

    def rollback
    end

    def process_operation(operation)
      operation.apply(@context)
    end
  end
end