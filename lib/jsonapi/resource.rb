require 'jsonapi/callbacks'

module JSONAPI
  class Resource
    include Callbacks

    @@resource_types = {}

    attr_reader :context
    attr_reader :model

    define_jsonapi_resources_callbacks :create,
                                       :update,
                                       :remove,
                                       :save,
                                       :create_has_many_link,
                                       :replace_has_many_links,
                                       :create_has_one_link,
                                       :replace_has_one_link,
                                       :replace_polymorphic_has_one_link,
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
      completed = false

      if @changing
        run_callbacks callback do
          completed = (yield == :completed)
        end
      else
        run_callbacks is_new? ? :create : :update do
          @changing = true
          run_callbacks callback do
            completed = (yield == :completed)
          end

          completed = (save == :completed) if @save_needed || is_new?
        end
      end

      return completed ? :completed : :accepted
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

    def replace_polymorphic_has_one_link(association_type, association_key_value, association_key_type)
      change :replace_polymorphic_has_one_link do
        _replace_polymorphic_has_one_link(association_type, association_key_value, association_key_type)
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
    def records_for(association_name, _options = {})
      model.send association_name
    end

    private

    def save
      run_callbacks :save do
        _save
      end
    end

    # Override this on a resource to return a different result code. Any
    # value other than :completed will result in operations returning
    # `:accepted`
    #
    # For example to return `:accepted` if your model does not immediately
    # save resources to the database you could override `_save` as follows:
    #
    # ```
    # def _save
    #   super
    #   return :accepted
    # end
    # ```
    def _save
      unless @model.valid?
        fail JSONAPI::Exceptions::ValidationErrors.new(@model.errors.messages)
      end

      if defined? @model.save
        saved = @model.save
        fail JSONAPI::Exceptions::SaveFailed.new unless saved
      else
        saved = true
      end

      @save_needed = !saved

      :completed
    end

    def _remove
      @model.destroy

      :completed
    end

    def _create_has_many_links(association_type, association_key_values)
      association = self.class._associations[association_type]

      association_key_values.each do |association_key_value|
        related_resource = association.resource_klass.find_by_key(association_key_value, context: @context)

        # TODO: Add option to skip relations that already exist instead of returning an error?
        relation = @model.send(association.type).where(association.primary_key => association_key_value).first
        if relation.nil?
          @model.send(association.type) << related_resource.model
        else
          fail JSONAPI::Exceptions::HasManyRelationExists.new(association_key_value)
        end
      end

      :completed
    end

    def _replace_has_many_links(association_type, association_key_values)
      association = self.class._associations[association_type]

      send("#{association.foreign_key}=", association_key_values)
      @save_needed = true

      :completed
    end

    def _replace_has_one_link(association_type, association_key_value)
      association = self.class._associations[association_type]

      send("#{association.foreign_key}=", association_key_value)
      @save_needed = true

      :completed
    end

    def _replace_polymorphic_has_one_link(association_type, key_value, key_type)
      association = self.class._associations[association_type.to_sym]

      model.send("#{association.foreign_key}=", key_value)
      model.send("#{association.polymorphic_type}=", key_type.to_s.classify)

      @save_needed = true

      :completed
    end

    def _remove_has_many_link(association_type, key)
      association = self.class._associations[association_type]

      @model.send(association.type).delete(key)

      :completed
    end

    def _remove_has_one_link(association_type)
      association = self.class._associations[association_type]

      send("#{association.foreign_key}=", nil)
      @save_needed = true

      :completed
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
          case value
          when Hash
            replace_polymorphic_has_one_link(association_type.to_s, value.fetch(:id), value.fetch(:type))
          else
            replace_has_one_link(association_type, value)
          end
        end
      end if field_data[:has_one]

      field_data[:has_many].each do |association_type, values|
        replace_has_many_links(association_type, values)
      end if field_data[:has_many]

      :completed
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
          fail NameError, "JSONAPI: Could not find resource '#{type}'. (Class #{resource_name} not found)"
        end
        resource
      end

      attr_accessor :_attributes, :_associations, :_allowed_filters, :_type, :_paginator

      def create(context)
        new(create_model, context)
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
        options = attrs.extract_options!.dup
        attrs.each do |attr|
          attribute(attr, options)
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
        { format: :default }
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
        @_allowed_filters.merge!(attrs.inject({}) { |h, attr| h[attr] = {}; h })
      end

      def filter(attr, *args)
        @_allowed_filters[attr.to_sym] = args.extract_options!
      end

      def primary_key(key)
        @_primary_key = key.to_sym
      end

      # TODO: remove this after the createable_fields and updateable_fields are phased out
      # :nocov:
      def method_missing(method, *args)
        if method.to_s.match /createable_fields/
          ActiveSupport::Deprecation.warn('`createable_fields` is deprecated, please use `creatable_fields` instead')
          creatable_fields(*args)
        elsif method.to_s.match /updateable_fields/
          ActiveSupport::Deprecation.warn('`updateable_fields` is deprecated, please use `updatable_fields` instead')
          updatable_fields(*args)
        else
          super
        end
      end
      # :nocov:

      # Override in your resource to filter the updatable keys
      def updatable_fields(_context = nil)
        _updatable_associations | _attributes.keys - [:id]
      end

      # Override in your resource to filter the creatable keys
      def creatable_fields(_context = nil)
        _updatable_associations | _attributes.keys
      end

      # Override in your resource to filter the sortable keys
      def sortable_fields(_context = nil)
        _attributes.keys
      end

      def fields
        _associations.keys | _attributes.keys
      end

      def resolve_association_names_to_relations(resource_klass, model_includes, options = {})
        case model_includes
          when Array
            return model_includes.map do |value|
              resolve_association_names_to_relations(resource_klass, value, options)
            end
          when Hash
            model_includes.keys.each do |key|
              association = resource_klass._associations[key]
              value = model_includes[key]
              model_includes.delete(key)
              model_includes[association.relation_name(options)] = resolve_association_names_to_relations(association.resource_klass, value, options)
            end
            return model_includes
          when Symbol
            association = resource_klass._associations[model_includes]
            return association.relation_name(options)
        end
      end

      def apply_includes(records, options = {})
        include_directives = options[:include_directives]
        if include_directives
          model_includes = resolve_association_names_to_relations(self, include_directives.model_includes, options)
          records = records.includes(model_includes)
        end

        records
      end

      def apply_pagination(records, paginator, order_options)
        records = paginator.apply(records, order_options) if paginator
        records
      end

      def apply_sort(records, order_options)
        if order_options.any?
          records.order(order_options)
        else
          records
        end
      end

      def apply_filter(records, filter, value, _options = {})
        records.where(filter => value)
      end

      def apply_filters(records, filters, options = {})
        required_includes = []

        if filters
          filters.each do |filter, value|
            if _associations.include?(filter)
              if _associations[filter].is_a?(JSONAPI::Association::HasMany)
                required_includes.push(filter.to_s)
                records = apply_filter(records, "#{filter}.#{_associations[filter].primary_key}", value, options)
              else
                records = apply_filter(records, "#{_associations[filter].foreign_key}", value, options)
              end
            else
              records = apply_filter(records, filter, value, options)
            end
          end
        end

        if required_includes.any?
          records = apply_includes(records, options.merge(include_directives: IncludeDirectives.new(required_includes)))
        end

        records
      end

      def filter_records(filters, options)
        records = records(options)
        records = apply_filters(records, filters, options)
        apply_includes(records, options)
      end

      def sort_records(records, order_options)
        apply_sort(records, order_options)
      end

      def find_count(filters, options = {})
        filter_records(filters, options).count
      end

      # Override this method if you have more complex requirements than this basic find method provides
      def find(filters, options = {})
        context = options[:context]

        records = filter_records(filters, options)

        sort_criteria = options.fetch(:sort_criteria) { [] }
        order_options = construct_order_options(sort_criteria)
        records = sort_records(records, order_options)

        records = apply_pagination(records, options[:paginator], order_options)

        resources = []
        records.each do |model|
          resources.push new(model, context)
        end

        resources
      end

      def find_by_key(key, options = {})
        context = options[:context]
        records = records(options)
        records = apply_includes(records, options)
        model = records.where({_primary_key => key}).first
        fail JSONAPI::Exceptions::RecordNotFound.new(key) if model.nil?
        new(model, context)
      end

      # Override this method if you want to customize the relation for
      # finder methods (find, find_by_key)
      def records(_options = {})
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
      def verify_key(key, _context = nil)
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
      def verify_custom_filter(filter, value, _context = nil)
        [filter, value]
      end

      # override to allow for custom association logic, such as uuids, multiple keys or permission checks on keys
      def verify_association_filter(filter, raw, _context = nil)
        [filter, raw]
      end

      # quasi private class methods
      def _attribute_options(attr)
        default_attribute_options.merge(@_attributes[attr])
      end

      def _updatable_associations
        @_associations.map { |key, _association| key }
      end

      def _has_association?(type)
        type = type.to_s
        @_associations.key?(type.singularize.to_sym) || @_associations.key?(type.pluralize.to_sym)
      end

      def _association(type)
        type = type.to_sym
        @_associations[type]
      end

      def _model_name
        @_model_name ||= name.demodulize.sub(/Resource$/, '')
      end

      def _primary_key
        @_primary_key ||= :id
      end

      def _as_parent_key
        @_as_parent_key ||= "#{_type.to_s.singularize}_#{_primary_key}"
      end

      def _allowed_filters
        !@_allowed_filters.nil? ? @_allowed_filters : { id: {} }
      end

      def _resource_name_from_type(type)
        class_name = @@resource_types[type]
        if class_name.nil?
          class_name = "#{type.to_s.underscore.singularize}_resource".camelize
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
        !_allowed_filters[filter].nil?
      end

      def module_path
        @module_path ||= name =~ /::[^:]+\Z/ ? ($`.freeze.gsub('::', '/') + '/').downcase : ''
      end

      def construct_order_options(sort_params)
        return {} unless sort_params

        sort_params.each_with_object({}) do |sort, order_hash|
          field = sort[:field] == 'id' ? _primary_key : sort[:field]
          order_hash[field] = sort[:direction]
        end
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
        if [:type, :href, :links, :model].include?(name.to_sym)
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
          @_associations[attr] = association = klass.new(attr, options)

          associated_records_method_name = case association
                                           when JSONAPI::Association::HasOne then "record_for_#{attr}"
                                           when JSONAPI::Association::HasMany then "records_for_#{attr}"
                                           end

          foreign_key = association.foreign_key

          define_method "#{foreign_key}=" do |value|
            @model.method("#{foreign_key}=").call(value)
          end unless method_defined?("#{foreign_key}=")

          define_method associated_records_method_name do |options = {}|
            options = options.merge({context: @context})
            relation_name = association.relation_name(options)
            records_for(relation_name, options)
          end unless method_defined?(associated_records_method_name)

          if association.is_a?(JSONAPI::Association::HasOne)
            define_method foreign_key do
              @model.method(foreign_key).call
            end unless method_defined?(foreign_key)

            define_method attr do |options = {}|
              if association.polymorphic?
                associated_model = public_send(associated_records_method_name)
                resource_klass = Resource.resource_for(self.class.module_path + associated_model.class.to_s.underscore) if associated_model
                return resource_klass.new(associated_model, @context) if resource_klass
              else
                resource_klass = association.resource_klass
                if resource_klass
                  associated_model = public_send(associated_records_method_name)
                  return associated_model ? resource_klass.new(associated_model, @context) : nil
                end
              end
            end unless method_defined?(attr)
          elsif association.is_a?(JSONAPI::Association::HasMany)
            define_method foreign_key do
              records = public_send(associated_records_method_name)
              return records.collect do |record|
                record.send(association.resource_klass._primary_key)
              end
            end unless method_defined?(foreign_key)
            define_method attr do |options = {}|
              resource_klass = association.resource_klass
              records = public_send(associated_records_method_name)

              filters = options.fetch(:filters, {})
              unless filters.nil? || filters.empty?
                records = resource_klass.apply_filters(records, filters, options)
              end

              sort_criteria =  options.fetch(:sort_criteria, {})
              unless sort_criteria.nil? || sort_criteria.empty?
                order_options = self.class.construct_order_options(sort_criteria)
                records = resource_klass.apply_sort(records, order_options)
              end

              paginator = options[:paginator]
              if paginator
                records = resource_klass.apply_pagination(records, paginator, order_options)
              end

              return records.collect do |record|
                if association.polymorphic?
                  resource_klass = Resource.resource_for(self.class.module_path + record.class.to_s.underscore)
                end
                resource_klass.new(record, @context)
              end
            end unless method_defined?(attr)
          end
        end
      end
    end
  end
end
