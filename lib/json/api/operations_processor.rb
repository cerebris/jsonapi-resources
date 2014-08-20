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
            case operation
              when AddResourceOperation
                result = add(operation, context)
              when AddHasManyAssociationOperation
                result = add_has_many_association(operation, context)
              when AddHasOneAssociationOperation
                result = add_has_one_association(operation, context)
              when ReplaceAttributesOperation
                result = replace(operation, context)
              when RemoveResourceOperation
                result = remove(operation, context)
              when RemoveHasManyAssociationOperation
                result = remove_has_many_association(operation, context)
              when RemoveHasOneAssociationOperation
                result = remove_has_one_association(operation, context)
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

        resource.before_operation(context, operation)

        update_resource_values(resource, operation.values)

        resource.save(context)

        resource.after_operation(context, operation)

        return JSON::API::OperationResult.new(:created, resource)
      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, e.errors)
      end

      #  Process an add_has_one_association operation
      def add_has_one_association(operation, context)
        resource = operation.resource_klass.find_by_key(operation.resource_id, context)

        resource.before_operation(context, operation)

        resource.create_has_one_link(context, operation.key, operation.key_value)

        resource.after_operation(context, operation)

        return JSON::API::OperationResult.new(:created, resource)
      end

      #  Process an add_has_one_association operation
      def add_has_many_association(operation, context)
        resource = operation.resource_klass.find_by_key(operation.resource_id, context)

        resource.before_operation(context, operation)
        association = resource.class._association(operation.association_type)

        operation.key_values.each do |value|
          related_resource = Resource.resource_for(association.serialize_type_name).find_by_key(value, context)
          resource.create_has_many_link(context, operation.association_type, related_resource)
        end

        resource.before_save(context)

        resource.save(context)

        resource.after_operation(context, operation)

        return JSON::API::OperationResult.new(:created, resource)
      end

      #  Process a replace operation
      def replace(operation, context)
        resource = operation.resource_klass.find_by_key(operation.resource_id, context)

        resource.before_operation(context, operation)

        update_resource_values(resource, operation.values)

        resource.before_save(context)

        resource.save(context)

        resource.after_operation(context, operation)

        return JSON::API::OperationResult.new(:ok, resource)
      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, e.errors)
      end

      # Process a remove operation
      def remove(operation, context)
        resource = operation.resource_klass.find_by_key(operation.resource_id, context)

        resource.before_operation(context, operation)

        resource.remove

        resource.after_operation(context, operation)

        return JSON::API::OperationResult.new(:no_content)

      rescue ActiveRecord::DeleteRestrictionError => e
        record_locked_error = JSON::API::Exceptions::RecordLocked.new(e.message)
        return JSON::API::OperationResult.new(record_locked_error.errors[0].code, nil, record_locked_error.errors)
      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, e.errors)
      end

      # Process a remove_has_one_association operation
      def remove_has_one_association(operation, context)
        resource = operation.resource_klass.find_by_key(operation.resource_id, context)

        key = operation.resource_klass._association(operation.association_type).key

        resource.before_operation(context, operation)

        resource.remove_has_one_link(context, key)

        resource.after_operation(context, operation)

        return JSON::API::OperationResult.new(:no_content)
      end

      # Process a remove_has_many_association operation
      def remove_has_many_association(operation, context)
        resource = operation.resource_klass.find_by_key(operation.resource_id, context)

        resource.before_operation(context, operation)

        resource.remove_has_many_link(context, operation.association_type, operation.associated_key)

        resource.after_operation(context, operation)

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