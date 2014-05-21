require 'json/api/resources'
require 'json/api/association'

module JSON
  module API
    class Resource
      include Resources

      @@resource_types = {}

      def initialize(object)
        @object          = object
      end

      def destroy
        @object.destroy
      end

      class << self
        def inherited(base)
          base._attributes = (_attributes || Set.new).dup
          base._associations = (_associations || {}).dup
          base._allowed_filters = (_allowed_filters || Set.new).dup

          type = base.name.demodulize.sub(/Resource$/, '').downcase
          base._type_singular =  type.to_sym
          base._type = type.pluralize.to_sym
          @@resource_types[base._type] = base.name.demodulize
        end

        attr_accessor :_attributes, :_associations, :_allowed_filters , :_type, :_type_singular

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

        def _updateable_associations
          associations = []

          @_associations.each do |key, association|
            if association.is_a?(JSON::API::Association::HasOne) || association.treat_as_set
              associations.push(key)
            end
          end
          associations
        end

        def has_one(*attrs)
          _associate(Association::HasOne, *attrs)
        end

        def has_many(*attrs)
          _associate(Association::HasMany, *attrs)
        end

        def type_singular(type)
          @_type_singular = type.to_sym
        end

        def model_name(model)
          @_model_name = model.to_sym
        end

        def model
          @_model_name ||= self.name.demodulize.sub(/Resource$/, '')
        end

        def model_plural
          @_model_name_plural ||= self.model.to_s.pluralize.to_sym
        end

        def model_plural=(model_plural)
          @_model_name_plural = model_plural.to_sym
        end

        def plural_model_symbol
          @_plural_model_symbol ||= self.model_plural.downcase.to_sym
        end

        def key
          @_key ||= :id
        end

        def key=(key)
          @_key = key.to_sym
        end

        def filters(*attrs)
          @_allowed_filters.merge(*attrs)
        end

        def filter(attr)
          @_allowed_filters.add(attr.to_sym)
        end

        def _allowed_filters
          !@_allowed_filters.nil? ? @_allowed_filters : Set.new([key])
        end

        def resource_name_from_type(type)
          return @@resource_types[type]
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

        def _allowed_filter?(filter)
          _allowed_filters.include?(filter.to_sym)
        end

        # Override this method if you have more complex requirements than this basic find method provides
        def find(attrs)
          resources = []
          model_class.where(attrs[:filters]).each do |object|
            resources.push self.new(object)
          end

          return resources
        end

        def find_by_id(id)
          obj = model_class.where({key => id}).first
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

        def _validate_field(field)
          _attributes.include?(field) || _associations.key?(field)
        end

        def _updateable(keys)
          keys
        end

        def _createable(keys)
          keys
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

      def _fetchable(keys)
        keys
      end
    end
  end
end
