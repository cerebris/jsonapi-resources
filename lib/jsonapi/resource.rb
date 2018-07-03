require 'jsonapi/callbacks'
require 'jsonapi/configuration'

module JSONAPI
  class Resource
    include Callbacks

    attr_reader :context

    define_jsonapi_resources_callbacks :create,
                                       :update,
                                       :remove,
                                       :save,
                                       :create_to_many_link,
                                       :replace_to_many_links,
                                       :create_to_one_link,
                                       :replace_to_one_link,
                                       :replace_polymorphic_to_one_link,
                                       :remove_to_many_link,
                                       :remove_to_one_link,
                                       :replace_fields

    def initialize(model, context)
      @model = model
      @context = context
      @reload_needed = false
      @changing = false
      @save_needed = false
    end

    def _model
      @model
    end

    def id
      _model.public_send(self.class._primary_key)
    end

    def identity
      JSONAPI::ResourceIdentity.new(self.class, id)
    end

    def cache_id
      [id, self.class.hash_cache_field(_model.public_send(self.class._cache_field))]
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

    def create_to_many_links(relationship_type, relationship_key_values, options = {})
      change :create_to_many_link do
        _create_to_many_links(relationship_type, relationship_key_values, options)
      end
    end

    def replace_to_many_links(relationship_type, relationship_key_values, options = {})
      change :replace_to_many_links do
        _replace_to_many_links(relationship_type, relationship_key_values, options)
      end
    end

    def replace_to_one_link(relationship_type, relationship_key_value, options = {})
      change :replace_to_one_link do
        _replace_to_one_link(relationship_type, relationship_key_value, options)
      end
    end

    def replace_polymorphic_to_one_link(relationship_type, relationship_key_value, relationship_key_type, options = {})
      change :replace_polymorphic_to_one_link do
        _replace_polymorphic_to_one_link(relationship_type, relationship_key_value, relationship_key_type, options)
      end
    end

    def remove_to_many_link(relationship_type, key, options = {})
      change :remove_to_many_link do
        _remove_to_many_link(relationship_type, key, options)
      end
    end

    def remove_to_one_link(relationship_type, options = {})
      change :remove_to_one_link do
        _remove_to_one_link(relationship_type, options)
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

    def model_error_messages
      _model.errors.messages
    end

    # Add metadata to validation error objects.
    #
    # Suppose `model_error_messages` returned the following error messages
    # hash:
    #
    #   {password: ["too_short", "format"]}
    #
    # Then to add data to the validation error `validation_error_metadata`
    # could return:
    #
    #   {
    #     password: {
    #       "too_short": {"minimum_length" => 6},
    #       "format": {"requirement" => "must contain letters and numbers"}
    #     }
    #   }
    #
    # The specified metadata is then be merged into the validation error
    # object.
    def validation_error_metadata
      {}
    end

    # Override this to return resource level meta data
    # must return a hash, and if the hash is empty the meta section will not be serialized with the resource
    # meta keys will be not be formatted with the key formatter for the serializer by default. They can however use the
    # serializer's format_key and format_value methods if desired
    # the _options hash will contain the serializer and the serialization_options
    def meta(_options)
      {}
    end

    # Override this to return custom links
    # must return a hash, which will be merged with the default { self: 'self-url' } links hash
    # links keys will be not be formatted with the key formatter for the serializer by default.
    # They can however use the serializer's format_key and format_value methods if desired
    # the _options hash will contain the serializer and the serialization_options
    def custom_links(_options)
      {}
    end

    # Override this to change the default
    # A value of false will cause a filter value of 'a,b' -> IN ('a','b')
    # A value of true will cause a filter value of 'a,b' -> ('a,b')
    def self.parse_values_as_array
      true
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
    def _save(validation_context = nil)
      unless @model.valid?(validation_context)
        fail JSONAPI::Exceptions::ValidationErrors.new(self)
      end

      if defined? @model.save
        saved = @model.save(validate: false)

        unless saved
          if @model.errors.present?
            fail JSONAPI::Exceptions::ValidationErrors.new(self)
          else
            fail JSONAPI::Exceptions::SaveFailed.new
          end
        end
      else
        saved = true
      end
      @model.reload if @reload_needed
      @reload_needed = false

      @save_needed = !saved

      :completed
    end

    def _remove
      unless @model.destroy
        fail JSONAPI::Exceptions::ValidationErrors.new(self)
      end
      :completed

    rescue ActiveRecord::DeleteRestrictionError => e
      fail JSONAPI::Exceptions::RecordLocked.new(e.message)
    end

    def reflect_relationship?(relationship, options)
      return false if !relationship.reflect ||
        (!JSONAPI.configuration.use_relationship_reflection || options[:reflected_source])

      inverse_relationship = relationship.resource_klass._relationships[relationship.inverse_relationship]
      if inverse_relationship.nil?
        warn "Inverse relationship could not be found for #{self.class.name}.#{relationship.name}. Relationship reflection disabled."
        return false
      end
      true
    end

    def _create_to_many_links(relationship_type, relationship_key_values, options)
      relationship = self.class._relationships[relationship_type]

      # check if relationship_key_values are already members of this relationship
      relation_name = relationship.relation_name(context: @context)
      existing_relations = @model.public_send(relation_name).where(relationship.primary_key => relationship_key_values)
      if existing_relations.count > 0
        # todo: obscure id so not to leak info
        fail JSONAPI::Exceptions::HasManyRelationExists.new(existing_relations.first.id)
      end

      if options[:reflected_source]
        @model.public_send(relation_name) << options[:reflected_source]._model
        return :completed
      end

      # load requested related resources
      # make sure they all exist (also based on context) and add them to relationship

      related_resources = relationship.resource_klass.find_by_keys(relationship_key_values, context: @context)

      if related_resources.count != relationship_key_values.count
        # todo: obscure id so not to leak info
        fail JSONAPI::Exceptions::RecordNotFound.new('unspecified')
      end

      reflect = reflect_relationship?(relationship, options)

      related_resources.each do |related_resource|
        if reflect
          if related_resource.class._relationships[relationship.inverse_relationship].is_a?(JSONAPI::Relationship::ToMany)
            related_resource.create_to_many_links(relationship.inverse_relationship, [id], reflected_source: self)
          else
            related_resource.replace_to_one_link(relationship.inverse_relationship, id, reflected_source: self)
          end
          @reload_needed = true
        else
          @model.public_send(relation_name) << related_resource._model
        end
      end

      :completed
    end

    def _replace_to_many_links(relationship_type, relationship_key_values, options)
      relationship = self.class._relationships[relationship_type]

      reflect = reflect_relationship?(relationship, options)

      if reflect
        existing_rids = self.class.find_related_fragments([identity], relationship_type, options)

        existing = existing_rids.keys.collect { |rid| rid.id }

        to_delete = existing - (relationship_key_values & existing)
        to_delete.each do |key|
          _remove_to_many_link(relationship_type, key, reflected_source: self)
        end

        to_add = relationship_key_values - (relationship_key_values & existing)
        _create_to_many_links(relationship_type, to_add, {})

        @reload_needed = true
      else
        send("#{relationship.foreign_key}=", relationship_key_values)
        @save_needed = true
      end

      :completed
    end

    def _replace_to_one_link(relationship_type, relationship_key_value, _options)
      relationship = self.class._relationships[relationship_type]

      send("#{relationship.foreign_key}=", relationship_key_value)
      @save_needed = true

      :completed
    end

    def _replace_polymorphic_to_one_link(relationship_type, key_value, key_type, _options)
      relationship = self.class._relationships[relationship_type.to_sym]

      send("#{relationship.foreign_key}=", {type: key_type, id: key_value})
      @save_needed = true

      :completed
    end

    def _remove_to_many_link(relationship_type, key, options)
      relationship = self.class._relationships[relationship_type]

      reflect = reflect_relationship?(relationship, options)

      if reflect

        related_resource = relationship.resource_klass.find_by_key(key, context: @context)

        if related_resource.nil?
          fail JSONAPI::Exceptions::RecordNotFound.new(key)
        else
          if related_resource.class._relationships[relationship.inverse_relationship].is_a?(JSONAPI::Relationship::ToMany)
            related_resource.remove_to_many_link(relationship.inverse_relationship, id, reflected_source: self)
          else
            related_resource.remove_to_one_link(relationship.inverse_relationship, reflected_source: self)
          end
        end

        @reload_needed = true
      else
        @model.public_send(relationship.relation_name(context: @context)).delete(key)
      end

      :completed

    rescue ActiveRecord::DeleteRestrictionError => e
      fail JSONAPI::Exceptions::RecordLocked.new(e.message)
    rescue ActiveRecord::RecordNotFound
      fail JSONAPI::Exceptions::RecordNotFound.new(key)
    end

    def _remove_to_one_link(relationship_type, _options)
      relationship = self.class._relationships[relationship_type]

      send("#{relationship.foreign_key}=", nil)
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

      field_data[:to_one].each do |relationship_type, value|
        if value.nil?
          remove_to_one_link(relationship_type)
        else
          case value
          when Hash
            replace_polymorphic_to_one_link(relationship_type.to_s, value.fetch(:id), value.fetch(:type))
          else
            replace_to_one_link(relationship_type, value)
          end
        end
      end if field_data[:to_one]

      field_data[:to_many].each do |relationship_type, values|
        replace_to_many_links(relationship_type, values)
      end if field_data[:to_many]

      :completed
    end

    class << self
      def inherited(subclass)
        subclass.abstract(false)
        subclass.immutable(false)
        subclass.caching(_caching)
        subclass.paginator(_paginator)
        subclass._attributes = (_attributes || {}).dup

        subclass._model_hints = (_model_hints || {}).dup

        unless _model_name.empty? || _immutable
          subclass.model_name(_model_name, add_model_hint: (_model_hints && !_model_hints[_model_name].nil?) == true)
        end

        subclass.rebuild_relationships(_relationships || {})

        subclass._allowed_filters = (_allowed_filters || Set.new).dup

        subclass._allowed_sort = _allowed_sort.dup

        type = subclass.name.demodulize.sub(/Resource$/, '').underscore
        subclass._type = type.pluralize.to_sym

        unless subclass._attributes[:id]
          subclass.attribute :id, format: :id, readonly: true
        end

        check_reserved_resource_name(subclass._type, subclass.name)

        subclass.include JSONAPI.configuration.resource_finder if JSONAPI.configuration.resource_finder
      end

      # A ResourceFinder is a mixin that adds functionality to find Resources and Resource Fragments
      # to the core Resource class.
      #
      # Resource fragments are a hash with the following format:
      # {
      #   identity: <required: a ResourceIdentity>,
      #   cache: <optional: the resource's cache value>
      #   attributes: <optional: attributes hash for attributes requested - currently unused>
      #   related: {
      #     <relationship_name>: <ResourceIndentity of a source resource in find_related_fragments>
      #   }
      # }
      #
      # begin ResourceFinder Abstract methods
        def find(_filters, _options = {})
          # :nocov:
          raise 'Abstract ResourceFinder method called. Ensure that a ResourceFinder has been set.'
          # :nocov:
        end

        def count(_filters, _options = {})
          # :nocov:
          raise 'Abstract ResourceFinder method called. Ensure that a ResourceFinder has been set.'
          # :nocov:
        end

        def find_by_keys(_keys, _options = {})
          # :nocov:
          raise 'Abstract ResourceFinder method called. Ensure that a ResourceFinder has been set.'
          # :nocov:
        end

        def find_by_key(_key, _options = {})
          # :nocov:
          raise 'Abstract ResourceFinder method called. Ensure that a ResourceFinder has been set.'
          # :nocov:
        end

        def find_fragments(_filters, _options = {})
          # :nocov:
          raise 'Abstract ResourceFinder method called. Ensure that a ResourceFinder has been set.'
          # :nocov:
        end

        def find_related_fragments(_source_rids, _relationship_name, _options = {})
          # :nocov:
          raise 'Abstract ResourceFinder method called. Ensure that a ResourceFinder has been set.'
          # :nocov:
        end

        def count_related(_source_rid, _relationship_name, _options = {})
          # :nocov:
          raise 'Abstract ResourceFinder method called. Ensure that a ResourceFinder has been set.'
          # :nocov:
        end

      #end ResourceFinder Abstract methods

      def rebuild_relationships(relationships)
        original_relationships = relationships.deep_dup

        @_relationships = {}

        if original_relationships.is_a?(Hash)
          original_relationships.each_value do |relationship|
            options = relationship.options.dup
            options[:parent_resource] = self
            options[:inverse_relationship] = relationship.inverse_relationship
            _add_relationship(relationship.class, relationship.name, options)
          end
        end
      end

      def resource_klass_for(type)
        type = type.underscore
        type_with_module = type.start_with?(module_path) ? type : module_path + type

        resource_name = _resource_name_from_type(type_with_module)
        resource = resource_name.safe_constantize if resource_name
        if resource.nil?
          fail NameError, "JSONAPI: Could not find resource '#{type}'. (Class #{resource_name} not found)"
        end
        resource
      end

      def resource_klass_for_model(model)
        resource_klass_for(resource_type_for(model))
      end

      def _resource_name_from_type(type)
        "#{type.to_s.underscore.singularize}_resource".camelize
      end

      def resource_type_for(model)
        model_name = model.class.to_s.underscore
        if _model_hints[model_name]
          _model_hints[model_name]
        else
          model_name.rpartition('/').last
        end
      end

      def model_name_for_type(key_type)
        type_class_name = key_type.to_s.classify
        resource_klass = resource_klass_for(type_class_name)
        resource_klass ? resource_klass._model_name.to_s : type_class_name
      end

      attr_accessor :_attributes, :_relationships, :_type, :_model_hints
      attr_writer :_allowed_filters, :_paginator, :_allowed_sort

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

      def attribute(attribute_name, options = {})
        attr = attribute_name.to_sym

        check_reserved_attribute_name(attr)

        if (attr == :id) && (options[:format].nil?)
          ActiveSupport::Deprecation.warn('Id without format is no longer supported. Please remove ids from attributes, or specify a format.')
        end

        check_duplicate_attribute_name(attr) if options[:format].nil?

        @_attributes ||= {}
        @_attributes[attr] = options
        define_method attr do
          @model.public_send(options[:delegate] ? options[:delegate].to_sym : attr)
        end unless method_defined?(attr)

        define_method "#{attr}=" do |value|
          @model.public_send("#{options[:delegate] ? options[:delegate].to_sym : attr}=", value)
        end unless method_defined?("#{attr}=")

        if options.fetch(:sortable, true) && !_has_sort?(attr)
          sort attr
        end
      end

      def attribute_to_model_field(attribute)
        field_name = if attribute == :_cache_field
                       _cache_field
                     else
                       # Note: this will allow the returning of model attributes without a corresponding
                       # resource attribute, for example a belongs_to id such as `author_id` or bypassing
                       # the delegate.
                       attr = @_attributes[attribute]
                       attr && attr[:delegate] ? attr[:delegate].to_sym : attribute
                     end
        if Rails::VERSION::MAJOR >= 5
          attribute_type = _model_class.attribute_types[field_name.to_s]
        else
          attribute_type = _model_class.column_types[field_name.to_s]
        end
        { name: field_name, type: attribute_type}
      end

      def cast_to_attribute_type(value, type)
        if Rails::VERSION::MAJOR >= 5
          return type.cast(value)
        else
          return type.type_cast_from_database(value)
        end
      end

      def default_attribute_options
        { format: :default }
      end

      def relationship(*attrs)
        options = attrs.extract_options!
        klass = case options[:to]
                  when :one
                    Relationship::ToOne
                  when :many
                    Relationship::ToMany
                  else
                    #:nocov:#
                    fail ArgumentError.new('to: must be either :one or :many')
                    #:nocov:#
                end
        _add_relationship(klass, *attrs, options.except(:to))
      end

      def has_one(*attrs)
        _add_relationship(Relationship::ToOne, *attrs)
      end

      def belongs_to(*attrs)
        ActiveSupport::Deprecation.warn "In #{name} you exposed a `has_one` relationship "\
                                        " using the `belongs_to` class method. We think `has_one`" \
                                        " is more appropriate. If you know what you're doing," \
                                        " and don't want to see this warning again, override the" \
                                        " `belongs_to` class method on your resource."
        _add_relationship(Relationship::ToOne, *attrs)
      end

      def has_many(*attrs)
        _add_relationship(Relationship::ToMany, *attrs)
      end

      def model_name(model, options = {})
        @_model_name = model.to_sym

        model_hint(model: @_model_name, resource: self) unless options[:add_model_hint] == false

        rebuild_relationships(_relationships)
      end

      def model_hint(model: _model_name, resource: _type)
        resource_type = ((resource.is_a?(Class)) && (resource < JSONAPI::Resource)) ? resource._type : resource.to_s

        _model_hints[model.to_s.gsub('::', '/').underscore] = resource_type.to_s
      end

      def filters(*attrs)
        @_allowed_filters.merge!(attrs.inject({}) { |h, attr| h[attr] = {}; h })
      end

      def filter(attr, *args)
        @_allowed_filters[attr.to_sym] = args.extract_options!
      end

      def sort(sorting, options = {})
        self._allowed_sort[sorting.to_sym] = options
      end

      def sorts(*args)
        options = args.extract_options!
        _allowed_sort.merge!(args.inject({}) { |h, sorting| h[sorting.to_sym] = options.dup; h })
      end

      def primary_key(key)
        @_primary_key = key.to_sym
      end

      def cache_field(field)
        @_cache_field = field.to_sym
      end

      # Override in your resource to filter the updatable keys
      def updatable_fields(_context = nil)
        _updatable_relationships | _updatable_attributes - [:id]
      end

      # Override in your resource to filter the creatable keys
      def creatable_fields(_context = nil)
        _updatable_relationships | _updatable_attributes
      end

      # Override in your resource to filter the sortable keys
      def sortable_fields(_context = nil)
        _allowed_sort.keys
      end

      def sortable_field?(key, context = nil)
        sortable_fields(context).include? key.to_sym
      end

      def fields
        _relationships.keys | _attributes.keys
      end

      def _lookup_association_chain(model_names)
        associations = []
        model_names.inject do |prev, current|
          association = prev.classify.constantize.reflect_on_all_associations.detect do |assoc|
            assoc.name.to_s.downcase == current.downcase
          end
          associations << association
          association.class_name
        end

        associations
      end

      def find_count(filters, options = {})
        # ToDo: Deprecation warning
        count(filters, options)
      end

      def records(options = {})
        _model_class.all
      end

      def resources_for(records, context)
        records.collect do |record|
          resource_for(record, context)
        end
      end

      def resource_for(model_record, context)
        resource_klass = self.resource_klass_for_model(model_record)
        resource_klass.new(model_record, context)
      end

      def verify_filters(filters, context = nil)
        verified_filters = {}
        filters.each do |filter, raw_value|
          verified_filter = verify_filter(filter, raw_value, context)
          verified_filters[verified_filter[0]] = verified_filter[1]
        end
        verified_filters
      end

      def is_filter_relationship?(filter)
        filter == _type || _relationships.include?(filter)
      end

      def verify_filter(filter, raw, context = nil)
        filter_values = []
        if raw.present?
          begin
            filter_values += if self.parse_values_as_array
                                 raw.is_a?(String) ? CSV.parse_line(raw) : [raw]
                               else
                                 [raw]
                               end
          rescue CSV::MalformedCSVError
            filter_values << raw
          end
        end

        strategy = _allowed_filters.fetch(filter, Hash.new)[:verify]

        if strategy
          values = call_method_or_proc(strategy, filter_values, context)
          [filter, values]
        else
          if is_filter_relationship?(filter)
            verify_relationship_filter(filter, filter_values, context)
          else
            verify_custom_filter(filter, filter_values, context)
          end
        end
      end

      def call_method_or_proc(strategy, *args)
        if strategy.is_a?(Symbol) || strategy.is_a?(String)
          send(strategy, *args)
        else
          strategy.call(*args)
        end
      end

      def key_type(key_type)
        @_resource_key_type = key_type
      end

      def resource_key_type
        @_resource_key_type ||= JSONAPI.configuration.resource_key_type
      end

      def verify_key(key, context = nil)
        key_type = resource_key_type

        case key_type
        when :integer
          return if key.nil?
          Integer(key)
        when :string
          return if key.nil?
          if key.to_s.include?(',')
            raise JSONAPI::Exceptions::InvalidFieldValue.new(:id, key)
          else
            key
          end
        when :uuid
          return if key.nil?
          if key.to_s.match(/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/)
            key
          else
            raise JSONAPI::Exceptions::InvalidFieldValue.new(:id, key)
          end
        else
          key_type.call(key, context)
        end
      rescue
        raise JSONAPI::Exceptions::InvalidFieldValue.new(:id, key)
      end

      # override to allow for key processing and checking
      def verify_keys(keys, context = nil)
        return keys.collect do |key|
          verify_key(key, context)
        end
      end

      # Either add a custom :verify lambda or override verify_custom_filter to allow for custom filters
      def verify_custom_filter(filter, value, _context = nil)
        [filter, value]
      end

      # Either add a custom :verify lambda or override verify_relationship_filter to allow for custom
      # relationship logic, such as uuids, multiple keys or permission checks on keys
      def verify_relationship_filter(filter, raw, _context = nil)
        [filter, raw]
      end

      # quasi private class methods
      def _attribute_options(attr)
        default_attribute_options.merge(@_attributes[attr])
      end

      def _attribute_delegated_name(attr)
        @_attributes.fetch(attr.to_sym, {}).fetch(:delegate, attr)
      end

      def _has_attribute?(attr)
        @_attributes.keys.include?(attr.to_sym)
      end

      def _updatable_attributes
        _attributes.map { |key, options| key unless options[:readonly] }.compact
      end

      def _updatable_relationships
        @_relationships.map { |key, relationship| key unless relationship.readonly? }.compact
      end

      def _relationship(type)
        type = type.to_sym
        @_relationships[type]
      end

      def _model_name
        if _abstract
          return ''
        else
          return @_model_name.to_s if defined?(@_model_name)
          class_name = self.name
          return '' if class_name.nil?
          @_model_name = class_name.demodulize.sub(/Resource$/, '')
          return @_model_name.to_s
        end
      end

      def _primary_key
        @_primary_key ||= _default_primary_key
      end

      def _default_primary_key
        @_default_primary_key ||=_model_class.respond_to?(:primary_key) ? _model_class.primary_key : :id
      end

      def _cache_field
        @_cache_field ||= JSONAPI.configuration.default_resource_cache_field
      end

      def _table_name
        @_table_name ||= _model_class.respond_to?(:table_name) ? _model_class.table_name : _model_name.tableize
      end

      def _as_parent_key
        @_as_parent_key ||= "#{_type.to_s.singularize}_id"
      end

      def _allowed_filters
        defined?(@_allowed_filters) ? @_allowed_filters : { id: {} }
      end

      def _allowed_sort
        @_allowed_sort ||= {}
      end

      def _paginator
        @_paginator ||= JSONAPI.configuration.default_paginator
      end

      def paginator(paginator)
        @_paginator = paginator
      end

      def abstract(val = true)
        @abstract = val
      end

      def _abstract
        @abstract
      end

      def immutable(val = true)
        @immutable = val
      end

      def _immutable
        @immutable
      end

      def mutable?
        !@immutable
      end

      def caching(val = true)
        @caching = val
      end

      def _caching
        @caching
      end

      def caching?
        if @caching.nil?
          !JSONAPI.configuration.resource_cache.nil? && JSONAPI.configuration.default_caching
        else
          @caching && !JSONAPI.configuration.resource_cache.nil?
        end
      end

      def attribute_caching_context(_context)
        nil
      end

      # Generate a hashcode from the value to be used as part of the cache lookup
      def hash_cache_field(value)
        value.hash
      end

      def _model_class
        return nil if _abstract

        return @model_class if @model_class

        model_name = _model_name
        return nil if model_name.to_s.blank?

        @model_class = model_name.to_s.safe_constantize
        if @model_class.nil?
          warn "[MODEL NOT FOUND] Model could not be found for #{self.name}. If this is a base Resource declare it as abstract."
        end

        @model_class
      end

      def _allowed_filter?(filter)
        !_allowed_filters[filter].nil?
      end

      def _has_sort?(sorting)
        !_allowed_sort[sorting.to_sym].nil?
      end

      def module_path
        if name == 'JSONAPI::Resource'
          ''
        else
          name =~ /::[^:]+\Z/ ? ($`.freeze.gsub('::', '/') + '/').underscore : ''
        end
      end

      def default_sort
        [{field: 'id', direction: :asc}]
      end

      def construct_order_options(sort_params)
        sort_params ||= default_sort

        return {} unless sort_params

        sort_params.each_with_object({}) do |sort, order_hash|
          field = sort[:field].to_s == 'id' ? _primary_key : sort[:field].to_s
          order_hash[field] = sort[:direction]
        end
      end

      def _add_relationship(klass, *attrs)
        options = attrs.extract_options!
        options[:parent_resource] = self

        attrs.each do |name|
          relationship_name = name.to_sym
          check_reserved_relationship_name(relationship_name)
          check_duplicate_relationship_name(relationship_name)

          define_relationship_methods(relationship_name.to_sym, klass, options)
        end
      end

      #   ResourceBuilder methods
      def define_relationship_methods(relationship_name, relationship_klass, options)
        relationship = register_relationship(
            relationship_name,
            relationship_klass.new(relationship_name, options)
        )

        define_foreign_key_setter(relationship)
      end

      def define_foreign_key_setter(relationship)
        if relationship.polymorphic?
          define_on_resource "#{relationship.foreign_key}=" do |v|
            _model.method("#{relationship.foreign_key}=").call(v[:id])
            _model.public_send("#{relationship.polymorphic_type}=", v[:type])
          end
        else
          define_on_resource "#{relationship.foreign_key}=" do |value|
            _model.method("#{relationship.foreign_key}=").call(value)
          end
        end
      end

      def define_on_resource(method_name, &block)
        return if method_defined?(method_name)
        define_method(method_name, block)
      end

      def register_relationship(name, relationship_object)
        @_relationships[name] = relationship_object
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
        if [:type, :_cache_field, :cache_field].include?(name.to_sym)
          warn "[NAME COLLISION] `#{name}` is a reserved key in #{_resource_name_from_type(_type)}."
        end
      end

      def check_reserved_relationship_name(name)
        if [:id, :ids, :type, :types].include?(name.to_sym)
          warn "[NAME COLLISION] `#{name}` is a reserved relationship name in #{_resource_name_from_type(_type)}."
        end
      end

      def check_duplicate_relationship_name(name)
        if _relationships.include?(name.to_sym)
          warn "[DUPLICATE RELATIONSHIP] `#{name}` has already been defined in #{_resource_name_from_type(_type)}."
        end
      end

      def check_duplicate_attribute_name(name)
        if _attributes.include?(name.to_sym)
          warn "[DUPLICATE ATTRIBUTE] `#{name}` has already been defined in #{_resource_name_from_type(_type)}."
        end
      end
    end
  end
end
