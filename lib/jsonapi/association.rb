module JSONAPI
  # Association
  class Association
    attr_reader :acts_as_set, :foreign_key, :type, :options, :name, :class_name

    def initialize(name, options = {})
      @name = name.to_s
      @options = options
      @acts_as_set = options.fetch(:acts_as_set, false) == true
      @foreign_key = options[:foreign_key] ? options[:foreign_key].to_sym : nil
      @module_path = options[:module_path] || ''
    end

    def self.serializer(association, resource_serializer)
      if association.is_a? HasOne
        AssociationSerializer::HasOne.new(association, resource_serializer)
      else
        AssociationSerializer::HasMany.new(association, resource_serializer)
      end
    end

    def primary_key
      @primary_key ||= Resource.resource_for(@module_path + @name)._primary_key
    end

    # HasOne Association
    class HasOne < Association
      def initialize(name, options = {})
        super
        @class_name = options.fetch(:class_name, name.to_s.capitalize)
        @type = class_name.underscore.pluralize.to_sym
        @foreign_key ||= @key.nil? ? "#{name}_id".to_sym : @key
      end

      def foreign_key_value(value)
        IdValueFormatter.format(value)
      end
    end

    # HasMany Association
    class HasMany < Association
      def initialize(name, options = {})
        super
        @class_name =
          options.fetch(:class_name, name.to_s.capitalize.singularize)
        @type = class_name.underscore.pluralize.to_sym
        @foreign_key ||=
          @key.nil? ? "#{name.to_s.singularize}_ids".to_sym : @key
      end

      def foreign_key_value(values)
        values.map { |value| IdValueFormatter.format(value) }
      end
    end
  end
end
