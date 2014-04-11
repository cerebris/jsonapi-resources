module JSON
  module API
    module Serializer

      def as_json
        hash = {self.class.model_name.pluralize.downcase.to_sym => object_hash}

        linked_hash = {}
        @linked_objects.each_key do |class_name|
          linked_hash[class_name.to_sym] = @linked_objects[class_name].values
        end

        if linked_hash.size > 0
          hash.merge!({linked: linked_hash})
        end

        return hash
      end

      def object_hash
        obj_hash = attribute_hash
        links = links_hash
        obj_hash.merge!({links: links}) unless links.empty?
        return obj_hash
      end

      def attribute_hash
        _fetchable(self.class._attributes.dup).each_with_object({}) do |name, hash|
          hash[name] = send(name)
        end
      end

      def links_hash
        associations = self.class._associations
        included_associations = _fetchable(associations.keys)

        associations.each_with_object({}) do |(name, association), hash|
          if included_associations.include? name
            key = association.key
            hash[name] = send(key)

            if association.is_a?(JSON::API::Association::HasOne)
              object_method_name = "_#{name}_object"
            elsif association.is_a?(JSON::API::Association::HasMany)
              object_method_name = "_#{name}_objects"
            end
            if self.class.method_defined?(object_method_name)
              ia = @included_associations[name]
              if ia && (ia[:include] || ia[:include_children])
                send object_method_name, @root_resource, include: ia[:include_related], skip_object: ((ia[:include].blank? || !ia[:include]) && ia[:include_children])
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