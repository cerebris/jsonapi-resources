require 'json/api/association'
require 'json/api/serializer'

module JSON
  module API
    class Resource
      include JSON::API::Serializer

      def initialize(object, options={})
        @object          = object
        @options         = options
        @root_resource   = options.fetch(:root_resource, self)

        @linked_objects  = {}
        @included_associations = {}
        process_includes(options[:include])
      end

      def process_includes(includes)
        return if includes.blank?

        includes.split(/\s*,\s*/).each do |include|
          pos = include.index('.')
          if pos
            association_name = include[0, pos].to_sym
            @included_associations[association_name] ||= {}
            @included_associations[association_name].store(:include_children, true)
            @included_associations[association_name].store(:include_related, include[pos+1, include.length])
          else
            association_name = include.to_sym
            @included_associations[association_name] ||= {}
            @included_associations[association_name].store(:include, true)
          end
        end
      end

      class << self
        def inherited(base)
          base._attributes = (_attributes || []).dup
          base._associations = (_associations || {}).dup
        end

        attr_accessor :_attributes, :_associations, :model

        def attributes(*attrs)
          @_attributes.concat attrs
          attrs.each do |attr|
            define_method attr do
              @object.read_attribute_for_serialization attr
            end unless method_defined?(attr)
          end
        end

        def attribute(attr)
          @_attributes.push attr
          define_method attr do
            @object.read_attribute_for_serialization attr
          end unless method_defined?(attr)
        end

        def has_one(*attrs)
          associate(Association::HasOne, *attrs)
        end

        def has_many(*attrs)
          associate(Association::HasMany, *attrs)
        end

        def model_name
          @_model_name ||= self.name.demodulize.sub(/Resource$/, '')
        end

        def model_name=(model)
          @_model_name = model
        end

        def set_model_name(model)
          @_model_name = model
        end

        if RUBY_VERSION >= '2.0'
          def resource_for(resource_name)
            begin
              Object.const_get "#{resource_name}Resource"
            rescue NameError
              nil
            end
          end
          def model_class
            begin
              @model ||= Object.const_get(model_name)
            rescue NameError
              nil
            end
          end
        else
          def resource_for(resource)
            "#{resource.class.name}Resource".safe_constantize
          end
          def model_class
            @model ||= model_name.safe_constantize
          end
        end

        private

        def associate(klass, *attrs)
          options = attrs.extract_options!

          attrs.each do |attr|
            @_associations[attr] = klass.new(attr, options)

            if @_associations[attr].is_a?(JSON::API::Association::HasOne)
              key = @_associations[attr].key

              define_method key do
                @object.read_attribute_for_serialization key
              end unless method_defined?(key)

              define_method "_#{attr}_object" do |root_resource, opts = {}|
                skip_object = opts.fetch(:skip_object, false)
                class_name = self.class._associations[attr].class_name
                r = self.class.resource_for(class_name)
                if r
                  associated_object = @object.send attr
                  id = associated_object.send self.class._associations[attr].primary_key

                  opts.merge!({root_resource: @root_resource})
                  object_hash = r.new(associated_object, opts).object_hash
                  root_resource.add_linked_object(class_name.downcase.pluralize, id, object_hash) unless skip_object
                end
              end
            elsif @_associations[attr].is_a?(JSON::API::Association::HasMany)
              key = @_associations[attr].key

              define_method key do
                @object.read_attribute_for_serialization key
              end unless method_defined?(key)

              define_method "_#{attr}_objects" do |root_resource, opts = {}|
                skip_object = opts.fetch(:skip_object, false)
                class_name = self.class._associations[attr].class_name
                r = self.class.resource_for(class_name)
                if r
                  associated_objects = @object.send attr
                  associated_objects.each do |associated_object|
                    id = associated_object.send self.class._associations[attr].primary_key

                    opts.merge!({root_resource: @root_resource})
                    object_hash = r.new(associated_object, opts).object_hash
                    root_resource.add_linked_object(class_name.downcase.pluralize, id, object_hash) unless skip_object
                  end
                end
              end
            end
          end
        end
      end

      def _fetchable(keys)
        keys
      end

      def _updateable(keys)
        keys
      end

      def _creatable(keys)
        keys
      end
    end
  end
end
