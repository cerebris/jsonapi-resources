module JSON
  module API
    class Association
      def initialize(name, options={})
        @name          = name.to_s
        @options       = options
        @key           = options[:key]
        @primary_key   = options.fetch(:primary_key, 'id')
      end

      def key
        @key
      end

      def class_name
        @class_name
      end

      def serialize_type_name
        @serialize_type_name
      end

      def primary_key
        @primary_key
      end

      class HasOne < Association
        def initialize(name, options={})
          super
          @class_name           = options.fetch(:class_name, name.to_s.capitalize)
          @serialize_type_name = @class_name.downcase.pluralize
          @key ||= "#{name}_id"
        end
      end

      class HasMany < Association
        def initialize(name, options={})
          super
          @class_name           = options.fetch(:class_name, name.to_s.capitalize.singularize)
          @serialize_type_name = @class_name.downcase.pluralize
          @key ||= "#{name.to_s.singularize}_ids"
        end
      end
    end
  end
end
