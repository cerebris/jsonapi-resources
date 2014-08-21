require 'jsonapi/operations_processor'

module JSONAPI
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