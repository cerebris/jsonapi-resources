module JSONAPI
  class OperationsProcessor
    include Callbacks
    define_jsonapi_resources_callbacks :operation,
                                       :operations,
                                       :find_operation,
                                       :show_operation,
                                       :show_association_operation,
                                       :show_related_resource_operation,
                                       :show_related_resources_operation,
                                       :create_resource_operation,
                                       :remove_resource_operation,
                                       :replace_fields_operation,
                                       :replace_has_one_association_operation,
                                       :create_has_many_association_operation,
                                       :replace_has_many_association_operation,
                                       :remove_has_many_association_operation,
                                       :remove_has_one_association_operation

    class << self
      def operations_processor_for(operations_processor)
        operations_processor_class_name = "#{operations_processor.to_s.camelize}OperationsProcessor"
        operations_processor_class_name.safe_constantize
      end
    end

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
          # Links and meta data global to the set of operations
          @operations_meta = {}
          @operations_links = {}
          @operations.each do |operation|
            @operation = operation
            # Links and meta data for each operation
            @operation_meta = {}
            @operation_links = {}
            run_callbacks :operation do
              @result = nil
              run_callbacks @operation.class.name.demodulize.underscore.to_sym do
                @result = process_operation(@operation)
              end
              @result.meta.merge!(@operation_meta)
              @result.links.merge!(@operation_links)
              @results.add_result(@result)
              if @results.has_errors?
                rollback
              end
            end
          end
          @results.meta = @operations_meta
          @results.links = @operations_links
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

class BasicOperationsProcessor < JSONAPI::OperationsProcessor
end