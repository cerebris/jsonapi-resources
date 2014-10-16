module JSONAPI
  class Association
    attr_reader :acts_as_set, :type, :key, :options, :name, :class_name

    def initialize(name, options={})
      @name          = name.to_s
      @options       = options
      @key           = options[:key] ? options[:key].to_sym : nil
      @acts_as_set   = options.fetch(:acts_as_set, false) == true
    end

    def primary_key
      @primary_key ||= Resource.resource_for(@name)._primary_key
    end

    class HasOne < Association
      def initialize(name, options={})
        super
        @class_name = options.fetch(:class_name, name.to_s.capitalize)
        @type = class_name.underscore.pluralize.to_sym
        @key ||= "#{name}_id".to_sym
      end
    end

    class HasMany < Association
      def initialize(name, options={})
        super
        @class_name = options.fetch(:class_name, name.to_s.capitalize.singularize)
        @type = class_name.underscore.pluralize.to_sym
        @key ||= "#{name.to_s.singularize}_ids".to_sym
      end
    end
  end
end
