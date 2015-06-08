module JSONAPI
  # Serializer for associations
  class AssociationSerializer
    attr_reader :serializer
    attr_reader :association

    def initialize(association, serializer)
      @association = association
      @serializer = serializer
    end

    private

    def resource_data(ia, inc, inc_child, resource, type)
      id = resource.id
      associations_only = serializer.already_serialized?(type, id)
      if inc && !associations_only
        serializer.add_included_object(
          type, id, serializer.object_hash(resource, ia)
        )
      elsif inc_child || associations_only
        serializer.relationship_data(resource, ia)
      end
    end

    def linkage_base(linkage_id)
      { type: serializer.format_key(association.type), id: linkage_id }
    end

    # Serializer for has_one associations
    class HasOne < AssociationSerializer
      def serialize_to_links_hash(source)
        linkage_id = serializer.foreign_key_value(source, association)
        linkage_base(linkage_id) if linkage_id
      end

      def link_object(source, _)
        serializer.link_object_base(source, association, true) do
          serialize_to_links_hash(source)
        end
      end

      def relationship_data(ia, inc, inc_child, name, source, type)
        resource = source.send(name)
        resource_data(ia, inc, inc_child, resource, type) if resource
      end
    end

    # Serializer for has_many associations
    class HasMany < AssociationSerializer
      def serialize_to_links_hash(source)
        linkage = []
        serializer.foreign_key_value(source, association).each do |linkage_id|
          linkage.append(linkage_base(linkage_id))
        end
        linkage
      end

      def link_object(source, include_linkage)
        serializer.link_object_base(source, association, include_linkage) do
          serialize_to_links_hash(source)
        end
      end

      def relationship_data(ia, inc, inc_child, name, source, type)
        resources = source.send(name)
        resources.each do |resource|
          resource_data(ia, inc, inc_child, resource, type)
        end
      end
    end
  end
end
