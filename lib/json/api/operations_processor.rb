require 'json/api/operation_result'

module JSON
  module API
    class OperationsProcessor

      def process(request)
        @results = []
        @resources = []

        context = request.context

        transaction {
          request.operations.each do |operation|
            result = nil
            case operation.op
              when :add
                result = add(operation, context)
              when :replace
                result = replace(operation, context)
              when :remove
                result = remove(operation, context)
              when :remove_association
                result = remove_association(operation, context)
            end
            @results.push(result)
            if result.has_errors?
              rollback
            end
          end
        }
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

      #  Process an add operation
      def add(operation, context)
        resource = operation.resource_klass.new

        resource.before_create(context, operation.values)

        update_resource_values(resource, operation.values)

        resource.before_save(context)

        resource.save

        resource.after_create(context)

        return JSON::API::OperationResult.new(:created, resource)
      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, e.errors)
      end

      #  Process a replace operation
      def replace(operation, context)
        resource = operation.resource_klass.find_by_key(operation.resource_id, context)

        resource.before_replace(context, operation.values)

        update_resource_values(resource, operation.values)

        resource.before_save(context)

        resource.save

        resource.after_replace(context)

        return JSON::API::OperationResult.new(:ok, resource)
      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, e.errors)
      end

      # Process a remove operation
      def remove(operation, context)
        resource = operation.resource_klass.find_by_key(operation.resource_id, context)

        resource.before_remove(context)

        resource.remove

        resource.after_remove(context)

        return JSON::API::OperationResult.new(:no_content)

      rescue ActiveRecord::DeleteRestrictionError => e
        record_locked_error = JSON::API::Exceptions::RecordLocked.new(e.message)
        return JSON::API::OperationResult.new(record_locked_error.errors[0].code, nil, record_locked_error.errors)
      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, e.errors)
      end

      # Process a remove_association operation
      def remove_association(operation, context)
        resource = operation.resource_klass.find_by_key(operation.resource_id, context)

        key = operation.values[:associated_key]

        resource.before_remove_association(context, key)

        if key
          resource.remove_has_many_link(operation.values[:association], key)
        else
          resource.remove_has_one_link(operation.values[:association])
        end

        resource.after_remove_association(context)

        return JSON::API::OperationResult.new(:no_content)
      end

      # Updates each value on the resource with the new values provided
      def update_resource_values(resource, values)
        values.each do |property, value|
          resource.send "#{property}=", value
        end unless values.nil?
      end
    end
  end
end