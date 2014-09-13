require 'jsonapi/configuration'
require 'jsonapi/resource_for'
require 'jsonapi/association'
require 'action_dispatch/routing/mapper'

module JSONAPI
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

    def remove(context)
      @object.destroy
    end

    def create_has_many_link(association_type, association_key_value, context)
      association = self.class._associations[association_type]
      related_resource = self.class.resource_for(association.serialize_type_name).find_by_key(association_key_value, context)

      @object.send(association.serialize_type_name) << related_resource.object
    end

    def replace_has_many_links(association_type, association_key_values, context)
      association = self.class._associations[association_type]

      @object.send("#{association.key}=", association_key_values)
    end

    def replace_has_one_link(association_type, association_key_value, context)
      association = self.class._associations[association_type]

      @object.send("#{association.key}=", association_key_value)
    end

    def remove_has_many_link(association_type, key, context)
      association = self.class._associations[association_type]

      @object.send(association.serialize_type_name).delete(key)
    end

    def remove_has_one_link(association_type, context)
      association = self.class._associations[association_type]

      @object.send("#{association.key}=", nil)
    end

    def replace_fields(field_data, context)
      field_data[:attributes].each do |attribute, value|
        send "#{attribute}=", value
      end

      field_data[:has_one].each do |association_type, value|
        if value.nil?
          remove_has_one_link(association_type, context)
        else
          replace_has_one_link(association_type, value, context)
        end
      end if field_data[:has_one]

      field_data[:has_many].each do |association_type, values|
        replace_has_many_links(association_type, values, context)
      end if field_data[:has_many]
    end

    def save(context)
      @object.save!
    rescue ActiveRecord::RecordInvalid => e
      errors = []
      e.record.errors.messages.each do |element|
        element[1].each do |message|
          errors.push(JSONAPI::Error.new(
                          code: JSONAPI::VALIDATION_ERROR,
                          status: :bad_request,
                          title: "#{element[0]} - #{message}",
                          detail: "can't be blank",
                          path: "\\#{element[0]}"))
        end
      end
      raise JSONAPI::Exceptions::ValidationErrors.new(errors)
    end

    # Override this on a resource instance to override the fetchable keys
    def fetchable(keys, context = nil)
      keys
    end

    class << self
      def inherited(base)
        base._attributes = (_attributes || {}).dup
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

      def routing_options(options)
        @_routing_resource_options = options
      end

      def routing_resource_options
        @_routing_resource_options ||= {}
      end

      # Methods used in defining a resource class
      def attributes(*attrs)
        attrs.each do |attr|
          attribute(attr)
        end
      end

      def attribute(attr, options = {type: :default})
        @_attributes[attr] = options
        define_method attr do
          @object.send(attr)
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
      def updateable_fields(context)
        fields
      end

      # Override in your resource to filter the createable keys
      def createable_fields(context)
        fields
      end

      def fields
        _updateable_associations | _attributes.keys
      end

      # Override this method if you have more complex requirements than this basic find method provides
      def find(filters, context = nil)
        includes = []
        where_filters = {}

        filters.each do |filter, value|
          if _associations.include?(filter)
            if _associations[filter].is_a?(JSONAPI::Association::HasMany)
              includes.push(filter.to_sym)
              where_filters["#{filter}.#{_associations[filter].primary_key}"] = value
            else
              where_filters["#{_associations[filter].key}"] = value
            end
          else
            where_filters[filter] = value
          end
        end

        resources = []
        _model_class.where(where_filters).includes(includes).each do |object|
          resources.push self.new(object)
        end

        return resources
      end

      def find_by_key(key, context = nil)
        obj = _model_class.where({_key => key}).first
        if obj.nil?
          raise JSONAPI::Exceptions::RecordNotFound.new(key)
        end
        self.new(obj)
      end

      def verify_filters(filters, context = nil)
        verified_filters = {}
        filters.each do |filter, raw_value|
          verified_filter = verify_filter(filter, raw_value, context)
          verified_filters[verified_filter[0]] = verified_filter[1]
        end
        verified_filters
      end

      def is_filter_association?(filter)
        filter == _serialize_as || _associations.include?(filter)
      end

      def verify_filter(filter, raw, context = nil)
        filter_values = []
        filter_values += CSV.parse_line(raw) unless raw.nil? || raw.empty?

        if is_filter_association?(filter)
          verify_association_filter(filter, filter_values, context)
        else
          verify_custom_filter(filter, filter_values, context)
        end
      end

      # override to allow for key processing and checking
      def verify_key(key, context = nil)
        return key
      end

      # override to allow for custom filters
      def verify_custom_filter(filter, value, context = nil)
        return filter, value
      end

      # override to allow for custom association logic, such as uuids, multiple keys or permission checks on keys
      def verify_association_filter(filter, raw, context = nil)
        return filter, raw
      end

      # quasi private class methods
      def _updateable_associations
        associations = []

        @_associations.each do |key, association|
          if association.is_a?(JSONAPI::Association::HasOne) || association.acts_as_set
            associations.push(key)
          end
        end
        associations
      end

      def _has_association?(type)
        type = type.to_s
        @_associations.has_key?(type.singularize.to_sym) || @_associations.has_key?(type.pluralize.to_sym)
      end

      def _association(type)
        type = type.to_sym unless type.is_a?(Symbol)
        @_associations[type]
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

      def _as_parent_key
        @_as_parent_key ||= "#{_serialize_as.to_s.singularize}_#{_key}"
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

      private

      def _associate(klass, *attrs)
        options = attrs.extract_options!

        attrs.each do |attr|
          @_associations[attr] = klass.new(attr, options)

          if @_associations[attr].is_a?(JSONAPI::Association::HasOne)
            key = @_associations[attr].key

            define_method key do
              @object.method(key).call
            end unless method_defined?(key)

            define_method "_#{attr}_object" do
              type_name = self.class._associations[attr].serialize_type_name
              resource_class = self.class.resource_for(type_name)
              if resource_class
                associated_object = @object.send attr
                return resource_class.new(associated_object)
              end
            end
          elsif @_associations[attr].is_a?(JSONAPI::Association::HasMany)
            key = @_associations[attr].key

            define_method key do
              @object.method(key).call
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
  end
end
