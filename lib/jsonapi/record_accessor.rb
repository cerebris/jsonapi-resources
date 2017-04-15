module JSONAPI
  class RecordAccessor
    attr_reader :_resource_klass

    # Note: model_base_class, delete_restriction_error_class, record_not_found_error_class could be defined as
    # class attributes but currently all the library files are loaded using 'require', so if we have something like
    # self.model_base_class = ActiveRecord::Base, then ActiveRecord would be required as a dependency. Leaving these
    # as instance methods means we can load in these files at load-time and use them if they so choose.

    def initialize(resource_klass)
      @_resource_klass = resource_klass
    end

    class << self
      def transaction
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      def rollback_transaction
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      # Should return an enumerable with the key being the attribute name and value being an array of error messages.
      def model_error_messages(model)
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      def valid?(model, validation_context)
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      # Must save without raising an error as well.
      # +options+ can include :validate and :raise_on_failure as options.
      def save(model, options={})
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      def destroy(model, options={})
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      def delete_relationship(model, relationship_name, id)
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      def reload(model)
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      def model_base_class
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      def delete_restriction_error_class
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      def record_not_found_error_class
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      def find_in_association(model, association_name, ids)
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      def add_to_association(model, association_name, association_model)
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      def association_model_class_name(from_model, relationship_name)
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

      def set_primary_keys(model, relationship, value)
        # :nocov:
        raise 'Abstract method called'
        # :nocov:
      end

    end

    def find_records(filters, options = {})
      if defined?(_resource_klass.find_records)
        ActiveSupport::Deprecation.warn "In #{_resource_klass.name} you overrode `find_records`. "\
                                        "`find_records` has been deprecated in favor of using `apply` "\
                                        "and `verify` callables on the filter."

        _resource_klass.find_records(filters, options)
      else
        context = options[:context]

        records = filter_records(filters, options)

        sort_criteria = options.fetch(:sort_criteria) { [] }
        order_options = _resource_klass.construct_order_options(sort_criteria)
        records = sort_records(records, order_options, context)

        records = apply_pagination(records, options[:paginator], order_options)

        records
      end
    end

    def filter_records(filters, options, records = records(options))
      records = apply_filters(records, filters, options)
      apply_includes(records, options)
    end

    def apply_includes(records, options = {})
      # TODO: See if we can delete these keys out of options since they should really only be for #apply_includes
      include_as_join = options[:include_as_join]
      include_directives = options[:include_directives]
      if include_directives
        model_includes = resolve_relationship_names_to_relations(_resource_klass, include_directives.model_includes, options)
        records = records_with_includes(records, model_includes, include_as_join)
      end
      records
    end

    def sort_records(records, order_options, context = {})
      apply_sort(records, order_options, context)
    end

    # Converts a chainable relation to an actual Array of records.
    # Overwrite if subclass ORM has different implementation.
    def get_all(records)
      records.all
    end

    # Overwrite if subclass ORM has different implementation.
    def count_records(records)
      records.count
    end

    # Eager load the has of includes onto the record and return a chainable relation.
    # Overwrite if subclass ORM has different implementation.
    #
    # +include_as_join+ signifies that the includes should create a join table. Some ORMs will do includes as seperate
    # foreign key lookups to avoid huge cascading joins.
    def records_with_includes(records, includes, include_as_join=false)
      records.includes(includes)
    end

    # Overwrite if subclass ORM has different implementation.
    def association_relation(model, relation_name)
      model.public_send(relation_name)
    end

    # Returns a chainable relation from the model class.
    def model_class_relation
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    # Implement self.records on the resource if you want to customize the relation for
    # finder methods (find, find_by_key, find_serialized_with_caching)
    def records(_options = {})
      if defined?(_resource_klass.records)
        _resource_klass.records(_options)
      else
        model_class_relation
      end
    end

    def apply_pagination(records, paginator, order_options)
      records = paginator.apply(records, order_options) if paginator
      records
    end

    def find_by_key_serialized_with_caching(key, serializer, options = {})
      if _resource_klass.model_class_compatible_with_record_accessor?
        results = find_serialized_with_caching({ _resource_klass._primary_key => key }, serializer, options)
        result = results.first
        fail JSONAPI::Exceptions::RecordNotFound.new(key) if result.nil?
        return result
      else
        # :nocov:
        warn('Caching enabled on model that does not support ActiveRelation')
        # :nocov:
      end
    end

    def find_resource(filters, options = {})
      if options[:caching] && options[:caching][:cache_serializer_output]
        find_serialized_with_caching(filters, options[:caching][:serializer], options)
      else
        resources_for(find_records(filters, options), options[:context])
      end
    end

    # Gets all the given resources for a +records+ relation and calls #get_all to ensure all the records are
    # queried and returned to the Resource.resources_for function.
    def resources_for(records, context)
      _resource_klass.resources_for(get_all(records), context)
    end

    def find_resources_by_keys(keys, options = {})
      records = records(options)
      records = apply_includes(records, options)
      records = records.where({ _resource_klass._primary_key => keys })

      resources_for(records, options[:context])
    end

    def find_resource_by_key(key, options = {})
      if options[:caching] && options[:caching][:cache_serializer_output]
        find_by_key_serialized_with_caching(key, options[:caching][:serializer], options)
      else
        records = find_records({ _resource_klass._primary_key => key }, options.except(:paginator, :sort_criteria))
        model = records.first
        fail JSONAPI::Exceptions::RecordNotFound.new(key) if model.nil?
        _resource_klass.resource_for(model, options[:context])
      end
    end

    def find_count(filters, options = {})
      count_records(filter_records(filters, options))
    end

    def count_for_relationship(resource, relationship_name, options = {})
      relationship = resource.class._relationships[relationship_name.to_sym]

      context = resource.context

      relation_name = relationship.relation_name(context: context)
      records = records_for(resource, relation_name)

      resource_klass = relationship.resource_klass

      filters = options.fetch(:filters, {})
      unless filters.nil? || filters.empty?
        records = resource_klass._record_accessor.apply_filters(records, filters, options)
      end

      count_records(records)
    end

    def records_for_relationship(resource, relationship_name, options = {})
      relationship = resource.class._relationships[relationship_name.to_sym]

      context = resource.context

      relation_name = relationship.relation_name(context: context)
      records = records_for(resource, relation_name)

      resource_klass = relationship.resource_klass

      filters = options.fetch(:filters, {})
      unless filters.nil? || filters.empty?
        records = resource_klass._record_accessor.apply_filters(records, filters, options)
      end

      sort_criteria = options.fetch(:sort_criteria, {})
      order_options = relationship.resource_klass.construct_order_options(sort_criteria)
      records = apply_sort(records, order_options, context)

      paginator = options[:paginator]
      if paginator
        records = apply_pagination(records, paginator, order_options)
      end

      records
    end

    def foreign_key(resource, relationship_name, options = {})
      relationship = resource.class._relationships[relationship_name.to_sym]

      if relationship.belongs_to?
        resource._model.method(relationship.foreign_key).call
      else
        records = records_for_relationship(resource, relationship_name, options)
        return nil if records.nil?
        records.public_send(relationship.resource_klass._primary_key)
      end
    end

    def foreign_keys(resource, relationship_name, options = {})
      relationship = resource.class._relationships[relationship_name.to_sym]

      records = records_for_relationship(resource, relationship_name, options)
      records.collect do |record|
        record.public_send(relationship.resource_klass._primary_key)
      end
    end

    def related_resource(resource, relationship_name, options = {})
      relationship = resource.class._relationships[relationship_name.to_sym]

      if relationship.polymorphic?
        associated_model = records_for_relationship(resource, relationship_name, options)
        resource_klass = resource.class.resource_klass_for_model(associated_model) if associated_model
        return resource_klass.new(associated_model, resource.context) if resource_klass && associated_model
      else
        resource_klass = relationship.resource_klass
        if resource_klass
          associated_model = records_for_relationship(resource, relationship_name, options)
          return associated_model ? resource_klass.new(associated_model, resource.context) : nil
        end
      end
    end

    def related_resources(resource, relationship_name, options = {})
      relationship = resource.class._relationships[relationship_name.to_sym]
      relationship_resource_klass = relationship.resource_klass

      if options[:caching] && options[:caching][:cache_serializer_output]
        scope = relationship_resource_klass._record_accessor.records_for_relationship(resource, relationship_name, options)
        relationship_resource_klass._record_accessor.find_serialized_with_caching(scope, options[:caching][:serializer], options)
      else
        records = records_for_relationship(resource, relationship_name, options)
        return records.collect do |record|
          klass = relationship.polymorphic? ? resource.class.resource_klass_for_model(record) : relationship_resource_klass
          klass.new(record, resource.context)
        end
      end
    end

    def resolve_relationship_names_to_relations(resource_klass, model_includes, options = {})
      case model_includes
      when Array
        return model_includes.map do |value|
          resolve_relationship_names_to_relations(resource_klass, value, options)
        end
      when Hash
        model_includes.keys.each do |key|
          relationship = resource_klass._relationships[key]
          value = model_includes[key]
          model_includes.delete(key)
          model_includes[relationship.relation_name(options)] = resolve_relationship_names_to_relations(relationship.resource_klass, value, options)
        end
        return model_includes
      when Symbol
        relationship = resource_klass._relationships[model_includes]
        return relationship.relation_name(options)
      end
    end

    # Implement records_for on the resource to customize how the associated records
    # are fetched for a model. Particularly helpful for authorization.
    def records_for(resource, relation_name)
      if resource.respond_to?(:records_for)
        return resource.records_for(relation_name)
      end

      relationship = resource.class._relationships[relation_name]

      if relationship.is_a?(JSONAPI::Relationship::ToMany)
        if resource.respond_to?(:"records_for_#{relation_name}")
          return resource.method(:"records_for_#{relation_name}").call
        end
      else
        if resource.respond_to?(:"record_for_#{relation_name}")
          return resource.method(:"record_for_#{relation_name}").call
        end
      end

      association_relation(resource._model, relation_name)
    end

    def apply_filters(records, filters, options = {})
      to_many_filters = []

      if filters
        filters.each do |filter, value|
          if _resource_klass._relationships.include?(filter)
            if _resource_klass._relationships[filter].belongs_to?
              records = apply_filter(records, _resource_klass._relationships[filter].foreign_key, value, options)
            else
              to_many_filters << [filter, value]
            end
          else
            records = apply_filter(records, filter, value, options)
          end
        end
      end

      if to_many_filters.any?
        records = apply_filters_to_many_relationships(records, to_many_filters, options)
      end

      records
    end

    # Apply an array of "to many" relationships to a set of records.
    #
    # Returns a collection of +records+.
    def apply_filters_to_many_relationships(records, to_many_filters, options)
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

    def pluck_attributes(relation, model_class, *attrs)
      # :nocov:
      raise 'Abstract method called'
      # :nocov:
    end

  end
end