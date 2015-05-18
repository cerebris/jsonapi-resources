require 'jsonapi/callbacks'

module JSONAPI
  class Resource
    include Callbacks

    @@resource_types = {}

    attr :context
    attr_reader :model

    define_jsonapi_resources_callbacks :create,
                                       :update,
                                       :remove,
                                       :save,
                                       :create_has_many_link,
                                       :replace_has_many_links,
                                       :create_has_one_link,
                                       :replace_has_one_link,
                                       :remove_has_many_link,
                                       :remove_has_one_link,
                                       :replace_fields

    def initialize(model, context = nil)
      @model = model
      @context = context
    end

    def id
      model.send(self.class._primary_key)
    end

    def is_new?
      id.nil?
    end

    def change(callback)
      if @changing
        run_callbacks callback do
          yield
        end
      else
        run_callbacks is_new? ? :create : :update do
          @changing = true
          run_callbacks callback do
            yield
          end

          save if @save_needed || is_new?
        end
      end
    end

    def remove
      run_callbacks :remove do
        _remove
      end
    end

    def create_has_many_links(association_type, association_key_values)
      change :create_has_many_link do
        _create_has_many_links(association_type, association_key_values)
      end
    end

    def replace_has_many_links(association_type, association_key_values)
      change :replace_has_many_links do
        _replace_has_many_links(association_type, association_key_values)
      end
    end

    def replace_has_one_link(association_type, association_key_value)
      change :replace_has_one_link do
        _replace_has_one_link(association_type, association_key_value)
      end
    end

    def remove_has_many_link(association_type, key)
      change :remove_has_many_link do
        _remove_has_many_link(association_type, key)
      end
    end

    def remove_has_one_link(association_type)
      change :remove_has_one_link do
        _remove_has_one_link(association_type)
      end
    end

    def replace_fields(field_data)
      change :replace_fields do
        _replace_fields(field_data)
      end
    end

    # Override this on a resource instance to override the fetchable keys
    def fetchable_fields
      self.class.fields
    end

    # Override this on a resource to customize how the associated records
    # are fetched for a model. Particularly helpful for authorization.
    def records_for(association_name, options = {})
      model.send association_name
    end

    private
    def save
      run_callbacks :save do
        _save
      end
    end

    def _save
      unless @model.valid?
        raise JSONAPI::Exceptions::ValidationErrors.new(@model.errors.messages)
      end

      saved = @model.save
      @save_needed = !saved
      saved
    end

    def _remove
      @model.destroy
    end

    def _create_has_many_links(association_type, association_key_values)
      association = self.class._associations[association_type]

      association_key_values.each do |association_key_value|
        related_resource = Resource.resource_for(self.class.module_path + association.type.to_s).find_by_key(association_key_value, context: @context)

        # ToDo: Add option to skip relations that already exist instead of returning an error?
        relation = @model.send(association.type).where(association.primary_key => association_key_value).first
        if relation.nil?
          @model.send(association.type) << related_resource.model
        else
          raise JSONAPI::Exceptions::HasManyRelationExists.new(association_key_value)
        end
      end
    end

    def _replace_has_many_links(association_type, association_key_values)
      association = self.class._associations[association_type]

      send("#{association.foreign_key}=", association_key_values)
      @save_needed = true
    end

    def _replace_has_one_link(association_type, association_key_value)
      association = self.class._associations[association_type]

      send("#{association.foreign_key}=", association_key_value)
      @save_needed = true
    end

    def _remove_has_many_link(association_type, key)
      association = self.class._associations[association_type]

      @model.send(association.type).delete(key)
    end

    def _remove_has_one_link(association_type)
      association = self.class._associations[association_type]

      send("#{association.foreign_key}=", nil)
      @save_needed = true
    end

    def _replace_fields(field_data)
      field_data[:attributes].each do |attribute, value|
        begin
          send "#{attribute}=", value
          @save_needed = true
        rescue ArgumentError
          # :nocov: Will be thrown if an enum value isn't allowed for an enum. Currently not tested as enums are a rails 4.1 and higher feature
          raise JSONAPI::Exceptions::InvalidFieldValue.new(attribute, value)
          # :nocov:
        end
      end

      field_data[:has_one].each do |association_type, value|
        if value.nil?
          remove_has_one_link(association_type)
        else
          replace_has_one_link(association_type, value)
        end
      end if field_data[:has_one]

      field_data[:has_many].each do |association_type, values|
        replace_has_many_links(association_type, values)
      end if field_data[:has_many]
    end

    class << self
      def inherited(base)
        base._attributes = (_attributes || {}).dup
        base._associations = (_associations || {}).dup
        base._allowed_filters = (_allowed_filters || Set.new).dup

        type = base.name.demodulize.sub(/Resource$/, '').underscore
        base._type = type.pluralize.to_sym

        base.attribute :id, format: :id

        check_reserved_resource_name(base._type, base.name)
      end

      def resource_for(type)
        resource_name = JSONAPI::Resource._resource_name_from_type(type)
        resource = resource_name.safe_constantize if resource_name
        if resource.nil?
          raise NameError, "JSONAPI: Could not find resource '#{type}'. (Class #{resource_name} not found)"
        end
        resource
      end

      attr_accessor :_attributes, :_associations, :_allowed_filters , :_type, :_paginator

      def create(context)
        self.new(self.create_model, context)
      end

      def create_model
        _model_class.new
      end

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

      def attribute(attr, options = {})
        check_reserved_attribute_name(attr)

        if (attr.to_sym == :id) && (options[:format].nil?)
          ActiveSupport::Deprecation.warn('Id without format is no longer supported. Please remove ids from attributes, or specify a format.')
        end

        @_attributes ||= {}
        @_attributes[attr] = options
        define_method attr do
          @model.send(attr)
        end unless method_defined?(attr)

        define_method "#{attr}=" do |value|
          @model.send "#{attr}=", value
        end unless method_defined?("#{attr}=")
      end

      def default_attribute_options
        {format: :default}
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

      def primary_key(key)
        @_primary_key = key.to_sym
      end

      # Override in your resource to filter the updateable keys
      def updateable_fields(context = nil)
        _updateable_associations | _attributes.keys - [:id]
      end

      # Override in your resource to filter the createable keys
      def createable_fields(context = nil)
        _updateable_associations | _attributes.keys
      end

      # Override in your resource to filter the sortable keys
      def sortable_fields(context = nil)
        _attributes.keys
      end

      def fields
        _associations.keys | _attributes.keys
      end

      def apply_includes(records, directives)
        records = records.includes(*directives.model_includes) if directives
        records
      end

      def apply_pagination(records, paginator, order_options)
        if paginator
          records = paginator.apply(records, order_options)
        end
        records
      end

      def apply_sort(records, order_options)
        if order_options.any?
          records.order(order_options)
        else
          records
        end
      end

      def apply_filter(records, filter, value)
        records.where(filter => value)
      end

      def apply_filters(records, filters)
        required_includes = []
        filters.each do |filter, value|
          if _associations.include?(filter)
            if _associations[filter].is_a?(JSONAPI::Association::HasMany)
              required_includes.push(filter)
              records = apply_filter(records, "#{filter}.#{_associations[filter].primary_key}", value)
            else
              records = apply_filter(records, "#{_associations[filter].foreign_key}", value)
            end
          else
            records = apply_filter(records, filter, value)
          end
        end
        if required_includes.any?
          records.includes(required_includes)
        elsif records.respond_to? :to_ary
          records
        else
          records.all
        end
      end

      # Override this method if you have more complex requirements than this basic find method provides
      def find(filters, options = {})
        context = options[:context]
        sort_criteria = options.fetch(:sort_criteria) { [] }
        include_directives = options.fetch(:include_directives, nil)

        resources = []

        records = records(options)
        records = apply_includes(records, include_directives)
        records = apply_filters(records, filters)
        order_options = construct_order_options(sort_criteria)
        records = apply_sort(records, order_options)
        records = apply_pagination(records, options[:paginator], order_options)

        records.each do |model|
          resources.push self.new(model, context)
        end

        return resources
      end

      def find_by_key(key, options = {})
        context = options[:context]
        include_directives = options.fetch(:include_directives, nil)
        records = records(options)
        records = apply_includes(records, include_directives)
        model = records.where({_primary_key => key}).first
        if model.nil?
          raise JSONAPI::Exceptions::RecordNotFound.new(key)
        end
        self.new(model, context)
      end

      # Override this method if you want to customize the relation for
      # finder methods (find, find_by_key)
      def records(options = {})
        _model_class
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
        filter == _type || _associations.include?(filter)
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
        key && Integer(key)
      rescue
        raise JSONAPI::Exceptions::InvalidFieldValue.new(:id, key)
      end

      # override to allow for key processing and checking
      def verify_keys(keys, context = nil)
        return keys.collect do |key|
          verify_key(key, context)
        end
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
      def _attribute_options(attr)
        default_attribute_options.merge(@_attributes[attr])
      end

      def _updateable_associations
        associations = []

        @_associations.each do |key, association|
          associations.push(key)
        end
        associations
      end

      def _has_association?(type)
        type = type.to_s
        @_associations.has_key?(type.singularize.to_sym) || @_associations.has_key?(type.pluralize.to_sym)
      end

      def _association(type)
        type = type.to_sym
        @_associations[type]
      end

      def _model_name
        @_model_name ||= self.name.demodulize.sub(/Resource$/, '')
      end

      def _primary_key
        @_primary_key ||= :id
      end

      def _as_parent_key
        @_as_parent_key ||= "#{_type.to_s.singularize}_#{_primary_key}"
      end

      def _allowed_filters
        !@_allowed_filters.nil? ? @_allowed_filters : Set.new([:id])
      end

      def _resource_name_from_type(type)
        class_name = @@resource_types[type]
        if class_name.nil?
          class_name = "#{type.to_s.singularize}_resource".camelize
          @@resource_types[type] = class_name
        end
        return class_name
      end

      def _paginator
        @_paginator ||= JSONAPI.configuration.default_paginator
      end

      def paginator(paginator)
        @_paginator = paginator
      end

      def _model_class
        @model ||= _model_name.to_s.safe_constantize
      end

      def _allowed_filter?(filter)
        _allowed_filters.include?(filter)
      end

      def module_path
        @module_path ||= self.name =~ /::[^:]+\Z/ ? ($`.freeze.gsub('::', '/') + '/').downcase : ''
      end

      def construct_order_options(sort_params)
        sort_params.each_with_object({}) { |sort, order_hash|
          field = sort[:field] == 'id' ? _primary_key : sort[:field]
          order_hash[field] = sort[:direction]
        }
      end

      private
      def check_reserved_resource_name(type, name)
        if [:ids, :types, :hrefs, :links].include?(type)
          warn "[NAME COLLISION] `#{name}` is a reserved resource name."
          return
        end
      end

      def check_reserved_attribute_name(name)
        # Allow :id since it can be used to specify the format. Since it is a method on the base Resource
        # an attribute method won't be created for it.
        if [:type, :href, :links].include?(name.to_sym)
          warn "[NAME COLLISION] `#{name}` is a reserved key in #{@@resource_types[_type]}."
        end
      end

      def check_reserved_association_name(name)
        if [:id, :ids, :type, :types, :href, :hrefs, :link, :links].include?(name.to_sym)
          warn "[NAME COLLISION] `#{name}` is a reserved association name in #{@@resource_types[_type]}."
        end
      end

      def _associate(klass, *attrs)
        options = attrs.extract_options!
        options[:module_path] = module_path

        attrs.each do |attr|
          check_reserved_association_name(attr)

          @_associations[attr] = klass.new(attr, options)

          foreign_key = @_associations[attr].foreign_key

          define_method foreign_key do
            @model.method(foreign_key).call
          end unless method_defined?(foreign_key)

          define_method "#{foreign_key}=" do |value|
            @model.method("#{foreign_key}=").call(value)
          end unless method_defined?("#{foreign_key}=")

          associated_records_method_name = case @_associations[attr]
          when JSONAPI::Association::HasOne then "record_for_#{attr}"
          when JSONAPI::Association::HasMany then "records_for_#{attr}"
          end

          define_method associated_records_method_name do |options={}|
            records_for(attr, options)
          end unless method_defined?(associated_records_method_name)

          if @_associations[attr].is_a?(JSONAPI::Association::HasOne)
            define_method attr do
              type_name = self.class._associations[attr].type.to_s
              resource_class = Resource.resource_for(self.class.module_path + type_name)
              if resource_class
                associated_model = public_send(associated_records_method_name)
                return associated_model ? resource_class.new(associated_model, @context) : nil
              end
            end unless method_defined?(attr)
          elsif @_associations[attr].is_a?(JSONAPI::Association::HasMany)
            define_method attr do |options = {}|
              type_name = self.class._associations[attr].type.to_s
              resource_class = Resource.resource_for(self.class.module_path + type_name)
              filters = options.fetch(:filters, {})
              sort_criteria =  options.fetch(:sort_criteria, {})
              paginator = options.fetch(:paginator, nil)

              resources = []
              if resource_class
                records = public_send(associated_records_method_name)
                records = self.class.apply_filters(records, filters)
                order_options = self.class.construct_order_options(sort_criteria)
                records = self.class.apply_sort(records, order_options)
                records = self.class.apply_pagination(records, paginator, order_options)
                records.each do |record|
                  resources.push resource_class.new(record, @context)
                end
              end
              return resources
            end unless method_defined?(attr)
          end
        end
      end
    end
  end
end
