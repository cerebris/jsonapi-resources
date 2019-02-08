module JSONAPI
  class PathSegment
    def self.parse(source_resource_klass:, segment_string:, parse_fields: true)
      first_part, last_part = segment_string.split('#', 2)
      relationship = source_resource_klass._relationship(first_part)

      if relationship
        if last_part
          unless relationship.resource_types.include?(last_part)
            raise JSONAPI::Exceptions::InvalidRelationship.new(source_resource_klass._type, segment_string)
          end
          resource_klass = source_resource_klass.resource_klass_for(last_part)
        end
        return PathSegment::Relationship.new(relationship: relationship, resource_klass: resource_klass)
      else
        if last_part.blank? && parse_fields
          return PathSegment::Field.new(resource_klass: source_resource_klass, field_name: first_part)
        else
          raise JSONAPI::Exceptions::InvalidRelationship.new(source_resource_klass._type, segment_string)
        end
      end
    end

    class Relationship
      attr_reader :relationship

      def initialize(relationship:, resource_klass:)
        @relationship = relationship
        @resource_klass = resource_klass
      end

      def to_s
        @resource_klass ? "#{relationship.name}##{resource_klass._type}" : "#{relationship.name}"
      end

      def resource_klass
        @resource_klass || @relationship.resource_klass
      end

      def path_specified_resource_klass?
        !@resource_klass.nil?
      end
    end

    class Field
      attr_reader :resource_klass, :field_name

      def initialize(resource_klass:, field_name:)
        @resource_klass = resource_klass
        @field_name = field_name
      end

      def delegated_field_name
        resource_klass._attribute_delegated_name(field_name)
      end

      def to_s
        # :nocov:
        field_name.to_s
        # :nocov:
      end
    end
  end
end