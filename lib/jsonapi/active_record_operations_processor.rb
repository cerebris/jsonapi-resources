class ActiveRecordOperationsProcessor < JSONAPI::OperationsProcessor
  private

  def transaction
    if @transactional
      ActiveRecord::Base.transaction do
        yield
      end
    else
      yield
    end
  end

  def rollback
    fail ActiveRecord::Rollback if @transactional
  end

  # Catch errors that should be handled before JSONAPI::Exceptions::Error
  # and other unprocessed exceptions
  def process_operation(operation)
    with_default_handling do 
      begin
        operation.apply
      rescue ActiveRecord::DeleteRestrictionError => e
        record_locked_error = JSONAPI::Exceptions::RecordLocked.new(e.message)
        return JSONAPI::ErrorsOperationResult.new(record_locked_error.errors[0].code, record_locked_error.errors)

      rescue ActiveRecord::RecordNotFound
        record_not_found = JSONAPI::Exceptions::RecordNotFound.new(operation.associated_key)
        return JSONAPI::ErrorsOperationResult.new(record_not_found.errors[0].code, record_not_found.errors)
      end
    end  
  end
end
