require 'json/api/association'
require 'json/api/serializer'

module JSON
  module API
    class Resource
      include JSON::API::Serializer

      def initialize(object, options={})
        @object          = object
        @root_resource   = options[:root_resource]
        @linked_objects  = {}
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
          def model_class
            begin
              @model ||= Object.const_get(model_name)
            rescue NameError
              nil
            end
          end
        else
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

              define_method "#{key}_object" do

              end
            elsif @_associations[attr].is_a?(JSON::API::Association::HasMany)
              key = @_associations[attr].key

              define_method key do
                @object.read_attribute_for_serialization key
              end unless method_defined?(key)
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
