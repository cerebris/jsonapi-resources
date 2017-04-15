require 'jsonapi/record_accessor'

module JSONAPI
  class ActiveRecordRecordAccessor < RecordAccessor
    # RecordAccessor methods

    class << self

      def transaction
        ActiveRecord::Base.transaction do
          yield
        end
      end

      def rollback_transaction
        fail ActiveRecord::Rollback
      end

      def model_error_messages(model)
        model.errors.messages
      end

      def valid?(model, validation_context)
        model.valid?(validation_context)
      end

      def save(model, options={})
        method = options[:raise_on_failure] ? :save! : :save
        model.public_send(method, options.slice(:validate))
      end

      def destroy(model, options={})
        model.destroy
      end

      def delete_relationship(model, relationship_name, id)
        model.public_send(relationship_name).delete(id)
      end

      def reload(model)
        model.reload
      end

      def model_base_class
        ActiveRecord::Base
      end

      def delete_restriction_error_class
        ActiveRecord::DeleteRestrictionError
      end

      def record_not_found_error_class
        ActiveRecord::RecordNotFound
      end

      def find_in_association(model, association_name, ids)
        primary_key = model.class.reflections[association_name.to_s].klass.primary_key
        model.public_send(association_name).where(primary_key => ids)
      end

      def add_to_association(model, association_name, association_model)
        model.public_send(association_name) << association_model
      end

      def association_model_class_name(from_model, relationship_name)
        (reflect = from_model.reflect_on_association(relationship_name)) && reflect.class_name
      end

      def set_primary_keys(model, relationship, value)
        model.method("#{relationship.foreign_key}=").call(value)
      end

    end


    # In AR, the .all command will return a chainable relation in which you can attach limit, offset, where, etc.
    def model_class_relation
      _resource_klass._model_class.all
    end

    # protected-ish methods left public for tests and what not

    def find_serialized_with_caching(filters_or_source, serializer, options = {})
      if filters_or_source.is_a?(ActiveRecord::Relation)
        return cached_resources_for(filters_or_source, serializer, options)
        # TODO - if we are already in ActiveRecordRecordAccessor, then _resource_klass._model_class
        # will essentially always support ActiveRelation, right? Maybe we should get rid of this check.
      elsif _resource_klass._model_class.respond_to?(:all) && _resource_klass._model_class.respond_to?(:arel_table)
        records = find_records(filters_or_source, options.except(:include_directives))
        return cached_resources_for(records, serializer, options)
      else
        # :nocov:
        warn('Caching enabled on model that does not support ActiveRelation')
        # :nocov:
      end
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

    def apply_filters_to_many_relationships(records, to_many_filters, options)
      required_includes = []
      to_many_filters.each do |filter, value|
        relationship = _resource_klass._relationships[filter]
        required_includes << filter.to_s
        records = apply_filter(records, "#{relationship.table_name}.#{relationship.primary_key}", value, options)
      end

      records = apply_includes(records, options.merge(include_directives: IncludeDirectives.new(_resource_klass, required_includes, force_eager_load: true)))

      records
    end

    # ActiveRecord requires :all to be specified
    def count_records(records)
      records.count(:all)
    end

    def cached_resources_for(records, serializer, options)
      if _resource_klass.caching?
        t = _resource_klass._model_class.arel_table
        cache_ids = pluck_attributes(records, t[_resource_klass._primary_key], t[_resource_klass._cache_field])
        resources = CachedResourceFragment.fetch_fragments(_resource_klass, serializer, options[:context], cache_ids)
      else
        resources = resources_for(records, options[:context]).map { |r| [r.id, r] }.to_h
      end

      preload_included_fragments(resources, records, serializer, options)

      resources.values
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
        joins_hash = nil # { :posts => { :approved_comments => :author } }

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
          joins_hash = assocs_path.reverse.reduce { |memo, step| { step => memo } }
          # We can't just look up the table name from the resource class, because Arel could
          # have used a table alias if the relation includes a self-reference.
          join_source = relation.joins(joins_hash).arel.source.right.reverse.find do |arel_node|
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
        relation = relation.joins(joins_hash)
        if relationship.is_a?(JSONAPI::Relationship::ToMany)
          # Rails doesn't include order clauses in `joins`, so we have to add that manually here.
          # FIXME Should find a better way to reflect on relationship ordering. :-(
          relation = relation.order(parent_klass._model_class.new.send(assocs_path.last).arel.orders)
        end

        # [[post id, comment id, author id, author updated_at], ...]
        id_rows = pluck_attributes(relation.joins(joins_hash), *pluck_attrs)

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

    def pluck_attributes(relation, *attrs)
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
