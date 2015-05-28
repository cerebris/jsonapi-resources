module JSONAPI
  class Association
    attr_reader :acts_as_set, :foreign_key, :type, :options, :name, :class_name, :polymorphic

    def initialize(name, options={})
      @name                = name.to_s
      @options             = options
      @acts_as_set         = !!options.fetch(:acts_as_set, false)
      @foreign_key         = options[:foreign_key ] ? options[:foreign_key ].to_sym : nil
      @module_path         = options[:module_path] || ''
      @polymorphic         = !!options.fetch(:polymorphic, false)
    end

    def primary_key
      @primary_key ||= Resource.resource_for(@module_path + @name)._primary_key
    end

    alias_method :polymorphic?, :polymorphic

    def type_for_source(source)
      if polymorphic?
        resource = source.public_send(name)
        resource.class._type if resource
      else
        type
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
