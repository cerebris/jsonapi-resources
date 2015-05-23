module JSONAPI
  class OperationResults
    attr_accessor :results

    def initialize
      @results = []
      @has_errors = false
    end

    def add_result(result)
      @has_errors = true if result.is_a?(JSONAPI::ErrorsOperationResult)
      @results.push(result)
    end

    def has_errors?
      @has_errors
    end

    def all_errors
      errors = []
      @results.each do |result|
        if result.is_a?(JSONAPI::ErrorsOperationResult)
          errors.concat(result.errors)
        end
      end if @has_errors
      errors
    end
  end
end
