require 'json/api/operation_result'

module JSON
  module API
    class OperationsProcessor

      def process(request, context = {})
        @results = []
        @resources = []
        @request = request

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
      def transaction
        yield
      end

      def rollback
      end

      def add(operation, context = {})
        resource = operation.resource_klass.new

        resource.before_create(context, operation.values)

        update_resource_values(resource, operation.values)

        resource.before_save(context)

        resource.save

        resource.after_create(context)

        return JSON::API::OperationResult.new(:created, resource)
      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, {}, e.errors)
      end

      def replace(operation, context = {})
        resource = operation.resource_klass.find_by_key(operation.resource_id, context)

        resource.before_replace(context, operation.values)

        update_resource_values(resource, operation.values)

        resource.before_save(context)

        resource.save

        resource.after_replace(context)

        return JSON::API::OperationResult.new(:ok, resource)
      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, {}, e.errors)
      end

      def remove(operation, context = {})
        resource = operation.resource_klass.find_by_key(operation.resource_id, context)

        resource.before_remove(context)

        resource.remove

        resource.after_remove(context)

        return JSON::API::OperationResult.new(:no_content)

      rescue ActiveRecord::DeleteRestrictionError => e
        record_locked_error = JSON::API::Exceptions::RecordLocked.new(e.message)
        return JSON::API::OperationResult.new(record_locked_error.errors[0].code, nil, {}, record_locked_error.errors)
      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, {}, e.errors)
      end

      def update_resource_values(resource, values)
        values.each do |property, value|
          resource.send "#{property}=", value
        end unless values.nil?
      end
    end
  end
end