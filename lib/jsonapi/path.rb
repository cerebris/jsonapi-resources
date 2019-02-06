module JSONAPI
  class Path
    attr_reader :parts, :resource_klass
    def initialize(resource_klass:,
                   path_string:,
                   ensure_default_field: true,
                   parse_fields: true)
      @resource_klass = resource_klass

      current_resource_klass = resource_klass
      @parts = path_string.to_s.split('.').collect do |part_string|
        part = PathPart.parse(source_resource_klass: current_resource_klass,
                              part_string: part_string,
                              parse_fields: parse_fields)

        current_resource_klass = part.resource_klass
        part
      end

      if ensure_default_field && parse_fields && @parts.last.is_a?(PathPart::Relationship)
        last = @parts.last
        @parts << PathPart::Field.new(resource_klass: last.resource_klass,
                                      field_name: last.resource_klass._primary_key)
      end
    end

    def relationship_parts
      relationships = []
      @parts.each do |part|
        relationships << part if part.is_a?(PathPart::Relationship)
      end
      relationships
    end

    def relationship_path_string
      relationship_parts.collect do |part|
        part.to_s
      end.join('.')
    end
  end
end