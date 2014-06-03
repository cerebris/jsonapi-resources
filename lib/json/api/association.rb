module JSON
  module API
    class Association
      def initialize(name, options={})
        @name          = name.to_s
        @options       = options
        @key           = options[:key] ? options[:key].to_sym : nil
        @primary_key   = options.fetch(:primary_key, 'id').to_sym
        @treat_as_set  = options.fetch(:treat_as_set, false) == true
      end

      def key
        @key
      end

      def primary_key
        @primary_key
      end

      def treat_as_set
        @treat_as_set
      end

      def serialize_type_name
        @serialize_type_name
      end

      class HasOne < Association
        def initialize(name, options={})
          super
          class_name = options.fetch(:class_name, name.to_s.capitalize)
          @serialize_type_name = class_name.underscore.pluralize.to_sym
          @key ||= "#{name}_id".to_sym
        end
      end

      class HasMany < Association
        def initialize(name, options={})
          super
          class_name           = options.fetch(:class_name, name.to_s.capitalize.singularize).to_sym
          @serialize_type_name = class_name.to_s.underscore.pluralize.to_sym
          @key ||= "#{name.to_s.singularize}_ids".to_sym
        end
      end
    end
  end
end
