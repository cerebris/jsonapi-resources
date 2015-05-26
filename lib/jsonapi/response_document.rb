module JSONAPI
  class ResponseDocument
    def initialize(operation_results, options = {})
      @operation_results = operation_results
      @options = options
    end

    def contents
      results_to_hash
    end

    def status
      if @operation_results.has_errors?
        @operation_results.all_errors[0].status
      else
        @operation_results.results[0].code
      end
    end

    private

    def serializer
      @serializer ||= JSONAPI::ResourceSerializer.new(
        @options.fetch(:primary_resource_klass),
        include: @options.fetch(:include),
        include_directives: @options.fetch(:include_directives),
        fields: @options.fetch(:fields),
        base_url: @options.fetch(:base_url),
        key_formatter: @options.fetch(:key_formatter),
        route_formatter: @options.fetch(:route_formatter)
      )
    end

    def results_to_hash
      if @operation_results.has_errors?
        {errors: @operation_results.all_errors}
      else
        if @operation_results.results.length == 1
          result = @operation_results.results[0]

          case result
          when JSONAPI::ResourceOperationResult
            serializer.serialize_to_hash(result.resource)
          when JSONAPI::ResourcesOperationResult
            serializer.serialize_to_hash(result.resources)
          when JSONAPI::LinksObjectOperationResult
            serializer.serialize_to_links_hash(result.parent_resource,
                                                result.association)
          when JSONAPI::OperationResult
            {}
          end

        elsif @operation_results.results.length > 1
          resources = []
          @operation_results.results.each do |result|
            case result
            when JSONAPI::ResourceOperationResult
              resources.push(result.resource)
            when JSONAPI::ResourcesOperationResult
              resources.concat(result.resources)
            end
          end

          serializer.serialize_to_hash(resources)
        end
      end
    end
  end
end