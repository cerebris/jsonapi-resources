module Helpers
# Test specific methods needed by each ORM for test cases to work.
  module RecordAccessorHelpers
    def find_first(model_class, id)
      find_all(model_class, id).first
    end

    # Written to be ORM agnostic so long as the orm implements a #where method which responds to #all
    # or #first, which many of them do. If needed this, can be abstracted out into the RecordAccessor, but
    # since they are only used for tests, I didn't want to add test-only logic into the library.
    def find_all(model_class, *ids)
      model_class.where(ids.first.is_a?(Hash) ? ids.first : {id: ids})
    end

    def save!(model)
      JSONAPI.configuration.default_record_accessor_klass.save(model, raise_on_failure: true)
    end

  end

end