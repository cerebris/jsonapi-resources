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

    def process_operation(operation)
      operation.apply(@context)
    rescue ActiveRecord::DeleteRestrictionError => e
      record_locked_error = JSONAPI::Exceptions::RecordLocked.new(e.message)
      return JSONAPI::OperationResult.new(record_locked_error.errors[0].code, nil, record_locked_error.errors)

    rescue ActiveRecord::RecordNotFound
      record_not_found = JSONAPI::Exceptions::RecordNotFound.new(operation.associated_key)
      return JSONAPI::OperationResult.new(record_not_found.errors[0].code, nil, record_not_found.errors)
    end
  end
end