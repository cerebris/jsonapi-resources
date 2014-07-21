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
            before_operation(context, operation)

            result = operation.apply(context)

            after_operation(context, result)

            @results.push(result)
            if result.has_errors?
              rollback
            end
          end
        }
        @results
      end

      def before_operation(context, operation)
      end

      def after_operation(context, result)
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
    end
  end
end