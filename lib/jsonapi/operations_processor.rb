module JSONAPI
  class OperationsProcessor
    include Callbacks
    define_jsonapi_resources_callbacks :operation,
                                       :operations,
                                       :find_operation,
                                       :show_operation,
                                       :show_relationship_operation,
                                       :show_related_resource_operation,
                                       :show_related_resources_operation,
                                       :create_resource_operation,
                                       :remove_resource_operation,
                                       :replace_fields_operation,
                                       :replace_to_one_relationship_operation,
                                       :replace_polymorphic_to_one_relationship_operation,
                                       :create_to_many_relationship_operation,
                                       :replace_to_many_relationship_operation,
                                       :remove_to_many_relationship_operation,
                                       :remove_to_one_relationship_operation

    class << self
      def operations_processor_for(operations_processor)
        operations_processor_class_name = "#{operations_processor.to_s.camelize}OperationsProcessor"
        operations_processor_class_name.safe_constantize
      end
    end

    def process(request)
      @results = JSONAPI::OperationResults.new
      @request = request
      @operations = request.operations

      # Use transactions if more than one operation and if one of the operations can be transactional
      # Even if transactional transactions won't be used unless the derived OperationsProcessor supports them.
      @transactional = false
      @operations.each do |operation|
        @transactional |= operation.transactional
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
              rollback if @results.has_errors?
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

    # If overriding in child operation processors, call operation.apply and 
    # catch errors that should be handled before JSONAPI::Exceptions::Error
    # and other unprocessed exceptions
    def process_operation(operation)
      with_default_handling do 
        operation.apply
      end        
    end

    def with_default_handling(&block)
      yield
    rescue JSONAPI::Exceptions::Error => e
      raise e

    rescue => e
      if JSONAPI.configuration.exception_class_whitelist.any? { |k| e.class.ancestors.include?(k) }
        raise e
      else
        @request.server_error_callbacks.each { |callback| safe_run_callback(callback, e) }

        internal_server_error = JSONAPI::Exceptions::InternalServerError.new(e)
        Rails.logger.error { "Internal Server Error: #{e.message} #{e.backtrace.join("\n")}" }
        return JSONAPI::ErrorsOperationResult.new(internal_server_error.errors[0].code, internal_server_error.errors)
      end
    end

    def safe_run_callback(callback, error)
      begin 
        callback.call(error)
      rescue => e
        Rails.logger.error { "Error in error handling callback: #{e.message} #{e.backtrace.join("\n")}" }
        internal_server_error = JSONAPI::Exceptions::InternalServerError.new(e)
        return JSONAPI::ErrorsOperationResult.new(internal_server_error.errors[0].code, internal_server_error.errors)
      end
    end

  end
end

class BasicOperationsProcessor < JSONAPI::OperationsProcessor
end
