module JSONAPI
  class OperationsProcessor
    include Callbacks
    define_jsonapi_resources_callbacks :operation, :operations

    def process(request)
      @results = JSONAPI::OperationResults.new
      @request = request
      @context = request.context
      @operations = request.operations

      # Use transactions if more than one operation and if one of the operations can be transactional
      # Even if transactional transactions won't be used unless the derived OperationsProcessor supports them.
      @transactional = false
      if @operations.length > 1
        @operations.each do |operation|
          @transactional = @transactional | operation.transactional
        end
      end

      run_callbacks :operations do
        transaction do
          @operations_meta = {}
          @operations.each do |operation|
            @operation = operation
            @operation_meta = {}
            run_callbacks :operation do
              result = process_operation(@operation)
              result.meta = @operation_meta
              @results.add_result(result)
              if @results.has_errors?
                rollback
              end
            end
          end
          @results.meta = @operations_meta
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