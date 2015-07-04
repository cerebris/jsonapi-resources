module JSONAPI
  class ResourceSerializer

    # Options can include
    # include:
    #     Purpose: determines which objects will be side loaded with the source objects in a linked section
    #     Example: ['comments','author','comments.tags','author.posts']
    # fields:
    #     Purpose: determines which fields are serialized for a resource type. This encompasses both attributes and
    #              association ids in the links section for a resource. Fields are global for a resource type.
    #     Example: { people: [:id, :email, :comments], posts: [:id, :title, :author], comments: [:id, :body, :post]}
    # key_formatter: KeyFormatter class to override the default configuration
    # base_url: a string to prepend to generated resource links

    def initialize(primary_resource_klass, options = {})
      @primary_resource_klass = primary_resource_klass
      @primary_class_name = @primary_resource_klass._type

      @fields =  options.fetch(:fields, {})
      @include = options.fetch(:include, [])
      @include_directives = options[:include_directives]
      @key_formatter = options.fetch(:key_formatter, JSONAPI.configuration.key_formatter)
      @route_formatter = options.fetch(:route_formatter, JSONAPI.configuration.route_formatter)
      @base_url = options.fetch(:base_url, '')
    end

    # Converts a single resource, or an array of resources to a hash, conforming to the JSONAPI structure
    def serialize_to_hash(source)
      is_resource_collection = source.respond_to?(:to_ary)

      @included_objects = {}
      @include_directives ||= JSONAPI::IncludeDirectives.new(@include)

      process_primary(source, @include_directives.include_directives)

      included_objects = []
      primary_objects = []
      @included_objects.each_value do |objects|
        objects.each_value do |object|
          if object[:primary]
            primary_objects.push(object[:object_hash])
          else
            included_objects.push(object[:object_hash])
          end
        end
      end

      primary_hash = {data: is_resource_collection ? primary_objects : primary_objects[0]}

      primary_hash[:included] = included_objects if included_objects.size > 0
      primary_hash
    end

    def serialize_to_links_hash(source, requested_association)
      if requested_association.is_a?(JSONAPI::Association::HasOne)
        data = has_one_linkage(source, requested_association)
      else
        data = has_many_linkage(source, requested_association)
      end

      {
        links: {
          self: self_link(source, requested_association),
          related: related_link(source, requested_association)
        },
        data: data
      }
    end

    def find_link(query_params)
      "#{@base_url}/#{formatted_module_path_from_klass(@primary_resource_klass)}#{@route_formatter.format(@primary_resource_klass._type.to_s)}?#{query_params.to_query}"
    end

    private
    # Process the primary source object(s). This will then serialize associated object recursively based on the
    # requested includes. Fields are controlled fields option for each resource type, such
    # as fields: { people: [:id, :email, :comments], posts: [:id, :title, :author], comments: [:id, :body, :post]}
    # The fields options controls both fields and included links references.
    def process_primary(source, include_directives)
      if source.respond_to?(:to_ary)
        source.each do |resource|
          id = resource.id
          if already_serialized?(@primary_class_name, id)
            set_primary(@primary_class_name, id)
          end

          add_included_object(@primary_class_name, id, object_hash(resource,  include_directives), true)
        end
      else
        return {} if source.nil?

        resource = source
        id = resource.id
        add_included_object(@primary_class_name, id, object_hash(source,  include_directives), true)
      end
    end

    # Returns a serialized hash for the source model
    def object_hash(source, include_directives)
      obj_hash = {}

      id_format = source.class._attribute_options(:id)[:format]
      #protect against ids that were declared as an attribute, but did not have a format set.
      id_format = 'id' if id_format == :default
      obj_hash['id'] = format_value(source.id, id_format)

      obj_hash['type'] = format_key(source.class._type.to_s)

      links = relationship_links(source)
      obj_hash['links'] = links unless links.empty?

      attributes = attribute_hash(source)
      obj_hash['attributes'] = attributes unless attributes.empty?

      relationships = relationship_data(source, include_directives)
      obj_hash['relationships'] = relationships unless relationships.nil? || relationships.empty?

      return obj_hash
    end

    def requested_fields(model)
      @fields[model] if @fields
    end

    def attribute_hash(source)
      requested = requested_fields(source.class._type)
      fields = source.fetchable_fields & source.class._attributes.keys.to_a
      unless requested.nil?
        fields = requested & fields
      end

      fields.each_with_object({}) do |name, hash|
        format = source.class._attribute_options(name)[:format]
        unless name == :id
          hash[format_key(name)] = format_value(source.send(name), format)
        end
      end
    end

    def relationship_data(source, include_directives)
      associations = source.class._associations
      requested = requested_fields(source.class._type)
      fields = associations.keys
      unless requested.nil?
        fields = requested & fields
      end

      field_set = Set.new(fields)

      included_associations = source.fetchable_fields & associations.keys

      data = {}

      associations.each_with_object(data) do |(name, association), hash|
        if included_associations.include? name
          ia = include_directives[:include_related][name]

          include_linkage = ia && ia[:include]
          include_linked_children = ia && !ia[:include_related].empty?

          if field_set.include?(name)
            hash[format_key(name)] = link_object(source, association, include_linkage)
          end

          type = association.type

          # If the object has been serialized once it will be in the related objects list,
          # but it's possible all children won't have been captured. So we must still go
          # through the associations.
          if include_linkage || include_linked_children
            if association.is_a?(JSONAPI::Association::HasOne)
              resource = source.send(name)
              if resource
                id = resource.id
                associations_only = already_serialized?(type, id)
                if include_linkage && !associations_only
                  add_included_object(type, id, object_hash(resource, ia))
                elsif include_linked_children || associations_only
                  relationship_data(resource, ia)
                end
              end
            elsif association.is_a?(JSONAPI::Association::HasMany)
              resources = source.send(name)
              resources.each do |resource|
                id = resource.id
                associations_only = already_serialized?(type, id)
                if include_linkage && !associations_only
                  add_included_object(type, id, object_hash(resource, ia))
                elsif include_linked_children || associations_only
                  relationship_data(resource, ia)
                end
              end
            end
          end
        end
      end
    end

    def relationship_links(source)
      links = {}
      links[:self] = self_href(source)

      links
    end

    def formatted_module_path(source)
      formatted_module_path_from_klass(source.class)
    end

    def formatted_module_path_from_klass(klass)
      klass.name =~ /::[^:]+\Z/ ? (@route_formatter.format($`).freeze.gsub('::', '/') + '/').downcase : ''
    end

    def self_href(source)
      "#{@base_url}/#{formatted_module_path(source)}#{@route_formatter.format(source.class._type.to_s)}/#{source.id}"
    end

    def already_serialized?(type, id)
      type = format_key(type)
      return @included_objects.key?(type) && @included_objects[type].key?(id)
    end

    def format_route(route)
      @route_formatter.format(route.to_s)
    end

    def self_link(source, association)
      "#{self_href(source)}/relationships/#{format_route(association.name)}"
    end

    def related_link(source, association)
      "#{self_href(source)}/#{format_route(association.name)}"
    end

    def has_one_linkage(source, association)
      linkage = {}
      linkage_id = foreign_key_value(source, association)
      if linkage_id
        linkage[:type] = format_key(association.type)
        linkage[:id] = linkage_id
      else
        linkage = nil
      end
      linkage
    end

    def has_many_linkage(source, association)
      linkage = []
      linkage_ids = foreign_key_value(source, association)
      linkage_ids.each do |linkage_id|
        linkage.append({type: format_key(association.type), id: linkage_id})
      end
      linkage
    end

    def link_object_has_one(source, association)
      link_object_hash = {}
      link_object_hash[:links] = {}
      link_object_hash[:links][:self] = self_link(source, association)
      link_object_hash[:links][:related] = related_link(source, association)
      link_object_hash[:data] = has_one_linkage(source, association)
      link_object_hash
    end

    def link_object_has_many(source, association, include_linkage)
      link_object_hash = {}
      link_object_hash[:links] = {}
      link_object_hash[:links][:self] = self_link(source, association)
      link_object_hash[:links][:related] = related_link(source, association)
      link_object_hash[:data] = has_many_linkage(source, association) if include_linkage
      link_object_hash
    end

    def link_object(source, association, include_linkage = false)
      if association.is_a?(JSONAPI::Association::HasOne)
        link_object_has_one(source, association)
      elsif association.is_a?(JSONAPI::Association::HasMany)
        link_object_has_many(source, association, include_linkage)
      end
    end

    # Extracts the foreign key value for an association.
    def foreign_key_value(source, association)
      foreign_key = association.foreign_key
      value = source.send(foreign_key)

      if association.is_a?(JSONAPI::Association::HasMany)
        value.map { |value| IdValueFormatter.format(value) }
      elsif association.is_a?(JSONAPI::Association::HasOne)
        IdValueFormatter.format(value)
      end
    end

    # Sets that an object should be included in the primary document of the response.
    def set_primary(type, id)
      type = format_key(type)
      @included_objects[type][id][:primary] = true
    end

    # Collects the hashes for all objects processed by the serializer
    def add_included_object(type, id, object_hash, primary = false)
      type = format_key(type)

      unless @included_objects.key?(type)
        @included_objects[type] = {}
      end

      if already_serialized?(type, id)
        if primary
          set_primary(type, id)
        end
      else
        @included_objects[type].store(id, {primary: primary, object_hash: object_hash})
      end
    end

    def format_key(key)
      @key_formatter.format(key)
    end

    def format_value(value, format)
      value_formatter = JSONAPI::ValueFormatter.value_formatter_for(format)
      value_formatter.format(value)
    end
  end
end
