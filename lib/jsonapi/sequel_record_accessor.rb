require 'jsonapi/record_accessor'
require 'sequel/plugins/association_pks'

module JSONAPI
  class SequelRecordAccessor < RecordAccessor

    class << self
      def transaction
        ::Sequel.transaction(::Sequel::DATABASES) do
          yield
        end
      end

      def rollback_transaction
        fail ::Sequel::Rollback
      end

      def model_error_messages(model)
        model.errors
      end

      def valid?(model, validation_context)
        raise("Sequel does not support validation contexts") if validation_context
        model.valid?
      end

      def save(model, options={})
        model.save(options)
      end

      def destroy(model, options={})
        model.destroy(options.slice(:raise_on_failure))
      end

      def delete_relationship(model, relationship_name, id)
        model.public_send("remove_#{relationship_name.singularize}", id)
      end

      def reload(model)
        model.reload
      end

      def model_base_class
        Sequel::Model
      end

      def delete_restriction_error_class
        Class.new(Exception)
      end

      def record_not_found_error_class
        Class.new(Exception)
      end

      def find_in_association(model, association_name, ids)
        klass = model.class.association_reflection(association_name).associated_class
        model.send("#{association_name}_dataset").where(:"#{klass.table_name}__#{klass.primary_key}" => ids)
      end

      def add_to_association(model, association_name, association_model)
        model.public_send("add_#{association_name.to_s.singularize}", association_model)
      end

      def association_model_class_name(from_model, association_name)
        (reflect = from_model.association_reflection(association_name)) &&
          reflect[:class_name] && reflect[:class_name].gsub(/^::/, '') # Sequel puts "::" in the beginning
      end

      def set_primary_keys(model, relationship, value)
        unless model.class.plugins.include?(Sequel::Plugins::AssociationPks)
          raise("Please include the Sequel::Plugins::AssociationPks plugin into the #{model.class} model.")
        end

        setter_method = relationship.is_a?(Relationship::ToMany) ?
          "#{relationship.name.to_s.singularize}_pks=" :
          "#{relationship.foreign_key}="

        model.public_send(setter_method, value)
      end

    end

    def model_class_relation
      _resource_klass._model_class.dataset
    end

    # protected-ish methods left public for tests and what not

    def find_serialized_with_caching(filters_or_source, serializer, options = {})
      if filters_or_source.is_a?(Sequel::SQLite::Dataset)
        cached_resources_for(filters_or_source, serializer, options)
      else
        records = find_records(filters_or_source, options.except(:include_directives))
        cached_resources_for(records, serializer, options)
      end
    end


    # Implement self.records on the resource if you want to customize the relation for
    # finder methods (find, find_by_key, find_serialized_with_caching)
    # def records(_options = {})
    #   if defined?(_resource_klass.records)
    #     _resource_klass.records(_options)
    #   else
    #     _resource_klass._model_class.all
    #   end
    # end
    #
    # def association_relation(model, relation_name)
    #   relationship = _resource_klass._relationships[relation_name]
    #   method = relationship.is_a?(JSONAPI::Relationship::ToMany) ? "#{relation_name}_dataset" : relation_name
    #   model.public_send(method)
    # end

    def association_relation(model, relation_name)
      # Sequel Reflection classes returning a collection end in "ToMany", so match against that.
      method = model.class.association_reflections[relation_name].class.to_s =~ /ToMany/ ?
        "#{relation_name}_dataset" : relation_name

      # Aryk: Leave off point.
      model.public_send(method)
    end

    def records_with_includes(records, includes, include_as_join=false)
      method = include_as_join ? :eager_graph : :eager
      records.public_send(method, includes)
    end

    def apply_sort(records, order_options, context = {})
      if defined?(_resource_klass.apply_sort)
        _resource_klass.apply_sort(records, order_options, context)
      else
        if order_options.any?
          columns = []
          order_options.each_pair do |field, direction|
            table_name = extract_model_class(records).table_name
            if field.to_s.include?(".")
              *association_names, column_name = field.split(".")
              association_graph = association_names.
                reverse.
                inject(nil) {|hash, assoc| hash ? {assoc.to_sym => hash} : assoc.to_sym }

              records = records.select_all(table_name).association_left_join(association_graph)

              # associations = _lookup_association_chain([records.model.to_s, *model_names])
              # joins_query = _build_joins([records.model, *associations])

              # _sorting is appended to avoid name clashes with manual joins eg. overridden filters
              #   debugger
              columns << Sequel.send(direction, :"#{records.opts[:join].last.table_expr.aliaz}__#{column_name}")
              # records = records.association_join(joins_query).select_all(table_name)
            else
              # DB[:items].order(Sequel.desc(:name)) # SELECT * FROM items ORDER BY name DESC
              columns << Sequel.send(direction, :"#{table_name}__#{field}")
            end
          end
          records = records.order(*columns)
        end
        records
      end
    end

    def _lookup_association_chain(model_names)
      associations = []
      model_names.inject do |prev, current|
        association = prev.classify.constantize.all_association_reflections.detect do |assoc|
          assoc.association_method.to_s.downcase == current.downcase
        end
        associations << association
        association.associated_class.to_s
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
        # Prefix primary key lookups with the table name to avoid conflicts (Sequel does not do this automatically)
        prefixed_filter = _resource_klass._primary_key == filter ? :"#{_resource_klass._model_class.table_name}__#{filter}" : filter
        records.where(prefixed_filter => value)
      end
    end

    def apply_filters_to_many_relationships(records, to_many_filters, options)
      required_includes = to_many_filters.map { |filter, _| filter.to_s }
      records = apply_includes(records, options.merge(
        include_as_join: true,
        include_directives: IncludeDirectives.new(_resource_klass, required_includes, force_eager_load: true)),
      )

      to_many_filters.each do |filter, value|
        table_name = records.opts[:join].map(&:table_expr).detect { |t| t.expression == filter }.aliaz
        relationship = _resource_klass._relationships[filter]
        records = apply_filter(records, :"#{table_name}__#{relationship.primary_key}", value, options)
      end

      records
    end

    def cached_resources_for(records, serializer, options)
      if _resource_klass.caching?
        table = _resource_klass._model_class.table_name
        cache_ids = pluck_attributes(records, [table, _resource_klass._primary_key], [table, _resource_klass._cache_field])
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
        pluck_attrs << [_resource_klass._model_class.table_name, _resource_klass._primary_key]

        relation = records.clone
          .tap { |dataset| [:limit, :offset, :order, :where, :join].each { |x| dataset.opts.delete(x) }}
          .where({ Sequel[_resource_klass._model_class.table_name][_resource_klass._primary_key] => res_ids })

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

          # Sequel::Model::Associations::ManyToManyAssociationReflection
          # join_source = relation.join(ar_hash).arel.source.right.reverse.find do |arel_node|
          #   arel_node.is_a?(Arel::Nodes::InnerJoin)
          # end
          # table = join_source.left

          parent_klass = klass
          klass = relationship.resource_klass

          # We can't just look up the table name from the resource class, because Sequel could
          # have used a table alias if the relation includes a self-reference.
          table = relation.association_join(joins_hash).opts[:join].last.table_expr.alias
          # pluck_attrs << :"#{_resource_klass._model_class}__#{_resource_klass._primary_key}"
          # pluck_attrs << table[klass._primary_key]
          pluck_attrs << [table, klass._primary_key]
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

        pluck_attrs << [table, klass._cache_field] if klass.caching?
        relation = relation.association_join(joins_hash).select_all(_resource_klass._model_class.table_name)
        # debugger
        if relationship.is_a?(JSONAPI::Relationship::ToMany)
          relation = relation.order(parent_klass._model_class.association_reflection(assocs_path.last)[:order])
        end

        # [[post id, comment id, author id, author updated_at], ...]
        id_rows = pluck_attributes(relation, *pluck_attrs)

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
        # debugger
          found = klass.find({ :"#{klass._model_class.table_name}__#{klass._primary_key}" => sub_res_ids }, context: options[:context])
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
      # Use Sequel's Symbol table aliasing convention.
      relation.select_map(attrs.map { |table, column| :"#{table}__#{column}___#{table}#{column}" })
    end

    private

    def extract_model_class(records)
      if records.is_a?(Sequel::Dataset)
        records.opts[:model]
      elsif records.is_a?(Class) && records < self.class.model_base_class
        records
      else
        raise("Cannot extract table name from #{records.inspect}")
      end
    end

  end
end