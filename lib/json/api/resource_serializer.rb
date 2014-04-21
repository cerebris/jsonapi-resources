module JSON
  module API
    class ResourceSerializer
      def serialize(source, options = {})
        @options = options
        @linked_objects = {}

        requested_associations = process_includes(options[:include])

        if source.respond_to?(:to_ary)
          @primary_class_name = source[0].class.model.pluralize.downcase
        else
          @primary_class_name = source.class.model.pluralize.downcase
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

      def process_includes(includes)
        requested_associations = {}
        includes.each do |include|
          include = include.to_s  if include.is_a? Symbol

          pos = include.index('.')
          if pos
            association_name = include[0, pos].to_sym
            requested_associations[association_name] ||= {}
            requested_associations[association_name].store(:include_children, true)
            requested_associations[association_name].store(:include_related, process_includes([include[pos+1, include.length]]))
          else
            association_name = include.to_sym
            requested_associations[association_name] ||= {}
            requested_associations[association_name].store(:include, true)
          end
        end if includes.is_a?(Array)
        return requested_associations
      end

      def process_primary(source, requested_associations)
        if source.respond_to?(:to_ary)
          source.each do |object|
            add_linked_object(@primary_class_name, object.send(object.class.key), object_hash(object,  requested_associations), true)
          end
        else
          add_linked_object(@primary_class_name, source.send(source.class.key), object_hash(source,  requested_associations), true)
        end
      end

      def object_hash(source, requested_associations)
        obj_hash = attribute_hash(source)
        links = links_hash(source, requested_associations)
        obj_hash.merge!({links: links}) unless links.empty?
        return obj_hash
      end

      def requested_fields(model)
        @options[:fields][model.downcase.pluralize.to_sym] if @options[:fields]
      end

      def attribute_hash(source)
        requested_fields = requested_fields(source.class.model)
        fields = source.class._attributes.dup
        unless requested_fields.nil?
          fields = requested_fields & fields
        end

        source._fetchable(fields).each_with_object({}) do |name, hash|
          hash[name] = source.send(name)
        end
      end

      def links_hash(source, requested_associations)
        associations = source.class._associations
        requested_fields = requested_fields(source.class.model)
        fields = associations.keys
        unless requested_fields.nil?
          fields = requested_fields & fields
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

            if association.is_a?(JSON::API::Association::HasOne)
              object = source.send("_#{name}_object")
              if include_linked_object
                add_linked_object(association.class_name.downcase.pluralize,
                                  object.send(association.primary_key),
                                  object_hash(object, ia[:include_related]))
              elsif include_linked_children
                links_hash(object, ia[:include_related])
              end
            elsif association.is_a?(JSON::API::Association::HasMany)
              objects = source.send("_#{name}_objects")
              objects.each do |object|
                if include_linked_object
                  add_linked_object(association.class_name.downcase.pluralize,
                                    object.send(association.primary_key),
                                    object_hash(object, ia[:include_related]))
                elsif include_linked_children
                  links_hash(object, ia[:include_related])
                end
              end
            end
          end
        end
      end

      def add_linked_object(type, id, object_hash, primary = false)
        unless @linked_objects.key?(type)
          @linked_objects[type] = {}
        end

        unless @linked_objects[type].key?(id)
          @linked_objects[type].store(id, {primary: primary, object_hash: object_hash})
        else
          if primary
            @linked_objects[type][id][:primary] = true
          end
        end
      end

    end
  end
end
