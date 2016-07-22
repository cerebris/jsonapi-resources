module JSONAPI
  class OperationResults
    attr_accessor :results
    attr_accessor :meta
    attr_accessor :links

    def initialize
      @results = []
      @has_errors = false
      @meta = {}
      @links = {}
    end

    def add_result(result)
      @has_errors = true if result.is_a?(JSONAPI::ErrorsOperationResult)
      @results.push(result)
    end

    def has_errors?
      @has_errors
    end

    def custom_errors?
      @has_errors &&
      @results.all? do |result|
        result.is_a?(JSONAPI::ErrorsOperationResult) && result.errors.is_a?(ActiveModel::Errors)
      end
    end

    def all_errors
      errors = []

      if concateable_errors?
        concatenate_errors(errors)
      elsif custom_errors?
        collect_error_objects(errors)
      end

      errors
    end

    private

    def concatenate_errors(collection)
      @results.each do |result|
        collection.concat(result.errors)
      end
    end

    def collect_error_objects(collection)
      @results.each do |result|
        collection.push(result.errors)
      end
    end

    def concateable_errors?
      @has_errors &&
      @results.all? do |result|
        result.is_a?(JSONAPI::ErrorsOperationResult) && result.errors.is_a?(Array)
      end
    end
  end
end
