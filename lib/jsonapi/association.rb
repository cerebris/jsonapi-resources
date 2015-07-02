module JSONAPI
  class Association
    attr_reader :acts_as_set, :foreign_key, :type, :options, :name, :class_name

    def initialize(name, options={})
      @name                = name.to_s
      @options             = options
      @acts_as_set         = options.fetch(:acts_as_set, false) == true
      @foreign_key         = options[:foreign_key ] ? options[:foreign_key ].to_sym : nil
      @module_path         = options.fetch(:module_path, '')
      @relation_name       = options.fetch(:relation_name, @name)
    end

    def primary_key
      @primary_key ||= resource_klass._primary_key
    end

    def resource_klass
      @resource_klass ||= Resource.resource_for(@module_path + @class_name)
    end

    def relation_name(options = {})
      case @relation_name
        when Symbol
          @relation_name
        when String
          @relation_name.to_sym
        when Proc
          @relation_name.call(options)
      end
    end

    class HasOne < Association
      def initialize(name, options={})
        super
        @class_name = options.fetch(:class_name, name.to_s.capitalize)
        @type = class_name.underscore.pluralize.to_sym
        @foreign_key ||= @key.nil? ? "#{name}_id".to_sym : @key
      end
    end

    class HasMany < Association
      def initialize(name, options={})
        super
        @class_name = options.fetch(:class_name, name.to_s.capitalize.singularize)
        @type = class_name.underscore.pluralize.to_sym
        @foreign_key  ||= @key.nil? ? "#{name.to_s.singularize}_ids".to_sym : @key
      end
    end
  end
end
