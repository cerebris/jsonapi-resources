module JSONAPI
  class Relationship
    attr_reader :acts_as_set, :foreign_key, :options, :name,
                :class_name, :polymorphic, :always_include_linkage_data,
                :parent_resource, :eager_load_on_include, :custom_methods,
                :inverse_relationship, :allow_include

    attr_writer :allow_include

    def initialize(name, options = {})
      @name = name.to_s
      @options = options
      @acts_as_set = options.fetch(:acts_as_set, false) == true
      @foreign_key = options[:foreign_key] ? options[:foreign_key].to_sym : nil
      @parent_resource = options[:parent_resource]
      @relation_name = options.fetch(:relation_name, @name)
      @polymorphic = options.fetch(:polymorphic, false) == true
      @polymorphic_relations = options[:polymorphic_relations]
      @always_include_linkage_data = options.fetch(:always_include_linkage_data, false) == true
      @eager_load_on_include = options.fetch(:eager_load_on_include, false) == true
      @allow_include = options[:allow_include]
      @class_name = nil
      @inverse_relationship = nil

      # Custom methods are reserved for use in resource finders. Not used in the default ActiveRelationResourceFinder
      @custom_methods = options.fetch(:custom_methods, {})
    end

    alias_method :polymorphic?, :polymorphic

    def primary_key
      # :nocov:
      @primary_key ||= resource_klass._primary_key
      # :nocov:
    end

    def resource_klass
      @resource_klass ||= @parent_resource.resource_klass_for(@class_name)
    end

    def table_name
      # :nocov:
      @table_name ||= resource_klass._table_name
      # :nocov:
    end

    def self.polymorphic_types(name)
      @poly_hash ||= {}.tap do |hash|
        ObjectSpace.each_object do |klass|
          next unless Module === klass
          if ActiveRecord::Base > klass
            klass.reflect_on_all_associations(:has_many).select{|r| r.options[:as] }.each do |reflection|
              (hash[reflection.options[:as]] ||= []) << klass.name.downcase
            end
          end
        end
      end
      @poly_hash[name.to_sym]
    end

    def polymorphic_relations
      @polymorphic_relations ||= self.class.polymorphic_types(@relation_name)
    end

    def type
      @type ||= resource_klass._type.to_sym
    end

    def relation_name(options)
      case @relation_name
        when Symbol
          # :nocov:
          @relation_name
          # :nocov:
        when String
          @relation_name.to_sym
        when Proc
          @relation_name.call(options)
      end
    end

    def belongs_to?
      # :nocov:
      false
      # :nocov:
    end

    def readonly?
      @options[:readonly]
    end

    class ToOne < Relationship
      attr_reader :foreign_key_on

      def initialize(name, options = {})
        super
        @class_name = options.fetch(:class_name, name.to_s.camelize)
        @foreign_key ||= "#{name}_id".to_sym
        @foreign_key_on = options.fetch(:foreign_key_on, :self)
        if parent_resource
          @inverse_relationship = options.fetch(:inverse_relationship, parent_resource._type)
        end
      end

      def belongs_to?
        # :nocov:
        foreign_key_on == :self
        # :nocov:
      end

      def polymorphic_type
        "#{name}_type" if polymorphic?
      end

      def allow_include?(context = nil)
        strategy = if @allow_include.nil?
                     JSONAPI.configuration.default_allow_include_to_one
                   else
                     @allow_include
                   end

        if !!strategy == strategy #check for boolean
          return strategy
        elsif strategy.is_a?(Symbol) || strategy.is_a?(String)
          parent_resource.send(strategy, context)
        else
          strategy.call(context)
        end
      end
    end

    class ToMany < Relationship
      attr_reader :reflect

      def initialize(name, options = {})
        super
        @class_name = options.fetch(:class_name, name.to_s.camelize.singularize)
        @foreign_key ||= "#{name.to_s.singularize}_ids".to_sym
        @reflect = options.fetch(:reflect, true) == true
        if parent_resource
          @inverse_relationship = options.fetch(:inverse_relationship, parent_resource._type.to_s.singularize.to_sym)
        end
      end

      def allow_include?(context = nil)
        strategy = if @allow_include.nil?
                     JSONAPI.configuration.default_allow_include_to_many
                   else
                     @allow_include
                   end

        if !!strategy == strategy #check for boolean
          return strategy
        elsif strategy.is_a?(Symbol) || strategy.is_a?(String)
          parent_resource.send(strategy, context)
        else
          strategy.call(context)
        end

      end
    end
  end
end
