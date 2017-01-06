module JSONAPI
  class ResponseDocument
    attr_reader :serialized_results

    def initialize(options = {})
      @serialized_results = []
      @result_codes = []
      @error_results = []
      @global_errors = []

      @options = options

      @top_level_meta = @options.fetch(:base_meta, {})
      @top_level_links = @options.fetch(:base_links, {})

      @key_formatter = @options.fetch(:key_formatter, JSONAPI.configuration.key_formatter)
      @content_type = @options.fetch(:content_type, JSONAPI::MEDIA_TYPE)
    end

    def has_errors?
      @error_results.length > 0 || @global_errors.length > 0
    end

    def add_top_level_meta(meta)
      @top_level_meta.merge!(meta)
    end

    def add_result(result, operation)
      if @content_type == JSONAPI::OPERATIONS_MEDIA_TYPE
        if result.is_a?(JSONAPI::ErrorsOperationResult)
          # Clear any serialized results
          @serialized_results = []
          @error_results.push result.to_hash
          @result_codes.push result.code.to_i
        else
          @result_codes.push result.code.to_i

          result_hash = result.to_hash(operation.options[:serializer])
          result_hash['meta'] = result.meta.as_json.deep_transform_keys { |key| @key_formatter.format(key) } unless result.meta.empty?
          result_hash['links'] = result.links.as_json.deep_transform_keys { |key| @key_formatter.format(key) } unless result.links.empty?

          @serialized_results.push result_hash
        end
      else
        if result.is_a?(JSONAPI::ErrorsOperationResult)
          # Clear any serialized results
          @serialized_results = []

          # In JSONAPI v1 we only have one operation so all errors can be kept together
          result.errors.each do |error|
            add_global_error(error)
          end
        else
          @serialized_results.push result.to_hash(operation.options[:serializer])
          @result_codes.push result.code.to_i
          update_links(operation.options[:serializer], result)
          update_meta(result)
        end
      end
    end

    def add_global_error(error)
      @global_errors.push error
    end

    def contents
      if @content_type == JSONAPI::OPERATIONS_MEDIA_TYPE
        if has_errors?
          errors = []

          @error_results.each do |error|
            errors.concat (error[:errors])
          end
          return { 'errors' => errors }
        else
          return { 'operations' => @serialized_results }
        end
      else
        if has_errors?
          return { 'errors' => @global_errors }
        else
          hash = @serialized_results[0]
          meta = top_level_meta
          hash.merge!('meta' => meta) unless meta.empty?

          links = top_level_links
          hash.merge!('links' => links) unless links.empty?

          return hash
        end
      end
    end

    def status
      status_codes = if has_errors?
                       @global_errors.collect do |error|
                         error.status.to_i
                       end
                     else
                       @result_codes
                     end

      # Count the unique status codes
      counts = status_codes.each_with_object(Hash.new(0)) { |code, counts| counts[code] += 1 }

      # if there is only one status code we can return that
      return counts.keys[0].to_i if counts.length == 1

      # if there are many we should return the highest general code, 200, 400, 500 etc.
      max_status = 0
      status_codes.each do |status|
        code = status.to_i
        max_status = code if max_status < code
      end
      return (max_status / 100).floor * 100
    end

    #
    # def status_sym
    #   Rack::Utils::HTTP_STATUS_CODES[status].downcase.gsub(/\s|-|'/, '_').to_sym
    # end

    private

    def update_meta(result)
      @top_level_meta.merge!(result.meta)

      unless @content_type == JSONAPI::OPERATIONS_MEDIA_TYPE
        if JSONAPI.configuration.top_level_meta_include_record_count && result.respond_to?(:record_count)
          @top_level_meta[JSONAPI.configuration.top_level_meta_record_count_key] = result.record_count
        end

        if JSONAPI.configuration.top_level_meta_include_page_count && result.respond_to?(:page_count)
          @top_level_meta[JSONAPI.configuration.top_level_meta_page_count_key] = result.page_count
        end

        if result.warnings.any?
          @top_level_meta[:warnings] = result.warnings.collect do |warning|
            warning.to_hash
          end
        end
      end
    end

    def top_level_meta
      @top_level_meta.as_json.deep_transform_keys { |key| @key_formatter.format(key) }
    end

    def update_links(serializer, result)
      @top_level_links.merge!(result.links)

      unless @content_type == JSONAPI::OPERATIONS_MEDIA_TYPE
        # Build pagination links
        if result.is_a?(JSONAPI::ResourcesOperationResult) || result.is_a?(JSONAPI::RelatedResourcesOperationResult)
          result.pagination_params.each_pair do |link_name, params|
            if result.is_a?(JSONAPI::RelatedResourcesOperationResult)
              relationship = result.source_resource.class._relationships[result._type.to_sym]
              @top_level_links[link_name] = serializer.link_builder.relationships_related_link(result.source_resource, relationship, query_params(params))
            else
              @top_level_links[link_name] = serializer.query_link(query_params(params))
            end
          end
        end
      end
    end

    def top_level_links
      @top_level_links.deep_transform_keys { |key| @key_formatter.format(key) }
    end

    def query_params(params)
      query_params = {}
      query_params[:page] = params

      request = @options[:request]
      if request.params[:fields]
        query_params[:fields] = request.params[:fields].respond_to?(:to_unsafe_hash) ? request.params[:fields].to_unsafe_hash : request.params[:fields]
      end

      query_params[:include] = request.params[:include] if request.params[:include]
      query_params[:sort] = request.params[:sort] if request.params[:sort]

      if request.params[:filter]
        query_params[:filter] = request.params[:filter].respond_to?(:to_unsafe_hash) ? request.params[:filter].to_unsafe_hash : request.params[:filter]
      end

      query_params
    end
  end
end