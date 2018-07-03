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

    def find
      filters = params[:filters]
      include_directives = params[:include_directives]
      sort_criteria = params.fetch(:sort_criteria, [])
      paginator = params[:paginator]
      fields = params[:fields]
      serializer = params[:serializer]

      verified_filters = resource_klass.verify_filters(filters, context)

      find_options = {
        context: context,
        sort_criteria: sort_criteria,
        paginator: paginator,
        fields: fields,
        filters: verified_filters
      }

      resource_set = find_resource_set(resource_klass,
                                       include_directives,
                                       serializer,
                                       find_options)

      page_options = result_options
      if (JSONAPI.configuration.top_level_meta_include_record_count || (paginator && paginator.class.requires_record_count))
        page_options[:record_count] = resource_klass.count(verified_filters,
                                                           context: context,
                                                           include_directives: include_directives)
      end

      if (JSONAPI.configuration.top_level_meta_include_page_count && paginator && page_options[:record_count])
        page_options[:page_count] = paginator ? paginator.calculate_page_count(page_options[:record_count]) : 1
      end

      if JSONAPI.configuration.top_level_links_include_pagination && paginator
        page_options[:pagination_params] = paginator.links_page_params(page_options.merge(fetched_resources: resource_set))
      end

      return JSONAPI::ResourcesSetOperationResult.new(:ok, resource_set, page_options)
    end

    def show
      include_directives = params[:include_directives]
      fields = params[:fields]
      id = params[:id]
      serializer = params[:serializer]

      key = resource_klass.verify_key(id, context)

      find_options = {
        context: context,
        fields: fields,
        filters: { resource_klass._primary_key => key }
      }

      resource_set = find_resource_set(resource_klass,
                                       include_directives,
                                       serializer,
                                       find_options)

      return JSONAPI::ResourceSetOperationResult.new(:ok, resource_set, result_options)
    end

    def show_relationship
      parent_key = params[:parent_key]
      relationship_type = params[:relationship_type].to_sym
      paginator = params[:paginator]
      sort_criteria = params.fetch(:sort_criteria, [])
      include_directives = params[:include_directives]
      fields = params[:fields]

      parent_resource = resource_klass.find_by_key(parent_key, context: context)

      find_options = {
          context: context,
          sort_criteria: sort_criteria,
          paginator: paginator,
          fields: fields
      }

      resource_id_tree = find_related_resource_id_tree(resource_klass,
                                                       JSONAPI::ResourceIdentity.new(resource_klass, parent_key),
                                                       relationship_type,
                                                       find_options,
                                                       nil)

      return JSONAPI::LinksObjectOperationResult.new(:ok,
                                                     parent_resource,
                                                     resource_klass._relationship(relationship_type),
                                                     resource_id_tree[:resources].keys,
                                                     result_options)
    end

    def show_related_resource
      include_directives = params[:include_directives]
      source_klass = params[:source_klass]
      source_id = params[:source_id]
      relationship_type = params[:relationship_type]
      serializer = params[:serializer]
      fields = params[:fields]

      find_options = {
          context: context,
          fields: fields,
          filters: {}
      }

      source_resource = source_klass.find_by_key(source_id, context: context, fields: fields)

      resource_set = find_related_resource_set(source_resource,
                                               relationship_type,
                                               include_directives,
                                               serializer,
                                               find_options)

      return JSONAPI::ResourceSetOperationResult.new(:ok, resource_set, result_options)
    end

    def show_related_resources
      source_klass = params[:source_klass]
      source_id = params[:source_id]
      relationship_type = params[:relationship_type]
      filters = params[:filters]
      sort_criteria = params.fetch(:sort_criteria, resource_klass.default_sort)
      paginator = params[:paginator]
      fields = params[:fields]
      include_directives = params[:include_directives]
      serializer = params[:serializer]

      verified_filters = resource_klass.verify_filters(filters, context)

      find_options = {
        filters:  verified_filters,
        sort_criteria: sort_criteria,
        paginator: paginator,
        fields: fields,
        context: context
      }

      source_resource = source_klass.find_by_key(source_id, context: context, fields: fields)

      resource_set = find_related_resource_set(source_resource,
                                               relationship_type,
                                               include_directives,
                                               serializer,
                                               find_options)

      opts = result_options
      if ((JSONAPI.configuration.top_level_meta_include_record_count) ||
          (paginator && paginator.class.requires_record_count) ||
          (JSONAPI.configuration.top_level_meta_include_page_count))

        opts[:record_count] = source_resource.class.count_related(
            source_resource.identity,
            relationship_type,
            find_options)
      end

      if (JSONAPI.configuration.top_level_meta_include_page_count && opts[:record_count])
        opts[:page_count] = paginator.calculate_page_count(opts[:record_count])
      end

      opts[:pagination_params] = if paginator && JSONAPI.configuration.top_level_links_include_pagination
                                   page_options = {}
                                   page_options[:record_count] = opts[:record_count] if paginator.class.requires_record_count
                                   paginator.links_page_params(page_options.merge(fetched_resources: resource_set))
                                 else
                                   {}
                                 end

      return JSONAPI::RelatedResourcesSetOperationResult.new(:ok,
                                                             source_resource,
                                                             relationship_type,
                                                             resource_set,
                                                             opts)
    end

    def create_resource
      include_directives = params[:include_directives]
      fields = params[:fields]
      serializer = params[:serializer]

      data = params[:data]
      resource = resource_klass.create(context)
      result = resource.replace_fields(data)

      find_options = {
          context: context,
          fields: fields,
          filters: { resource_klass._primary_key => resource.id }
      }

      resource_set = find_resource_set(resource_klass,
                                       include_directives,
                                       serializer,
                                       find_options)


      return JSONAPI::ResourceSetOperationResult.new((result == :completed ? :created : :accepted), resource_set, result_options)
    end

    def remove_resource
      resource_id = params[:resource_id]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.remove

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted, result_options)
    end

    def replace_fields
      resource_id = params[:resource_id]
      include_directives = params[:include_directives]
      fields = params[:fields]
      serializer = params[:serializer]

      data = params[:data]

      resource = resource_klass.find_by_key(resource_id, context: context)

      result = resource.replace_fields(data)

      find_options = {
          context: context,
          fields: fields,
          filters: { resource_klass._primary_key => resource.id }
      }

      resource_set = find_resource_set(resource_klass,
                                       include_directives,
                                       serializer,
                                       find_options)

      return JSONAPI::ResourceSetOperationResult.new((result == :completed ? :ok : :accepted), resource_set, result_options)
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

    def result_options
      options = {}
      options[:warnings] = params[:warnings] if params[:warnings]
      options
    end

    def find_resource_set(resource_klass, include_directives, serializer, options)
      include_related = include_directives.include_directives[:include_related] if include_directives

      resource_id_tree = find_resource_id_tree(resource_klass, options, include_related)

      # Generate a set of resources that can be used to turn the resource_id_tree into a result set
      resource_set = flatten_resource_id_tree(resource_id_tree)

      populate_resource_set(resource_set, serializer, options)

      resource_set
    end

    def find_related_resource_set(resource, relationship_name, include_directives, serializer, options)
      include_related = include_directives.include_directives[:include_related] if include_directives

      resource_id_tree = find_resource_id_tree_from_resource_relationship(resource, relationship_name, options, include_related)

      # Generate a set of resources that can be used to turn the resource_id_tree into a result set
      resource_set = flatten_resource_id_tree(resource_id_tree)

      populate_resource_set(resource_set, serializer, options)

      resource_set
    end

    def find_related_resource_id_tree(resource_klass, source_id, relationship_name, find_options, include_related)
      options = find_options.except(:include_directives)
      options[:cache] = resource_klass.caching?

      relationship = resource_klass._relationship(relationship_name)

      resources = {}

      identities = resource_klass.find_related_fragments([source_id], relationship_name, options)

      identities.each do |identity, value|
        resources[identity] = { id: identity,
                                resource_klass: relationship.resource_klass,
                                primary: true, relationships: {}
        }

        if resource_klass.caching?
          resources[identity][:cache_field] = value[:cache]
        end
      end

      included_relationships = get_related(relationship.resource_klass, resources, include_related, options)

      { resources: resources, included: included_relationships }
    end

    def find_resource_id_tree(resource_klass, find_options, include_related)
      options = find_options.except(:include_directives)
      options[:cache] = resource_klass.caching?
      resources = {}

      identities = resource_klass.find_fragments(find_options[:filters], options)
      identities.each do |identity, values|
        resources[identity] = { primary: true, relationships: {} }
        if resource_klass.caching?
          resources[identity][:cache_field] = values[:cache]
        end
      end

      included_relationships = get_related(resource_klass, resources, include_related, options.except(:filters, :sort_criteria))

      { resources: resources, included: included_relationships }
    end

    def find_resource_id_tree_from_resource_relationship(resource, relationship_name, find_options, include_related)
      relationship = resource.class._relationship(relationship_name)

      options = find_options.except(:include_directives)
      options[:cache] = relationship.resource_klass.caching?

      identities = resource.class.find_related_fragments([resource.identity], relationship_name, options)

      resources = {}

      identities.each do |identity, values|
        resources[identity] = { primary: true, relationships: {} }
        if relationship.resource_klass.caching?
          resources[identity][:cache_field] = values[:cache]
        end
      end

      options = options.except(:filters)

      included_relationships = get_related(resource_klass, resources, include_related, options)

      { resources: resources, included: included_relationships }
    end

    # Gets the related resource connections for the source resources
    # Note: source_resources must all be of the same type. This precludes includes through polymorphic
    # relationships. ToDo: Prevent this when parsing the includes
    def get_related(resource_klass, source_resources, include_related, options)
      source_rids = source_resources.keys

      related = {}

      include_related.try(:keys).try(:each) do |key|
        relationship = resource_klass._relationship(key)
        relationship_name = relationship.name.to_sym

        cache_related = relationship.resource_klass.caching?

        related[relationship_name] = {}
        related[relationship_name][:relationship] = relationship
        related[relationship_name][:resources] = {}

        find_related_resource_options = options.dup
        find_related_resource_options[:sort_criteria] = relationship.resource_klass.default_sort
        find_related_resource_options[:cache] = resource_klass.caching?

        related_identities = resource_klass.find_related_fragments(
          source_rids, relationship_name, find_related_resource_options, key
        )

        related_identities.each_pair do |identity, v|
          related[relationship_name][:resources][identity] =
              {
                  source_rids: v[:related][relationship_name],
                  relationships: {
                      relationship.parent_resource._type => { rids: v[:related][relationship_name] }
                  }
              }

          if cache_related
            related[relationship_name][:resources][identity][:cache_field] = v[:cache]
          end
        end

        related[relationship_name][:resources].each do |related_rid, related_resource|
          # add linkage to source records
          related_resource[:source_rids].each do |id|
            source_resource = source_resources[id]
            source_resource[:relationships][relationship_name] ||= { rids: [] }
            source_resource[:relationships][relationship_name][:rids] << related_rid
          end
        end

        # Now get the related resources for the currently found resources
        included_resources = get_related(relationship.resource_klass,
                                         related[relationship_name][:resources],
                                         include_related[relationship_name][:include_related],
                                         options)

        related[relationship_name][:included] = included_resources
      end

      related
    end

    # flatten the resource id tree into groupings by resource klass
    def flatten_resource_id_tree(resource_id_tree, flattened_tree = {})
      resource_id_tree[:resources].each_pair do |resource_rid, resource_details|

        resource_klass = resource_rid.resource_klass
        id = resource_rid.id

        flattened_tree[resource_klass] ||= {}

        flattened_tree[resource_klass][id] ||= { primary: resource_details[:primary], relationships: {} }
        flattened_tree[resource_klass][id][:cache_id] ||= resource_details[:cache_field]

        resource_details[:relationships].try(:each_pair) do |relationship_name, details|
          flattened_tree[resource_klass][id][:relationships][relationship_name] ||= { rids: [] }

          if details[:rids] && details[:rids].is_a?(Array)
            details[:rids].each do |related_rid|
              flattened_tree[resource_klass][id][:relationships][relationship_name][:rids] << related_rid
            end
          end
        end
      end

      included = resource_id_tree[:included]
      included.try(:each_value) do |i|
        flatten_resource_id_tree(i, flattened_tree)
      end

      flattened_tree
    end

    def populate_resource_set(resource_set, serializer, find_options)

      resource_set.each_key do |resource_klass|
        missed_ids = []

        serializer_config_key = serializer.config_key(resource_klass).gsub("/", "_")
        context_json = resource_klass.attribute_caching_context(context).to_json
        context_b64 = JSONAPI.configuration.resource_cache_digest_function.call(context_json)
        context_key = "ATTR-CTX-#{context_b64.gsub("/", "_")}"

        if resource_klass.caching?
          cache_ids = []

          resource_set[resource_klass].each_pair do |k, v|
            # Store the hashcode of the cache_field to avoid storing objects and to ensure precision isn't lost
            # on timestamp types (i.e. string conversions dropping milliseconds)
            cache_ids.push([k, resource_klass.hash_cache_field(v[:cache_id])])
          end

          found_resources = CachedResponseFragment.fetch_cached_fragments(
              resource_klass,
              serializer_config_key,
              cache_ids,
              context)

          found_resources.each do |found_result|
            resource = found_result[1]
            if resource.nil?
              missed_ids.push(found_result[0])
            else
              resource_set[resource_klass][resource.id][:resource] = resource
            end
          end
        else
          missed_ids = resource_set[resource_klass].keys
        end

        # fill in the missed resources, it there are any
        unless missed_ids.empty?
          filters = {resource_klass._primary_key => missed_ids}
          find_opts = {
              context: context,
              fields: find_options[:fields] }

          found_resources = resource_klass.find(filters, find_opts)

          found_resources.each do |resource|
            relationship_data = resource_set[resource_klass][resource.id][:relationships]

            if resource_klass.caching?
              (id, cr) = CachedResponseFragment.write(
                  resource_klass,
                  resource,
                  serializer,
                  serializer_config_key,
                  context,
                  context_key,
                  relationship_data)

              resource_set[resource_klass][id][:resource] = cr
            else
              resource_set[resource_klass][resource.id][:resource] = resource
            end
          end
        end
      end
    end
  end
end
