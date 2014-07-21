require 'json/api/operation_result'

module JSON
  module API
    class OperationsProcessor
      def initialize(transaction_method = method(:transaction), rollback_method = method(:rollback))
        @transaction_method = transaction_method
        @rollback_method = rollback_method
      end

      def process(operations, options = {})
        @results = []
        @resources = []

        @transaction_method.call {
          operations.each do |operation|
            result = nil
            case operation.op
              when :add
                result = add(operation, options)
              when :replace
                result = replace(operation, options)
              when :remove
                result = remove(operation, options)
            end
            @results.push(result)
            if result.has_errors?
              @rollback_method.call
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

      def add(operation, options)
        res = operation.resource_klass.new

        update(res, operation.values)

        res.save

        if options[:batch]
          return JSON::API::OperationResult.new(:created, res)
        else
          return JSON::API::OperationResult.new(:created, nil, JSON::API::ResourceSerializer.new.serialize(res, options))
        end
      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, {}, e.errors)
      end

      def replace(operation, options)
        res = operation.resource_klass.find_by_key(operation.resource_id, options)

        update(res, operation.values)

        res.save

        if options[:batch]
          return JSON::API::OperationResult.new(:ok, res)
        else
          return JSON::API::OperationResult.new(:ok, nil, JSON::API::ResourceSerializer.new.serialize(res, options))
        end
      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, {}, e.errors)
      end

      def remove(operation, options)
        res = operation.resource_klass.find_by_key(operation.resource_id, options)
        res.destroy

        return JSON::API::OperationResult.new(:no_content)

      rescue ActiveRecord::DeleteRestrictionError => e
        record_locked_error = JSON::API::Exceptions::RecordLocked.new(e.message)
        return JSON::API::OperationResult.new(record_locked_error.errors[0].code, nil, {}, record_locked_error.errors)
      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, {}, e.errors)
      end

      def update(res, values)
        values.each do |property, value|
          res.send "#{property}=", value
        end unless values.nil?
      end
    end
  end
end