module JSONAPI
  class Processor
    include Callbacks
    define_jsonapi_resources_callbacks :find,
                                       :show,
                                       :show_relationship,
                                       :show_related_resource,
                                       :show_related_resources,
                                       :create_resource,
                                       :remove_resource,
                                       :replace_fields,
                                       :replace_to_one_relationship,
                                       :replace_polymorphic_to_one_relationship,
                                       :create_to_many_relationships,
                                       :replace_to_many_relationships,
                                       :remove_to_many_relationships,
                                       :remove_to_one_relationship,
                                       :operation

    class << self
      def processor_instance_for(resource_klass, operation_type, params)
        _processor_from_resource_type(resource_klass).new(resource_klass, operation_type, params)
      end

      def _processor_from_resource_type(resource_klass)
        processor = resource_klass.name.gsub(/Resource$/,'Processor').safe_constantize
        if processor.nil?
          processor = JSONAPI.configuration.default_processor_klass
        end

        return processor
      end
    end

    attr_reader :resource_klass, :operation_type, :params, :context, :result, :result_options

    def initialize(resource_klass, operation_type, params)
      @resource_klass = resource_klass
      @operation_type = operation_type
      @params = params
      @context = params[:context]
      @result = nil
      @result_options = {}
    end

    def process
      run_callbacks :operation do
        run_callbacks operation_type do
          @result = send(operation_type)
        end
      end

    rescue JSONAPI::Exceptions::Error => e
      @result = JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end

    def result_options
      options = {}
      options[:warnings] = params[:warnings] if params[:warnings]
      options
    end

    def find
      filters = params[:filters]
      include_directives = params[:include_directives]
      sort_criteria = params.fetch(:sort_criteria, [])
      paginator = params[:paginator]
      fields = params[:fields]

      verified_filters = resource_klass.verify_filters(filters, context)
      find_options = {
        context: context,
        include_directives: include_directives,
        sort_criteria: sort_criteria,
        paginator: paginator,
        fields: fields,
        caching: {
            cache_serializer_output: params[:cache_serializer_output],
            serializer: params[:serializer]
        }
      }

      resources = resource_klass.find(verified_filters, find_options)

      page_options = result_options
      if (JSONAPI.configuration.top_level_meta_include_record_count ||
        (paginator && paginator.class.requires_record_count))
        page_options[:record_count] = resource_klass.find_count(verified_filters,
                                                                context: context,
                                                                include_directives: include_directives)
      end

      if (JSONAPI.configuration.top_level_meta_include_page_count && page_options[:record_count])
        page_options[:page_count] = paginator ? paginator.calculate_page_count(page_options[:record_count]) : 1
      end

      if JSONAPI.configuration.top_level_links_include_pagination && paginator
        page_options[:pagination_params] = paginator.links_page_params(page_options.merge(fetched_resources: resources))
      end

      return JSONAPI::ResourcesOperationResult.new(:ok, resources, page_options)
    end

    def show
      include_directives = params[:include_directives]
      fields = params[:fields]
      id = params[:id]

      key = resource_klass.verify_key(id, context)

      find_options = {
        context: context,
        include_directives: include_directives,
        fields: fields,
        caching: {
            cache_serializer_output: params[:cache_serializer_output],
            serializer: params[:serializer]
        }
      }

      resource = resource_klass.find_by_key(key, find_options)

      return JSONAPI::ResourceOperationResult.new(:ok, resource, result_options)
    end

    def show_relationship
      parent_key = params[:parent_key]
      relationship_type = params[:relationship_type].to_sym

      parent_resource = resource_klass.find_by_key(parent_key, context: context)

      return JSONAPI::LinksObjectOperationResult.new(:ok,
                                                     parent_resource,
                                                     resource_klass._relationship(relationship_type),
                                                     result_options)
    end

    def show_related_resource
      source_klass = params[:source_klass]
      source_id = params[:source_id]
      relationship_type = params[:relationship_type].to_sym
      fields = params[:fields]

      # TODO Should fetch related_resource from cache if caching enabled
      source_resource = source_klass.find_by_key(source_id, context: context, fields: fields)

      related_resource = source_resource.public_send(relationship_type)

      return JSONAPI::ResourceOperationResult.new(:ok, related_resource, result_options)
    end

    def show_related_resources
      source_klass = params[:source_klass]
      source_id = params[:source_id]
      relationship_type = params[:relationship_type]
      filters = params[:filters]
      sort_criteria = params[:sort_criteria]
      paginator = params[:paginator]
      fields = params[:fields]
      include_directives = params[:include_directives]

      source_resource ||= source_klass.find_by_key(source_id, context: context, fields: fields)
      verified_filters = resource_klass.verify_filters(filters, context)

      rel_opts = {
        filters:  verified_filters,
        sort_criteria: sort_criteria,
        paginator: paginator,
        fields: fields,
        context: context,
        include_directives: include_directives,
        caching: {
            cache_serializer_output: params[:cache_serializer_output],
            serializer: params[:serializer]
        }
      }

      related_resources = source_resource.public_send(relationship_type, rel_opts)

      if ((JSONAPI.configuration.top_level_meta_include_record_count) ||
          (paginator && paginator.class.requires_record_count) ||
          (JSONAPI.configuration.top_level_meta_include_page_count))
        record_count = source_resource.count_for_relationship(relationship_type, rel_opts)
      end

      if (JSONAPI.configuration.top_level_meta_include_page_count && record_count)
        page_count = paginator.calculate_page_count(record_count)
      end

      pagination_params = if paginator && JSONAPI.configuration.top_level_links_include_pagination
                            page_options = {}
                            page_options[:record_count] = record_count if paginator.class.requires_record_count
                            paginator.links_page_params(page_options.merge(fetched_resources: related_resources))
                          else
                            {}
                          end

      opts = result_options
      opts.merge!(pagination_params: pagination_params) if JSONAPI.configuration.top_level_links_include_pagination
      opts.merge!(record_count: record_count) if JSONAPI.configuration.top_level_meta_include_record_count
      opts.merge!(page_count: page_count) if JSONAPI.configuration.top_level_meta_include_page_count

      return JSONAPI::RelatedResourcesOperationResult.new(:ok,
                                                          source_resource,
                                                          relationship_type,
                                                          related_resources,
                                                          opts)
    end

    def create_resource
      data = params[:data]
      resource = resource_klass.create(context)
      result = resource.replace_fields(data)

      return JSONAPI::ResourceOperationResult.new((result == :completed ? :created : :accepted), resource, result_options)
    end

    def remove_resource
      resource_id = params[:resource_id]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.remove

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted, result_options)
    end

    def replace_fields
      resource_id = params[:resource_id]
      data = params[:data]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.replace_fields(data)

      return JSONAPI::ResourceOperationResult.new(result == :completed ? :ok : :accepted, resource, result_options)
    end

    def replace_to_one_relationship
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      key_value = params[:key_value]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.replace_to_one_link(relationship_type, key_value)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted, result_options)
    end

    def replace_polymorphic_to_one_relationship
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      key_value = params[:key_value]
      key_type = params[:key_type]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.replace_polymorphic_to_one_link(relationship_type, key_value, key_type)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted, result_options)
    end

    def create_to_many_relationships
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      data = params[:data]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.create_to_many_links(relationship_type, data)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted, result_options)
    end

    def replace_to_many_relationships
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      data = params.fetch(:data)

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.replace_to_many_links(relationship_type, data)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted, result_options)
    end

    def remove_to_many_relationships
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      associated_keys = params[:associated_keys]

      resource = resource_klass.find_by_key(resource_id, context: context)

      complete = true
      associated_keys.each do |key|
        result = resource.remove_to_many_link(relationship_type, key)
        if complete && result != :completed
          complete = false
        end
      end
      return JSONAPI::OperationResult.new(complete ? :no_content : :accepted, result_options)
    end

    def remove_to_one_relationship
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.remove_to_one_link(relationship_type)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted, result_options)
    end
  end
end
