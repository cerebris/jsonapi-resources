require 'jsonapi/record_accessor'

module JSONAPI
  class ActiveRecordAccessor < RecordAccessor

    # RecordAccessor methods

    def find_resource(filters, options = {})
      if options[:caching] && options[:caching][:cache_serializer_output]
        find_serialized_with_caching(filters, options[:caching][:serializer], options)
      else
        _resource_klass.resources_for(find_records(filters, options), options[:context])
      end
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

    def find_resources_by_keys(keys, options = {})
      records = records(options)
      records = apply_includes(records, options)
      records = records.where({ _resource_klass._primary_key => keys })

      _resource_klass.resources_for(records, options[:context])
    end

    def find_count(filters, options = {})
      count_records(filter_records(filters, options))
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

      records.count(:all)
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

    # protected-ish methods left public for tests and what not

    def find_serialized_with_caching(filters_or_source, serializer, options = {})
      if filters_or_source.is_a?(ActiveRecord::Relation)
        return cached_resources_for(filters_or_source, serializer, options)
      elsif _resource_klass._model_class.respond_to?(:all) && _resource_klass._model_class.respond_to?(:arel_table)
        records = find_records(filters_or_source, options.except(:include_directives))
        return cached_resources_for(records, serializer, options)
      else
        # :nocov:
        warn('Caching enabled on model that does not support ActiveRelation')
        # :nocov:
      end
    end

    def find_by_key_serialized_with_caching(key, serializer, options = {})
      if _resource_klass._model_class.respond_to?(:all) && _resource_klass._model_class.respond_to?(:arel_table)
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

    # Implement self.records on the resource if you want to customize the relation for
    # finder methods (find, find_by_key, find_serialized_with_caching)
    def records(_options = {})
      if defined?(_resource_klass.records)
        _resource_klass.records(_options)
      else
        _resource_klass._model_class.all
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

      resource._model.public_send(relation_name)
    end

    def apply_includes(records, options = {})
      include_directives = options[:include_directives]
      if include_directives
        model_includes = resolve_relationship_names_to_relations(_resource_klass, include_directives.model_includes, options)
        records = records.includes(model_includes)
      end

      records
    end

    def apply_pagination(records, paginator, order_options)
      records = paginator.apply(records, order_options) if paginator
      records
    end

    def apply_sort(records, order_options, context = {})
      if defined?(_resource_klass.apply_sort)
        _resource_klass.apply_sort(records, order_options, context)
      else
        if order_options.any?
          order_options.each_pair do |field, direction|
            if field.to_s.include?(".")
              *model_names, column_name = field.split(".")

              associations = _lookup_association_chain([records.model.to_s, *model_names])
              joins_query = _build_joins([records.model, *associations])

              # _sorting is appended to avoid name clashes with manual joins eg. overridden filters
              order_by_query = "#{associations.last.name}_sorting.#{column_name} #{direction}"
              records = records.joins(joins_query).order(order_by_query)
            else
              records = records.order(field => direction)
            end
          end
        end

        records
      end
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

    def _build_joins(associations)
      joins = []

      associations.inject do |prev, current|
        joins << "LEFT JOIN #{current.table_name} AS #{current.name}_sorting ON #{current.name}_sorting.id = #{prev.table_name}.#{current.foreign_key}"
        current
      end
      joins.join("\n")
    end

    def apply_filter(records, filter, value, options = {})
      strategy = _resource_klass._allowed_filters.fetch(filter.to_sym, Hash.new)[:apply]

      if strategy
        if strategy.is_a?(Symbol) || strategy.is_a?(String)
          _resource_klass.send(strategy, records, value, options)
        else
          strategy.call(records, value, options)
        end
      else
        records.where(filter => value)
      end
    end

    # Assumes ActiveRecord's counting. Override if you need a different counting method
    def count_records(records)
      records.count(:all)
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

    def apply_filters(records, filters, options = {})
      required_includes = []

      if filters
        filters.each do |filter, value|
          if _resource_klass._relationships.include?(filter)
            if _resource_klass._relationships[filter].belongs_to?
              records = apply_filter(records, _resource_klass._relationships[filter].foreign_key, value, options)
            else
              required_includes.push(filter.to_s)
              records = apply_filter(records, "#{_resource_klass._relationships[filter].table_name}.#{_resource_klass._relationships[filter].primary_key}", value, options)
            end
          else
            records = apply_filter(records, filter, value, options)
          end
        end
      end

      if required_includes.any?
        records = apply_includes(records, options.merge(include_directives: IncludeDirectives.new(_resource_klass, required_includes, force_eager_load: true)))
      end

      records
    end

    def filter_records(filters, options, records = records(options))
      records = apply_filters(records, filters, options)
      apply_includes(records, options)
    end

    def sort_records(records, order_options, context = {})
      apply_sort(records, order_options, context)
    end

    def cached_resources_for(records, serializer, options)
      if _resource_klass.caching?
        t = _resource_klass._model_class.arel_table
        cache_ids = pluck_arel_attributes(records, t[_resource_klass._primary_key], t[_resource_klass._cache_field])
        resources = CachedResourceFragment.fetch_fragments(_resource_klass, serializer, options[:context], cache_ids)
      else
        resources = _resource_klass.resources_for(records, options[:context]).map { |r| [r.id, r] }.to_h
      end

      preload_included_fragments(resources, records, serializer, options)

      resources.values
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

    def preload_included_fragments(resources, records, serializer, options)
      return if resources.empty?
      res_ids = resources.keys

      include_directives = options[:include_directives]
      return unless include_directives

      context = options[:context]

      # For each association, including indirect associations, find the target record ids.
      # Even if a target class doesn't have caching enabled, we still have to look up
      # and match the target ids here, because we can't use ActiveRecord#includes.
      #
      # Note that `paths` returns partial paths before complete paths, so e.g. the partial
      # fragments for posts.comments will exist before we start working with posts.comments.author
      target_resources = {}
      include_directives.paths.each do |path|
        # If path is [:posts, :comments, :author], then...
        pluck_attrs = [] # ...will be [posts.id, comments.id, authors.id, authors.updated_at]
        pluck_attrs << _resource_klass._model_class.arel_table[_resource_klass._primary_key]

        relation = records
                       .except(:limit, :offset, :order)
                       .where({ _resource_klass._primary_key => res_ids })

        # These are updated as we iterate through the association path; afterwards they will
        # refer to the final resource on the path, i.e. the actual resource to find in the cache.
        # So e.g. if path is [:posts, :comments, :author], then after iteration...
        parent_klass = nil # Comment
        klass = _resource_klass # Person
        relationship = nil # JSONAPI::Relationship::ToOne for CommentResource.author
        table = nil # people
        assocs_path = [] # [ :posts, :approved_comments, :author ]
        ar_hash = nil # { :posts => { :approved_comments => :author } }

        # For each step on the path, figure out what the actual table name/alias in the join
        # will be, and include the primary key of that table in our list of fields to select
        non_polymorphic = true
        path.each do |elem|
          relationship = klass._relationships[elem]
          if relationship.polymorphic
            # Can't preload through a polymorphic belongs_to association, ResourceSerializer
            # will just have to bypass the cache and load the real Resource.
            non_polymorphic = false
            break
          end
          assocs_path << relationship.relation_name(options).to_sym
          # Converts [:a, :b, :c] to Rails-style { :a => { :b => :c }}
          ar_hash = assocs_path.reverse.reduce { |memo, step| { step => memo } }
          # We can't just look up the table name from the resource class, because Arel could
          # have used a table alias if the relation includes a self-reference.
          join_source = relation.joins(ar_hash).arel.source.right.reverse.find do |arel_node|
            arel_node.is_a?(Arel::Nodes::InnerJoin)
          end
          table = join_source.left
          parent_klass = klass
          klass = relationship.resource_klass
          pluck_attrs << table[klass._primary_key]
        end
        next unless non_polymorphic

        # Pre-fill empty hashes for each resource up to the end of the path.
        # This allows us to later distinguish between a preload that returned nothing
        # vs. a preload that never ran.
        prefilling_resources = resources.values
        path.each do |rel_name|
          rel_name = serializer.key_formatter.format(rel_name)
          prefilling_resources.map! do |res|
            res.preloaded_fragments[rel_name] ||= {}
            res.preloaded_fragments[rel_name].values
          end
          prefilling_resources.flatten!(1)
        end

        pluck_attrs << table[klass._cache_field] if klass.caching?
        relation = relation.joins(ar_hash)
        if relationship.is_a?(JSONAPI::Relationship::ToMany)
          # Rails doesn't include order clauses in `joins`, so we have to add that manually here.
          # FIXME Should find a better way to reflect on relationship ordering. :-(
          relation = relation.order(parent_klass._model_class.new.send(assocs_path.last).arel.orders)
        end

        # [[post id, comment id, author id, author updated_at], ...]
        id_rows = pluck_arel_attributes(relation.joins(ar_hash), *pluck_attrs)

        target_resources[klass.name] ||= {}

        if klass.caching?
          sub_cache_ids = id_rows
                              .map { |row| row.last(2) }
                              .reject { |row| target_resources[klass.name].has_key?(row.first) }
                              .uniq
          target_resources[klass.name].merge! CachedResourceFragment.fetch_fragments(
              klass, serializer, context, sub_cache_ids
          )
        else
          sub_res_ids = id_rows
                            .map(&:last)
                            .reject { |id| target_resources[klass.name].has_key?(id) }
                            .uniq
          found = klass.find({ klass._primary_key => sub_res_ids }, context: options[:context])
          target_resources[klass.name].merge! found.map { |r| [r.id, r] }.to_h
        end

        id_rows.each do |row|
          res = resources[row.first]
          path.each_with_index do |rel_name, index|
            rel_name = serializer.key_formatter.format(rel_name)
            rel_id = row[index+1]
            assoc_rels = res.preloaded_fragments[rel_name]
            if index == path.length - 1
              assoc_rels[rel_id] = target_resources[klass.name].fetch(rel_id)
            else
              res = assoc_rels[rel_id]
            end
          end
        end
      end
    end

    def pluck_arel_attributes(relation, *attrs)
      conn = relation.connection
      quoted_attrs = attrs.map do |attr|
        quoted_table = conn.quote_table_name(attr.relation.table_alias || attr.relation.name)
        quoted_column = conn.quote_column_name(attr.name)
        "#{quoted_table}.#{quoted_column}"
      end
      relation.pluck(*quoted_attrs)
    end
  end
end
