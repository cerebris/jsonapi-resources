module JSON
  module API
    class ResourceSerializer
      def serialize(source, options = {})
        @options = options
        @linked_objects = {}
        requested_associations = process_includes(options[:include])

        if source.respond_to?(:to_ary)
          class_name = source[0].class.model.pluralize.downcase.to_sym
        else
          class_name = source.class.model.pluralize.downcase.to_sym
        end

        hash = {class_name => object_array(source, requested_associations)}

        linked_hash = {}
        @linked_objects.each_key do |class_name|
          linked_hash[class_name.to_sym] = @linked_objects[class_name].values
        end

        if linked_hash.size > 0
          hash.merge!({linked: linked_hash})
        end

        return hash
      end

      def process_includes(includes)
        requested_associations = {}
        includes.split(/\s*,\s*/).each do |include|
          pos = include.index('.')
          if pos
            association_name = include[0, pos].to_sym
            requested_associations[association_name] ||= {}
            requested_associations[association_name].store(:include_children, true)
            requested_associations[association_name].store(:include_related, process_includes(include[pos+1, include.length]))
          else
            association_name = include.to_sym
            requested_associations[association_name] ||= {}
            requested_associations[association_name].store(:include, true)
          end
        end unless includes.blank?
        return requested_associations
      end

      def object_array(source, requested_associations)
        if source.respond_to?(:to_ary)
          a = []
          source.each do |object|
            a.push object_hash(object, requested_associations)
          end
          a
        else
          [object_hash(source, requested_associations)]
        end
      end

      def object_hash(source, requested_associations)
        obj_hash = attribute_hash(source)
        links = links_hash(source, requested_associations)
        obj_hash.merge!({links: links}) unless links.empty?
        return obj_hash
      end

      def attribute_hash(source)
        source._fetchable(source.class._attributes.dup).each_with_object({}) do |name, hash|
          hash[name] = source.send(name)
        end
      end

      def links_hash(source, requested_associations)
        associations = source.class._associations
        included_associations = source._fetchable(associations.keys)

        associations.each_with_object({}) do |(name, association), hash|
          if included_associations.include? name
            key = association.key
            hash[name] = source.send(key)
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

      def add_linked_object(type, id, object_hash)
        hash = @linked_objects[type].nil? ? {} : @linked_objects[type]
        hash.store(id, object_hash)
        @linked_objects[type] = hash
        @linked_objects
      end

    end
  end
end
