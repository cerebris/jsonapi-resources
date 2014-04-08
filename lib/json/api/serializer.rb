module JSON
  module API
    module Serializer

      def as_json
        obj_hash = attribute_hash
        links = {links: links_hash}
        obj_hash.merge!(links)

        hash = {self.class.model_name.pluralize.downcase.to_sym => obj_hash}
      end

      def attribute_hash
        _fetchable(self.class._attributes.dup).each_with_object({}) do |name, hash|
          hash[name] = send(name)
        end
      end

      def associations
        _fetchable(self.class._associations.dup).each_with_object({}) do |name, hash|
          hash[name] = 'test'
        end
      end

      def links_hash
        associations = self.class._associations
        included_associations = _fetchable(associations.keys)

        associations.each_with_object({}) do |(name, association), hash|
          if included_associations.include? name
            key = association.key
            hash[name] = send(key)
          end
        end
      end

      def add_linked_object(type, object_hash)
        if @root_resource
          @root_resource.add_linked_object(type, object_hash)
        else
          @linked_object[type]
        end
      end
    end
  end
end