require 'json/api/resource_for'
require 'json/api/association'

module JSON
  module API
    class Resource
      include ResourceFor

      @@resource_types = {}

      attr_reader :object

      def initialize(object = create_new_object)
        @object = object
      end

      def create_new_object
        self.class._model_class.new
      end

      def destroy
        @object.destroy
      end

      def save
        @object.save!
      rescue ActiveRecord::RecordInvalid => e
        errors = []
        e.record.errors.messages.each do |element|
          element[1].each do |message|
            errors.push(JSON::API::Error.new(
                            code: JSON::API::VALIDATION_ERROR,
                            status: :bad_request,
                            title: "#{element[0]} - #{message}",
                            detail: "can't be blank",
                            path: "\\#{element[0]}"))
          end
        end
        raise JSON::API::Exceptions::ValidationErrors.new(errors)
      end

      # Override this on a resource instance to override the fetchable keys
      def fetchable(keys, options = {})
        keys
      end

      class << self
        def inherited(base)
          base._attributes = (_attributes || Set.new).dup
          base._associations = (_associations || {}).dup
          base._allowed_filters = (_allowed_filters || Set.new).dup

          type = base.name.demodulize.sub(/Resource$/, '').underscore
          base._type = type.pluralize.to_sym
          # If eager loading is on this is how all the resource types are setup
          # If eager loading is off some resource types will be initialized in
          # _resource_name_from_type
          @@resource_types[base._type] ||= base.name.demodulize
        end

        attr_accessor :_attributes, :_associations, :_allowed_filters , :_type

        # Methods used in defining a resource class
        def attributes(*attrs)
          @_attributes.merge attrs
          attrs.each do |attr|
            attribute(attr)
          end
        end

        def attribute(attr)
          @_attributes.add attr
          define_method attr do
            @object.method(attr).call
          end unless method_defined?(attr)

          define_method "#{attr}=" do |value|
            @object.send "#{attr}=", value
          end unless method_defined?("#{attr}=")
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
          @_allowed_filters.merge(attrs)
        end

        def filter(attr)
          @_allowed_filters.add(attr.to_sym)
        end

        def key(key)
          @_key = key.to_sym
        end

        # Override in your resource to filter the updateable keys
        def updateable(keys, options = {})
          keys
        end

        # Override in your resource to filter the createable keys
        def createable(keys, options = {})
          keys
        end

        # Override this method if you have more complex requirements than this basic find method provides
        def find(attrs, options = {})
          resources = []
          _model_class.where(verify_filters(attrs[:filters])).each do |object|
            resources.push self.new(object)
          end

          return resources
        end

        def find_by_key(id, options = {})
          obj = _model_class.where({_key => id}).first
          if obj.nil?
            raise JSON::API::Exceptions::RecordNotFound.new(id)
          end
          self.new(obj)
        end

        def transaction
          ActiveRecord::Base.transaction do
            yield
        def verify_params(object_params, create) #ToDo find better method of indicating create
          if create
            allowed_params = createable(_updateable_associations | _attributes.to_a)
          else
            allowed_params = updateable(_updateable_associations | _attributes.to_a)
          end

          # push links into top level param list with attributes
          if object_params && object_params[:links]
            object_params[:links].each do |link, value|
              object_params[link] = value
            end
            object_params.delete(:links)
          end

          checked_params = {}
          checked_associations = {}

          verify_permitted_params(object_params, allowed_params)

          object_params.each do |key, value|
            param = key.to_sym

            if _associations[param].is_a?(JSON::API::Association::HasOne)
              checked_params[_associations[param].key] = value
            elsif _associations[param].is_a?(JSON::API::Association::HasMany)
              checked_associations[_associations[param].key] = value
            else
              checked_params[param] = value
            end
          end
          return checked_params.merge(checked_associations)
        end

        def verify_filters(filters)
          verified_filters = {}
          filters.each do |filter, raw_value|
            verified_filter = verify_filter(filter, raw_value)
            verified_filters[verified_filter[0]] = verified_filter[1]
          end
          verified_filters
        end

        def is_filter_association?(filter)
          filter == _serialize_as || _associations.include?(filter)
        end

        def verify_filter(filter, raw)
          filter_values = []
          filter_values += CSV.parse_line(raw) unless raw.nil? || raw.empty?

          if is_filter_association?(filter)
            verify_association_filter(filter, filter_values)
          else
            verify_custom_filter(filter, filter_values)
          end
        end

        # override to allow for id processing and checking
        def verify_id(id)
          return id
        end

        # override to allow for custom filters
        def verify_custom_filter(filter, value)
          return filter, value
        end

        # override to allow for custom association logic, such as uuids, multiple ids or permission checks on ids
        def verify_association_filter(filter, raw)
          return _associations[filter].primary_key, raw
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

        def _has_association?(type)
          @_associations.has_key?(type)
        end

        def _model_name
          @_model_name ||= self.name.demodulize.sub(/Resource$/, '')
        end

        def _serialize_as
          @_serialize_as ||= self._type
        end

        def _key
          @_key ||= :id
        end

        def _allowed_filters
          !@_allowed_filters.nil? ? @_allowed_filters : Set.new([_key])
        end

        def _resource_name_from_type(type)
          class_name = @@resource_types[type]
          if class_name.nil?
            class_name = type.to_s.singularize.camelize + 'Resource'
            @@resource_types[type] = class_name
          end
          return class_name
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
                @object.method(key).call
              end unless method_defined?(key)

              define_method "#{key}=" do |values|
                @object.send "#{key}=", values
              end unless method_defined?("#{key}=")

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
                @object.method(key).call
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

        def verify_permitted_params(params, allowed_param_set)
          params_not_allowed = []
          params.keys.each do |key|
            param = key.to_sym
            params_not_allowed.push(param) unless allowed_param_set.include?(param)
          end
          raise JSON::API::Exceptions::ParametersNotAllowed.new(params_not_allowed) if params_not_allowed.length > 0
        end
      end
    end
  end
end
