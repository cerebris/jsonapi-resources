require 'json/api/association'

module JSON
  module API
    class Resource

      def initialize(object)
        @object          = object
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

        def model_name(model)
          @_model_name = model
        end

        def model
          @_model_name ||= self.name.demodulize.sub(/Resource$/, '')
        end

        def model=(model)
          @_model_name = model
        end

        def model_plural
          @_model_name_plural ||= self.model.pluralize
        end

        def model_plural=(model_plural)
          @_model_name_plural = model_plural
        end

        def plural_model_symbol
          @_plural_model_symbol ||= self.model_plural.downcase.to_sym
        end

        def key
          @_key ||= 'id'
        end

        def key=(key)
          @_key = key
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
              @model ||= Object.const_get(model)
            rescue NameError
              nil
            end
          end
        else
          def resource_for(resource)
            "#{resource.class.name}Resource".safe_constantize
          end
          def model_class
            @model ||= model.safe_constantize
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

              define_method "_#{attr}_object" do
                class_name = self.class._associations[attr].class_name
                resource_class = self.class.resource_for(class_name)
                if resource_class
                  associated_object = @object.send attr
                  return resource_class.new(associated_object)
                end
              end
            elsif @_associations[attr].is_a?(JSON::API::Association::HasMany)
              key = @_associations[attr].key

              define_method key do
                @object.read_attribute_for_serialization key
              end unless method_defined?(key)

              define_method "_#{attr}_objects" do
                class_name = self.class._associations[attr].class_name
                resource_class = self.class.resource_for(class_name)
                resources = []
                if resource_class
                  associated_objects = @object.send attr
                  associated_objects.each do |associated_object|
                    resources.push resource_class.new(associated_object)
                  end
                end
                return resources
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
