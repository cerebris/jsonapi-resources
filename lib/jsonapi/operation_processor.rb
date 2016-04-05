module JSONAPI
  class OperationProcessor
    class << self
      def operation_processor_instance_for(resource_klass, params)
        operation_processor_name = _operation_processor_from_resource_type(resource_klass)
        operation_processor = operation_processor_name.safe_constantize if operation_processor_name
        if operation_processor.nil?
          operation_processor = JSONAPI::OperationProcessor
        end
        operation_processor.new(resource_klass, params)
      end

      def _operation_processor_from_resource_type(resource_klass)
        resource_klass.name.gsub(/Resource$/,'OperationProcessor')
      end
    end

    attr_reader :resource_klass, :params, :context

    def initialize(resource_klass, params)
      @resource_klass = resource_klass
      @params = params
      @context = params[:context]
    end

    def find
      filters = params[:filters]
      include_directives = params[:include_directives]
      sort_criteria = params.fetch(:sort_criteria, [])
      paginator = params[:paginator]

      verified_filters = resource_klass.verify_filters(filters, context)
      resource_records = resource_klass.find(verified_filters,
                                             context: context,
                                             include_directives: include_directives,
                                             sort_criteria: sort_criteria,
                                             paginator: paginator)

      page_options = {}
      if (JSONAPI.configuration.top_level_meta_include_record_count ||
        (paginator && paginator.class.requires_record_count))
        page_options[:record_count] = resource_klass.find_count(verified_filters,
                                                                context: context,
                                                                include_directives: include_directives)
      end

      if (JSONAPI.configuration.top_level_meta_include_page_count && page_options[:record_count])
        page_options[:page_count] = paginator.calculate_page_count(page_options[:record_count])
      end

      if JSONAPI.configuration.top_level_links_include_pagination && paginator
        page_options[:pagination_params] = paginator.links_page_params(page_options)
      end

      return JSONAPI::ResourcesOperationResult.new(:ok,
                                                   resource_records,
                                                   page_options)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end

    def show
      include_directives = params[:include_directives]
      id = params[:id]

      key = resource_klass.verify_key(id, context)

      resource_record = resource_klass.find_by_key(key,
                                                   context: context,
                                                   include_directives: include_directives)

      return JSONAPI::ResourceOperationResult.new(:ok, resource_record)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end

    def show_relationship
      parent_key = params[:parent_key]
      relationship_type = params[:relationship_type].to_sym

      parent_resource = resource_klass.find_by_key(parent_key, context: context)

      return JSONAPI::LinksObjectOperationResult.new(:ok,
                                                     parent_resource,
                                                     resource_klass._relationship(relationship_type))
    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end

    def show_related_resource
      source_klass = params[:source_klass]
      source_id = params[:source_id]
      relationship_type = params[:relationship_type].to_sym

      source_resource = source_klass.find_by_key(source_id, context: context)

      related_resource = source_resource.public_send(relationship_type)

      return JSONAPI::ResourceOperationResult.new(:ok, related_resource)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end

    def show_related_resources
      source_klass = params[:source_klass]
      source_id = params[:source_id]
      relationship_type = params[:relationship_type]
      filters = params[:filters]
      sort_criteria = params[:sort_criteria]
      paginator = params[:paginator]

      source_resource ||= source_klass.find_by_key(source_id, context: context)

      related_resources = source_resource.public_send(relationship_type,
                                                      filters:  filters,
                                                      sort_criteria: sort_criteria,
                                                      paginator: paginator)

      if ((JSONAPI.configuration.top_level_meta_include_record_count) ||
          (paginator && paginator.class.requires_record_count) ||
          (JSONAPI.configuration.top_level_meta_include_page_count))
        related_resource_records = source_resource.public_send("records_for_" + relationship_type)
        records = resource_klass.filter_records(filters, {},
                                                related_resource_records)

        record_count = records.count(:all)
      end

      if (JSONAPI.configuration.top_level_meta_include_page_count && record_count)
        page_count = paginator.calculate_page_count(record_count)
      end

      pagination_params = if paginator && JSONAPI.configuration.top_level_links_include_pagination
                            page_options = {}
                            page_options[:record_count] = record_count if paginator.class.requires_record_count
                            paginator.links_page_params(page_options)
                          else
                            {}
                          end

      opts = {}
      opts.merge!(pagination_params: pagination_params) if JSONAPI.configuration.top_level_links_include_pagination
      opts.merge!(record_count: record_count) if JSONAPI.configuration.top_level_meta_include_record_count
      opts.merge!(page_count: page_count) if JSONAPI.configuration.top_level_meta_include_page_count

      return JSONAPI::RelatedResourcesOperationResult.new(:ok, source_resource, relationship_type, related_resources, opts)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end

    def create_resource
      data = params[:data]

      resource = resource_klass.create(context)
      result = resource.replace_fields(data)

      return JSONAPI::ResourceOperationResult.new((result == :completed ? :created : :accepted), resource)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end

    def remove_resource
      resource_id = params[:resource_id]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.remove

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end

    def replace_fields
      resource_id = params[:resource_id]
      data = params[:data]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.replace_fields(data)

      return JSONAPI::ResourceOperationResult.new(result == :completed ? :ok : :accepted, resource)
    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end

    def replace_to_one_relationship
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      key_value = params[:key_value]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.replace_to_one_link(relationship_type, key_value)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted)
    end

    def replace_polymorphic_to_one_relationship
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      key_value = params[:key_value]
      key_type = params[:key_type]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.replace_polymorphic_to_one_link(relationship_type, key_value, key_type)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted)
    end

    def create_to_many_relationship
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      data = params[:data]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.create_to_many_links(relationship_type, data)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted)
    end

    def replace_to_many_relationship
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      data = params.fetch(:data)

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.replace_to_many_links(relationship_type, data)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted)
    end

    def remove_to_many_relationship
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      associated_key = params[:associated_key]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.remove_to_many_link(relationship_type, associated_key)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted)
    end

    def remove_to_one_relationship
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.remove_to_one_link(relationship_type)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted)
    end
  end
end
