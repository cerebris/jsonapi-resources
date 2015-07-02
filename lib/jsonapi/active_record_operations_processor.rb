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
    raise ActiveRecord::Rollback if @transactional
  end

  def process_operation(operation)
    operation.apply
  rescue ActiveRecord::DeleteRestrictionError => e
    record_locked_error = JSONAPI::Exceptions::RecordLocked.new(e.message)
    return JSONAPI::ErrorsOperationResult.new(record_locked_error.errors[0].code, record_locked_error.errors)

  rescue ActiveRecord::RecordNotFound
    record_not_found = JSONAPI::Exceptions::RecordNotFound.new(operation.associated_key)
    return JSONAPI::ErrorsOperationResult.new(record_not_found.errors[0].code, record_not_found.errors)

  rescue JSONAPI::Exceptions::Error => e
    raise e

  rescue => e
    internal_server_error = JSONAPI::Exceptions::InternalServerError.new(e)
    Rails.logger.error { "Internal Server Error: #{e.message} #{e.backtrace.join("\n")}" }
    return JSONAPI::ErrorsOperationResult.new(internal_server_error.errors[0].code, internal_server_error.errors)
  end
end
