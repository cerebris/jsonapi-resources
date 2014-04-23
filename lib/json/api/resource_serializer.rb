module JSON
  module API
    class ResourceSerializer

      # Serializes a single resource, or an array of resources
      # Valid options are:
      # - include:
      #     Purpose: determines which objects will be side loaded with the source objects in a linked section
      #     Example: ['comments','author','comments.tags','author.posts']
      # - fields:
      #     Purpose: determines which fields are serialized for a resource type. This encompasses both attributes and
      #              association ids in the links section for a resource. Fields are global for a resource type.
      #     Example: { people: [:id, :email, :comments], posts: [:id, :title, :author], comments: [:id, :body, :post]}
      def serialize(source, options = {})
        @options = options
        @linked_objects = {}

        requested_associations = parse_includes(options[:include])

        if source.respond_to?(:to_ary)
          @primary_class_name = source[0].class.model_plural.downcase
        else
          @primary_class_name = source.class.model_plural.downcase
        end

        process_primary(source, requested_associations)

        primary_class_name = @primary_class_name.to_sym
        primary_hash = {primary_class_name => []}

        linked_hash = {}
        @linked_objects.each do |class_name, objects|
          class_name = class_name.to_sym

          linked = []
          objects.each_value do |object|
            if object[:primary]
              primary_hash[primary_class_name].push(object[:object_hash])
            else
              linked.push(object[:object_hash])
            end
          end
          linked_hash[class_name] = linked unless linked.empty?
        end

        if linked_hash.size > 0
          primary_hash.merge!({linked: linked_hash})
        end

        return primary_hash
      end

      # Convert an array of associated objects to include along with the primary document in the form of
      # ['comments','author','comments.tags','author.posts'] into a structure that tells what we need to include
      # from each association.
      def parse_includes(includes)
        requested_associations = {}
        includes.each do |include|
          include = include.to_s  if include.is_a? Symbol

          pos = include.index('.')
          if pos
            association_name = include[0, pos].to_sym
            requested_associations[association_name] ||= {}
            requested_associations[association_name].store(:include_children, true)
            requested_associations[association_name].store(:include_related, parse_includes([include[pos+1, include.length]]))
          else
            association_name = include.to_sym
            requested_associations[association_name] ||= {}
            requested_associations[association_name].store(:include, true)
          end
        end if includes.is_a?(Array)
        return requested_associations
      end

      # Process the primary source object(s). This will then serialize associated object recursively based on the
      # requested includes. Fields are controlled fields option for each resource type, such
      # as fields: { people: [:id, :email, :comments], posts: [:id, :title, :author], comments: [:id, :body, :post]}
      # The fields options controls both fields and included links references.
      def process_primary(source, requested_associations)
        if source.respond_to?(:to_ary)
          source.each do |object|
            id = object.send(object.class.key)
            if already_serialized?(@primary_class_name, id)
              set_primary(@primary_class_name, id)
            end

            add_linked_object(@primary_class_name, id, object_hash(object,  requested_associations), true)
          end
        else
          id = source.send(source.class.key)
          if already_serialized?(@primary_class_name, id)
            set_primary(@primary_class_name, id)
          end

          add_linked_object(@primary_class_name, id, object_hash(source,  requested_associations), true)
        end
      end

      # Returns a serialized hash for the source object, with
      def object_hash(source, requested_associations)
        obj_hash = attribute_hash(source)
        links = links_hash(source, requested_associations)
        obj_hash.merge!({links: links}) unless links.empty?
        return obj_hash
      end

      def requested_fields(model)
        @options[:fields][model] if @options[:fields]
      end

      # Returns a hash of the requested attributes for a resource, filtered by the resource class's _fetchable method
      def attribute_hash(source)
        requested = requested_fields(source.class.plural_model_symbol)
        fields = source.class._attributes.dup
        unless requested.nil?
          fields = requested & fields
        end

        source._fetchable(fields).each_with_object({}) do |name, hash|
          hash[name] = source.send(name)
        end
      end

      # Returns a hash of links for the requested associations for a resource, filtered by the resource
      # class's _fetchable method
      def links_hash(source, requested_associations)
        associations = source.class._associations
        requested = requested_fields(source.class.plural_model_symbol)
        fields = associations.keys
        unless requested.nil?
          fields = requested & fields
        end

        field_set = Set.new(fields)

        included_associations = source._fetchable(associations.keys)
        associations.each_with_object({}) do |(name, association), hash|
          if included_associations.include? name
            key = association.key

            if field_set.include?(name)
              hash[name] = source.send(key)
            end

            ia = requested_associations.is_a?(Hash) ? requested_associations[name] : nil

            include_linked_object = ia && ia[:include]
            include_linked_children = ia && ia[:include_children]

            type = association.serialize_type_name

            # If the object has been serialized once it will be in the related objects list,
            # but it's possible all children won't have been captured. So we must still go
            # through the associations.
            if include_linked_object || include_linked_children
              if association.is_a?(JSON::API::Association::HasOne)
                object = source.send("_#{name}_object")

                id = object.send(association.primary_key)
                associations_only = already_serialized?(type, id)
                if include_linked_object && !associations_only
                  add_linked_object(type, id, object_hash(object, ia[:include_related]))
                elsif include_linked_children || associations_only
                  links_hash(object, ia[:include_related])
                end
              elsif association.is_a?(JSON::API::Association::HasMany)
                objects = source.send("_#{name}_objects")
                objects.each do |object|
                  id = object.send(association.primary_key)
                  associations_only = already_serialized?(type, id)
                  if include_linked_object && !associations_only
                    add_linked_object(type, id, object_hash(object, ia[:include_related]))
                  elsif include_linked_children || associations_only
                    links_hash(object, ia[:include_related])
                  end
                end
              end
            end
          end
        end
      end

      def already_serialized?(type, id)
        return @linked_objects.key?(type) && @linked_objects[type].key?(id)
      end

      # Sets that an object should be included in the primary document of the response.
      def set_primary(type, id)
        @linked_objects[type][id][:primary] = true
      end

      # Collects the hashes for all objects processed by the serializer
      def add_linked_object(type, id, object_hash, primary = false)
        unless @linked_objects.key?(type)
          @linked_objects[type] = {}
        end

        if already_serialized?(type, id)
          if primary
            set_primary(type, id)
          end
        else
          @linked_objects[type].store(id, {primary: primary, object_hash: object_hash})
        end
      end
    end
  end
end
