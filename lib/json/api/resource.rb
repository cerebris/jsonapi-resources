require 'json/api/resources'
require 'json/api/association'

module JSON
  module API
    class Resource
      include Resources

      def initialize(object)
        @object          = object
      end

      class << self
        def inherited(base)
          base._attributes = (_attributes || Set.new).dup
          base._associations = (_associations || {}).dup
          base._allowed_filters = (_allowed_filters || Set.new).dup
        end

        attr_accessor :_attributes, :_associations, :model, :_allowed_filters

        def attributes(*attrs)
          @_attributes.merge attrs
          attrs.each do |attr|
            define_method attr do
              @object.read_attribute_for_serialization attr
            end unless method_defined?(attr)
          end
        end

        def attribute(attr)
          @_attributes.add attr
          define_method attr do
            @object.read_attribute_for_serialization attr
          end unless method_defined?(attr)
        end

        def has_one(*attrs)
          _associate(Association::HasOne, *attrs)
        end

        def has_many(*attrs)
          _associate(Association::HasMany, *attrs)
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
          @_key ||= :id
        end

        def key=(key)
          @_key = key
        end

        def filters(*attrs)
          @_allowed_filters.concat attrs
        end

        def filter(attr)
          @_allowed_filters.push attr.to_sym
        end

        def _allowed_filters
          !@_allowed_filters.nil? ? @_allowed_filters : [key]
        end

        if RUBY_VERSION >= '2.0'
          def model_class
            begin
              @model ||= Object.const_get(model)
            rescue NameError
              nil
            end
          end
        else
          def model_class
            @model ||= model.safe_constantize
          end
        end

        def _verify_filter_params(params)
          params.permit(*_allowed_filters)
        end

        # Override this method if you have more complex requirements than this basic find method provides
        def find(attrs)
          resources = []
          model_class.where(attrs[:filters]).each do |object|
            resources.push self.new(object)
          end

          return resources
        end

        def _validate_field(field)
          _attributes.include?(field) || _associations.key?(field)
        end

        private

        def _associate(klass, *attrs)
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

      def _filterable(keys)
        keys
      end

    end
  end
end
