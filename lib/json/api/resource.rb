require 'json/api/resources'
require 'json/api/association'

module JSON
  module API
    class Resource
      include Resources

      @@resource_types = {}

      def initialize(object = new_object)
        @object = object
      end

      def new_object
        self.class._model_class.new
      end

      def destroy
        @object.destroy
      end

      def update(attributes)
        @object.update(attributes)
      end

      class << self
        def inherited(base)
          base._attributes = (_attributes || Set.new).dup
          base._associations = (_associations || {}).dup
          base._allowed_filters = (_allowed_filters || Set.new).dup

          type = base.name.demodulize.sub(/Resource$/, '').underscore
          base._type = type.pluralize.to_sym
          @@resource_types[base._type] = base.name.demodulize
        end

        attr_accessor :_attributes, :_associations, :_allowed_filters , :_type

        # Methods used in defining a resource class
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
          @_model_name = model.to_sym
        end

        def filters(*attrs)
          @_allowed_filters.merge(*attrs)
        end

        def filter(attr)
          @_allowed_filters.add(attr.to_sym)
        end

        def key(key)
          @_key = key.to_sym
        end

        # Override in your resource to filter the updateable keys
        def updateable(keys)
          keys
        end

        # Override in your resource to filter the createable keys
        def createable(keys)
          keys
        end

        # Override this method if you have more complex requirements than this basic find method provides
        def find(attrs)
          resources = []
          _model_class.where(attrs[:filters]).each do |object|
            resources.push self.new(object)
          end

          return resources
        end

        def find_by_id(id)
          obj = _model_class.where({_key => id}).first
          if obj.nil?
            raise JSON::API::Errors::RecordNotFound.new(id)
          end
          self.new(obj)
        end

        def transaction
          ActiveRecord::Base.transaction do
            yield
          end
        end

        # quasi private class methods
        def _updateable_associations
          associations = []

          @_associations.each do |key, association|
            if association.is_a?(JSON::API::Association::HasOne) || association.treat_as_set
              associations.push(key)
            end
          end
          associations
        end

        def _model_name
          @_model_name ||= self.name.demodulize.sub(/Resource$/, '')
        end

        def _serialize_as
          @_serialize_as ||= self._model_name.underscore.pluralize.to_sym
        end

        def _key
          @_key ||= :id
        end

        def _allowed_filters
          !@_allowed_filters.nil? ? @_allowed_filters : Set.new([_key])
        end

        def _resource_name_from_type(type)
          return @@resource_types[type]
        end

        if RUBY_VERSION >= '2.0'
          def _model_class
            @model ||= Object.const_get(_model_name)
          end
        else
          def _model_class
            @model ||= _model_name.to_s.safe_constantize
          end
        end

        def _allowed_filter?(filter)
          _allowed_filters.include?(filter.to_sym)
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
                type_name = self.class._associations[attr].serialize_type_name
                resource_class = self.class.resource_for(type_name)
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

              define_method "#{key}=" do |values|
                @object.send "#{key}=", values
              end unless method_defined?("#{key}=")

              define_method "_#{attr}_objects" do
                type_name = self.class._associations[attr].serialize_type_name
                resource_class = self.class.resource_for(type_name)
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

      # Override this on a resource instance to override the fetchable keys
      def fetchable(keys)
        keys
      end
    end
  end
end
