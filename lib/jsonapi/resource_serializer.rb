module JSONAPI
  class ResourceSerializer

    attr_reader :link_builder, :key_formatter, :serialization_options,
                :fields, :include_directives, :always_include_to_one_linkage_data,
                :always_include_to_many_linkage_data

    # initialize
    # Options can include
    # include:
    #     Purpose: determines which objects will be side loaded with the source objects in a linked section
    #     Example: ['comments','author','comments.tags','author.posts']
    # fields:
    #     Purpose: determines which fields are serialized for a resource type. This encompasses both attributes and
    #              relationship ids in the links section for a resource. Fields are global for a resource type.
    #     Example: { people: [:id, :email, :comments], posts: [:id, :title, :author], comments: [:id, :body, :post]}
    # key_formatter: KeyFormatter instance to override the default configuration
    # serialization_options: additional options that will be passed to resource meta and links lambdas

    def initialize(primary_resource_klass, options = {})
      @primary_resource_klass = primary_resource_klass
      @fields                 = options.fetch(:fields, {})
      @include                = options.fetch(:include, [])
      @include_directives     = options[:include_directives]
      @include_directives     ||= JSONAPI::IncludeDirectives.new(@primary_resource_klass, @include)
      @key_formatter          = options.fetch(:key_formatter, JSONAPI.configuration.key_formatter)
      @id_formatter           = ValueFormatter.value_formatter_for(:id)
      @link_builder           = generate_link_builder(primary_resource_klass, options)
      @always_include_to_one_linkage_data = options.fetch(:always_include_to_one_linkage_data,
                                                          JSONAPI.configuration.always_include_to_one_linkage_data)
      @always_include_to_many_linkage_data = options.fetch(:always_include_to_many_linkage_data,
                                                           JSONAPI.configuration.always_include_to_many_linkage_data)
      @serialization_options = options.fetch(:serialization_options, {})

      # Warning: This makes ResourceSerializer non-thread-safe. That's not a problem with the
      # request-specific way it's currently used, though.
      @value_formatter_type_cache = NaiveCache.new{|arg| ValueFormatter.value_formatter_for(arg) }

      @_config_keys = {}
      @_supplying_attribute_fields = {}
      @_supplying_relationship_fields = {}
    end

    # Converts a resource_set to a hash, conforming to the JSONAPI structure
    def serialize_resource_set_to_hash(result_set)

      primary_objects = []
      included_objects = []

      result_set.each_value do |values|
        values.each_value do |value|
          serialized_result = object_hash(value[:resource], value[:relationships])

          if value[:primary]
            primary_objects.push(serialized_result)
          else
            included_objects.push(serialized_result)
          end
        end
      end

      fail "To Many primary objects for show" if (primary_objects.count > 1)
      primary_hash = { 'data' => primary_objects[0] }

      primary_hash['included'] = included_objects if included_objects.size > 0
      primary_hash
    end

    def serialize_resources_set_to_hash(result_set)

      primary_objects = []
      included_objects = []

      result_set.each_value do |resources|
        resources.each_value do |resource|
          serialized_result = object_hash(resource[:resource], resource[:relationships])

          if resource[:primary]
            primary_objects.push(serialized_result)
          else
            included_objects.push(serialized_result)
          end
        end
      end

      primary_hash = { 'data' => primary_objects }

      primary_hash['included'] = included_objects if included_objects.size > 0
      primary_hash
    end

    def serialize_related_resources_set_to_hash(source_resource, result_set)

      primary_objects = []
      included_objects = []

      result_set.each_value do |values|
        values.each_value do |value|
          serialized_result = object_hash(value[:resource], value[:relationships])

          if value[:primary]
            primary_objects.push(serialized_result)
          else
            included_objects.push(serialized_result)
          end
        end
      end

      primary_hash = { 'data' => primary_objects }

      primary_hash['included'] = included_objects if included_objects.size > 0
      primary_hash
    end

    def serialize_to_links_hash(source, requested_relationship, resource_ids)
      if requested_relationship.is_a?(JSONAPI::Relationship::ToOne)
        data = to_one_linkage(resource_ids[0])
      else
        data = to_many_linkage(resource_ids)
      end

      {
          'links' => {
              'self' => self_link(source, requested_relationship),
              'related' => related_link(source, requested_relationship)
          },
          'data' => data
      }
    end

    def query_link(query_params)
      link_builder.query_link(query_params)
    end

    def format_key(key)
      @key_formatter.format(key)
    end

    def unformat_key(key)
      @key_formatter.unformat(key)
    end

    def format_value(value, format)
      @value_formatter_type_cache.get(format).format(value)
    end

    def config_key(resource_klass)
      @_config_keys.fetch resource_klass do
        desc = self.config_description(resource_klass).map(&:inspect).join(",")
        key = JSONAPI.configuration.resource_cache_digest_function.call(desc)
        @_config_keys[resource_klass] = "SRLZ-#{key}"
      end
    end

    def config_description(resource_klass)
      {
        class_name: self.class.name,
        seriserialization_options: serialization_options.sort.map(&:as_json),
        supplying_attribute_fields: supplying_attribute_fields(resource_klass).sort,
        supplying_relationship_fields: supplying_relationship_fields(resource_klass).sort,
        link_builder_base_url: link_builder.base_url,
        route_formatter_class: link_builder.route_formatter.uncached.class.name,
        key_formatter_class: key_formatter.uncached.class.name,
        always_include_to_one_linkage_data: always_include_to_one_linkage_data,
        always_include_to_many_linkage_data: always_include_to_many_linkage_data
      }
    end

    def object_hash(source, relationship_data)
      obj_hash = {}

      return obj_hash if source.nil?

      fetchable_fields = Set.new(source.fetchable_fields)

      if source.is_a?(JSONAPI::CachedResponseFragment)
        id_format = source.resource_klass._attribute_options(:id)[:format]

        id_format = 'id' if id_format == :default
        obj_hash['id'] = format_value(source.id, id_format)
        obj_hash['type'] = source.type

        obj_hash['links'] = source.links_json if source.links_json
        obj_hash['attributes'] = source.attributes_json if source.attributes_json

        relationships = cached_relationships_hash(source, fetchable_fields, relationship_data)
        obj_hash['relationships'] = relationships unless relationships.nil? || relationships.empty?

        obj_hash['meta'] = source.meta_json if source.meta_json
      else
        # TODO Should this maybe be using @id_formatter instead, for consistency?
        id_format = source.class._attribute_options(:id)[:format]
        # protect against ids that were declared as an attribute, but did not have a format set.
        id_format = 'id' if id_format == :default
        obj_hash['id'] = format_value(source.id, id_format)

        obj_hash['type'] = format_key(source.class._type.to_s)

        links = links_hash(source)
        obj_hash['links'] = links unless links.empty?

        attributes = attributes_hash(source, fetchable_fields)
        obj_hash['attributes'] = attributes unless attributes.empty?

        relationships = relationships_hash(source, fetchable_fields, relationship_data)
        obj_hash['relationships'] = relationships unless relationships.nil? || relationships.empty?

        meta = meta_hash(source)
        obj_hash['meta'] = meta unless meta.empty?
      end

      obj_hash
    end

    private

    def supplying_attribute_fields(resource_klass)
      @_supplying_attribute_fields.fetch resource_klass do
        attrs = Set.new(resource_klass._attributes.keys.map(&:to_sym))
        cur = resource_klass
        while cur != JSONAPI::Resource
          if @fields.has_key?(cur._type)
            attrs &= @fields[cur._type]
            break
          end
          cur = cur.superclass
        end
        @_supplying_attribute_fields[resource_klass] = attrs
      end
    end

    def supplying_relationship_fields(resource_klass)
      @_supplying_relationship_fields.fetch resource_klass do
        relationships = Set.new(resource_klass._relationships.keys.map(&:to_sym))
        cur = resource_klass
        while cur != JSONAPI::Resource
          if @fields.has_key?(cur._type)
            relationships &= @fields[cur._type]
            break
          end
          cur = cur.superclass
        end
        @_supplying_relationship_fields[resource_klass] = relationships
      end
    end

    def attributes_hash(source, fetchable_fields)
      fields = fetchable_fields & supplying_attribute_fields(source.class)
      fields.each_with_object({}) do |name, hash|
        unless name == :id
          format = source.class._attribute_options(name)[:format]
          hash[format_key(name)] = format_value(source.public_send(name), format)
        end
      end
    end

    def custom_generation_options
      {
        serializer: self,
        serialization_options: @serialization_options
      }
    end

    def meta_hash(source)
      meta = source.meta(custom_generation_options)
      (meta.is_a?(Hash) && meta) || {}
    end

    def links_hash(source)
      links = custom_links_hash(source)
      links['self'] = link_builder.self_link(source) unless links.key?('self')
      links.compact
    end

    def custom_links_hash(source)
      custom_links = source.custom_links(custom_generation_options)
      (custom_links.is_a?(Hash) && custom_links) || {}
    end

    def relationships_hash(source, fetchable_fields, relationship_data)
      relationships = source.class._relationships.select{|k,_v| fetchable_fields.include?(k) }
      field_set = supplying_relationship_fields(source.class) & relationships.keys

      relationships.each_with_object({}) do |(name, relationship), hash|
        if field_set.include?(name)
          if relationship_data[name]
            if relationship.is_a?(JSONAPI::Relationship::ToOne)
              rids = relationship_data[name][:rids].first
            else
              rids = relationship_data[name][:rids]
            end
          end

          hash[format_key(name)] = link_object(source, relationship, rids)
        end
      end
    end

    def cached_relationships_hash(source, fetchable_fields, relationship_data)
      relationships = {}

      source.relationships.try(:each_pair) do |k,v|
        if fetchable_fields.include?(unformat_key(k).to_sym)
          relationships[k.to_sym] = v
        end
      end

      field_set = supplying_relationship_fields(source.resource_klass).collect {|k| format_key(k).to_sym } & relationships.keys

      relationships.each_with_object({}) do |(name, relationship), hash|
        if field_set.include?(name)

          relationship_name = unformat_key(name).to_sym
          relationship_klass = source.resource_klass._relationships[relationship_name]

          if relationship_klass.is_a?(JSONAPI::Relationship::ToOne)
            # include_linkage = @always_include_to_one_linkage_data | relationship_klass.always_include_linkage_data
            if relationship_data[relationship_name]
              rids = relationship_data[relationship_name][:rids].first
              include_linkage = rids
              relationship['data'] = to_one_linkage(rids) if include_linkage
            end
          else
            # include_linkage = relationship_klass.always_include_linkage_data
            if relationship_data[relationship_name]
              rids = relationship_data[relationship_name][:rids]
              include_linkage = !(rids.nil? || rids.empty?)
              relationship['data'] = to_many_linkage(rids) if include_linkage
            end
          end

          hash[format_key(name)] = relationship
        end
      end
    end

    def self_link(source, relationship)
      link_builder.relationships_self_link(source, relationship)
    end

    def related_link(source, relationship)
      link_builder.relationships_related_link(source, relationship)
    end

    def to_many_linkage(rids)
      linkage = []

      rids.each do |details|
        id = details.id
        type = details.resource_klass.try(:_type)
        if type && id
          linkage.append({'type' => format_key(type), 'id' => @id_formatter.format(id)})
        end
      end

      linkage
    end

    def to_one_linkage(rid)
      return unless rid

      {
          'type' => format_key(rid.resource_klass._type),
          'id' => @id_formatter.format(rid.id),
      }
    end

    def link_object_to_one(source, relationship, rid)
      # include_linkage = @always_include_to_one_linkage_data | relationship.always_include_linkage_data
      include_linkage = rid
      link_object_hash = {}
      link_object_hash['links'] = {}
      link_object_hash['links']['self'] = self_link(source, relationship)
      link_object_hash['links']['related'] = related_link(source, relationship)
      link_object_hash['data'] = to_one_linkage(rid) if include_linkage
      link_object_hash
    end

    def link_object_to_many(source, relationship, rids)
      # include_linkage = relationship.always_include_linkage_data
      include_linkage = rids && !rids.empty?
      link_object_hash = {}
      link_object_hash['links'] = {}
      link_object_hash['links']['self'] = self_link(source, relationship)
      link_object_hash['links']['related'] = related_link(source, relationship)
      link_object_hash['data'] = to_many_linkage(rids) if include_linkage
      link_object_hash
    end

    def link_object(source, relationship, rid)
      if relationship.is_a?(JSONAPI::Relationship::ToOne)
        link_object_to_one(source, relationship, rid)
      elsif relationship.is_a?(JSONAPI::Relationship::ToMany)
        link_object_to_many(source, relationship, rid)
      end
    end

    def generate_link_builder(primary_resource_klass, options)
      LinkBuilder.new(
        base_url: options.fetch(:base_url, ''),
        route_formatter: options.fetch(:route_formatter, JSONAPI.configuration.route_formatter),
        primary_resource_klass: primary_resource_klass,
      )
    end
  end
end
