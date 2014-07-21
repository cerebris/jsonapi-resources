require 'json/api/operations_processor'

module JSON
  module API
    class ActiveRecordOperationsProcessor < OperationsProcessor

      private
      def transaction
        ActiveRecord::Base.transaction do
          yield
        end
      end

      def rollback
        raise ActiveRecord::Rollback
      end
    end
  end
end