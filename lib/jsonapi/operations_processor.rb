module JSONAPI
  class OperationsProcessor
    include Callbacks
    define_jsonapi_resources_callbacks :operation, :operations

    def process(request)
      @results = JSONAPI::OperationResults.new
      @request = request
      @context = request.context
      @operations = request.operations

      run_callbacks :operations do
        transaction do
          @operations.each do |operation|
            @operation = operation
            run_callbacks :operation do
              @results.add_result(process_operation(@operation))
              if @results.has_errors?
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