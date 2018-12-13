module JSONAPI
  module ActiveRelationResourceFinder
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      # Finds Resources using the `filters`. Pagination and sort options are used when provided
      #
      # @param filters [Hash] the filters hash
      # @option options [Hash] :context The context of the request, set in the controller
      # @option options [Hash] :sort_criteria The `sort criteria`
      # @option options [Hash] :include_directives The `include_directives`
      #
      # @return [Array<Resource>] the Resource instances matching the filters, sorting and pagination rules.
      def find(filters, options = {})
        records = find_records(filters, options)
        resources_for(records, options[:context])
      end

      # Counts Resources found using the `filters`
      #
      # @param filters [Hash] the filters hash
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [Integer] the count
      def count(filters, options = {})
        count_records(filter_records(records(options), filters, options))
      end

      # Returns the single Resource identified by `key`
      #
      # @param key the primary key of the resource to find
      # @option options [Hash] :context The context of the request, set in the controller
      def find_by_key(key, options = {})
        record = find_record_by_key(key, options)
        resource_for(record, options[:context])
      end

      # Returns an array of Resources identified by the `keys` array
      #
      # @param keys [Array<key>] Array of primary keys to find resources for
      # @option options [Hash] :context The context of the request, set in the controller
      def find_by_keys(keys, options = {})
        records = find_records_by_keys(keys, options)
        resources_for(records, options[:context])
      end

      # Finds Resource fragments using the `filters`. Pagination and sort options are used when provided.
      # Retrieving the ResourceIdentities and attributes does not instantiate a model instance.
      #
      # @param filters [Hash] the filters hash
      # @option options [Hash] :context The context of the request, set in the controller
      # @option options [Hash] :sort_criteria The `sort criteria`
      # @option options [Hash] :include_directives The `include_directives`
      # @option options [Hash] :attributes Additional fields to be retrieved.
      # @option options [Boolean] :cache Return the resources' cache field
      #
      # @return [Hash{ResourceIdentity => {identity: => ResourceIdentity, cache: cache_field, attributes: => {name => value}}}]
      #    the ResourceInstances matching the filters, sorting, and pagination rules along with any request
      #    additional_field values
      def find_fragments(filters, options = {})
        records = find_records(filters, options)

        table_name = _model_class.table_name
        pluck_fields = [Arel.sql("#{concat_table_field(table_name, _primary_key)} AS #{table_name}_#{_primary_key}")]

        cache_field = attribute_to_model_field(:_cache_field) if options[:cache]
        if cache_field
          pluck_fields << Arel.sql("#{concat_table_field(table_name, cache_field[:name])} AS #{table_name}_#{cache_field[:name]}")
        end

        model_fields = {}
        attributes = options[:attributes]
        attributes.try(:each) do |attribute|
          model_field = attribute_to_model_field(attribute)
          model_fields[attribute] = model_field
          pluck_fields << Arel.sql("#{concat_table_field(table_name, model_field[:name])} AS #{table_name}_#{model_field[:name]}")
        end

        fragments = {}
        records.pluck(*pluck_fields).collect do |row|
          rid = JSONAPI::ResourceIdentity.new(self, pluck_fields.length == 1 ? row : row[0])
          fragments[rid] = { identity: rid }
          attributes_offset = 1

          if cache_field
            fragments[rid][:cache] = cast_to_attribute_type(row[1], cache_field[:type])
            attributes_offset+= 1
          end

          fragments[rid][:attributes]= {} unless model_fields.empty?
          model_fields.each_with_index do |k, idx|
            fragments[rid][:attributes][k[0]]= cast_to_attribute_type(row[idx + attributes_offset], k[1][:type])
          end
        end

        fragments
      end

      # Finds Resource Fragments related to the source resources through the specified relationship
      #
      # @param source_rids [Array<ResourceIdentity>] The resources to find related ResourcesIdentities for
      # @param relationship_name [String | Symbol] The name of the relationship
      # @option options [Hash] :context The context of the request, set in the controller
      # @option options [Hash] :attributes Additional fields to be retrieved.
      # @option options [Boolean] :cache Return the resources' cache field
      #
      # @return [Hash{ResourceIdentity => {identity: => ResourceIdentity, cache: cache_field, attributes: => {name => value}, related: {relationship_name: [] }}}]
      #    the ResourceInstances matching the filters, sorting, and pagination rules along with any request
      #    additional_field values
      def find_related_fragments(source_rids, relationship_name, options = {}, included_key = nil)
        relationship = _relationship(relationship_name)

        if relationship.polymorphic? && relationship.foreign_key_on == :self
          find_related_polymorphic_fragments(source_rids, relationship, options)
        else
          find_related_monomorphic_fragments(source_rids, relationship, included_key, options)
        end
      end

      # Counts Resources related to the source resource through the specified relationship
      #
      # @param source_rid [ResourceIdentity] Source resource identifier
      # @param relationship_name [String | Symbol] The name of the relationship
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [Integer] the count
      def count_related(source_rid, relationship_name, options = {})
        opts = options.dup

        relationship = _relationship(relationship_name)
        related_klass = relationship.resource_klass

        context = opts[:context]

        primary_key_field = "#{_table_name}.#{_primary_key}"

        records = records(context: context).where(primary_key_field => source_rid.id)

        # join in related to the source records
        records, related_alias = get_join_alias(records) { |records| records.joins(relationship.relation_name(opts)) }

        join_tree = JoinTree.new(resource_klass: related_klass,
                                 source_relationship: relationship,
                                 filters: filters,
                                 options: opts)

        records, joins = apply_joins(records, join_tree, opts)

        # Options for filtering
        opts[:joins] = joins
        opts[:related_alias] = related_alias

        filters = opts.fetch(:filters, {})
        records = related_klass.filter_records(records, filters,  opts)

        records.count(:all)
      end

      def parse_relationship_path(path)
        relationships = []
        relationship_names = []
        field = nil

        current_path = path
        current_resource_klass = self
        loop do
          parts = current_path.to_s.partition('.')
          relationship = current_resource_klass._relationship(parts[0])
          if relationship
            relationships << relationship
            relationship_names << relationship.name
          else
            if parts[2].blank?
              field = parts[0]
              break
            else
              # :nocov:
              warn "Unknown relationship #{parts[0]}"
              # :nocov:
            end
          end

          current_resource_klass = relationship.resource_klass

          if parts[2].include?('.')
            current_path = parts[2]
          else
            relationship = current_resource_klass._relationship(parts[2])
            if relationship
              relationships << relationship
              relationship_names << relationship.name
            else
              field = parts[2]
            end
            break
          end
        end

        return relationships, relationship_names.join('.'), field
      end

      protected

      def find_record_by_key(key, options = {})
        records = find_records({ _primary_key => key }, options.except(:paginator, :sort_criteria))
        record = records.first
        fail JSONAPI::Exceptions::RecordNotFound.new(key) if record.nil?
        record
      end

      def find_records_by_keys(keys, options = {})
        records(options).where({ _primary_key => keys })
      end

      def find_related_monomorphic_fragments(source_rids, relationship, included_key, options = {})
        opts = options.dup

        source_ids = source_rids.collect {|rid| rid.id}

        context = opts[:context]

        related_klass = relationship.resource_klass

        primary_key_field = "#{_table_name}.#{_primary_key}"

        records = records(context: context).where(primary_key_field => source_ids)

        # join in related to the source records
        records, related_alias = get_join_alias(records) { |records| records.joins(relationship.relation_name(opts)) }

        sort_criteria = []
        opts[:sort_criteria].try(:each) do |sort|
          field = sort[:field].to_s == 'id' ? related_klass._primary_key : sort[:field]
          sort_criteria << { field: field, direction: sort[:direction] }
        end

        paginator = opts[:paginator]

        filters = opts.fetch(:filters, {})

        # Joins in this case are related to the related_klass
        join_tree = JoinTree.new(resource_klass: related_klass,
                                 source_relationship: relationship,
                                 filters: filters,
                                 sort_criteria: sort_criteria,
                                 options: opts)

        records, joins = apply_joins(records, join_tree, opts)

        # Options for filtering
        opts[:joins] = joins
        opts[:related_alias] = related_alias

        records = related_klass.filter_records(records, filters,  opts)

        order_options = related_klass.construct_order_options(sort_criteria)

        # ToDO: Remove count check. Currently pagination isn't working with multiple source_rids (i.e. it only works
        # for show relationships, not related includes).
        # Check included_key to not paginate included resources but ensure that nested resources can be paginated
        if paginator && source_rids.count == 1 && !included_key
          records = related_klass.apply_pagination(records, paginator, order_options)
        end

        records = sort_records(records, order_options, opts)

        pluck_fields = [
            Arel.sql(primary_key_field),
            Arel.sql("#{concat_table_field(related_alias, related_klass._primary_key)} AS #{related_alias}_#{related_klass._primary_key}")
        ]

        cache_field = related_klass.attribute_to_model_field(:_cache_field) if opts[:cache]
        if cache_field
          pluck_fields << Arel.sql("#{concat_table_field(related_alias, cache_field[:name])} AS #{related_alias}_#{cache_field[:name]}")
        end

        model_fields = {}
        attributes = opts[:attributes]
        attributes.try(:each) do |attribute|
          model_field = related_klass.attribute_to_model_field(attribute)
          model_fields[attribute] = model_field
          pluck_fields << Arel.sql("#{concat_table_field(related_alias, model_field[:name])} AS #{related_alias}_#{model_field[:name]}")
        end

        rows = records.pluck(*pluck_fields)

        relation_name = relationship.name.to_sym

        related_fragments = {}

        rows.each do |row|
          unless row[1].nil?
            rid = JSONAPI::ResourceIdentity.new(related_klass, row[1])
            related_fragments[rid] ||= { identity: rid, related: {relation_name => [] } }

            attributes_offset = 2

            if cache_field
              related_fragments[rid][:cache] = cast_to_attribute_type(row[attributes_offset], cache_field[:type])
              attributes_offset+= 1
            end

            related_fragments[rid][:attributes]= {} unless model_fields.empty?
            model_fields.each_with_index do |k, idx|
              related_fragments[rid][:attributes][k[0]] = cast_to_attribute_type(row[idx + attributes_offset], k[1][:type])
            end

            related_fragments[rid][:related][relation_name] << JSONAPI::ResourceIdentity.new(self, row[0])
          end
        end

        related_fragments
      end

      # Gets resource identities where the related resource is polymorphic and the resource type and id
      # are stored on the primary resources. Cache fields will always be on the related resources.
      def find_related_polymorphic_fragments(source_rids, relationship, options = {})
        source_ids = source_rids.collect {|rid| rid.id}

        context = options[:context]

        records = records(context: context)

        primary_key = concat_table_field(_table_name, _primary_key)
        related_key = concat_table_field(_table_name, relationship.foreign_key)
        related_type = concat_table_field(_table_name, relationship.polymorphic_type)

        pluck_fields = [
            Arel.sql("#{primary_key} AS #{_table_name}_#{_primary_key}"),
            Arel.sql("#{related_key} AS #{_table_name}_#{relationship.foreign_key}"),
            Arel.sql("#{related_type} AS #{_table_name}_#{relationship.polymorphic_type}")
        ]

        relations = relationship.polymorphic_relations

        # Get the additional fields from each relation. There's a limitation that the fields must exist in each relation

        relation_positions = {}
        relation_index = 3

        attributes = options.fetch(:attributes, [])

        if relations.nil? || relations.length == 0
          # :nocov:
          warn "No relations found for polymorphic relationship."
          # :nocov:
        else
          relations.try(:each) do |relation|
            related_klass = resource_klass_for(relation.to_s)

            cache_field = related_klass.attribute_to_model_field(:_cache_field) if options[:cache]

            # We only need to join the relations if we are getting additional fields
            if cache_field || attributes.length > 0
              records, table_alias = get_join_alias(records) { |records| records.left_joins(relation.to_sym) }

              if cache_field
                pluck_fields << concat_table_field(table_alias, cache_field[:name])
              end

              model_fields = {}
              attributes.try(:each) do |attribute|
                model_field = related_klass.attribute_to_model_field(attribute)
                model_fields[attribute] = model_field
              end

              model_fields.each do |_k, v|
                pluck_fields << concat_table_field(table_alias, v[:name])
              end

            end

            related = related_klass._model_class.name
            relation_positions[related] = { relation_klass: related_klass,
                                            cache_field: cache_field,
                                            model_fields: model_fields,
                                            field_offset: relation_index}

            relation_index+= 1 if cache_field
            relation_index+= attributes.length if attributes.length > 0
          end
        end

        primary_resource_filters = options[:filters]
        primary_resource_filters ||= {}

        primary_resource_filters[_primary_key] = source_ids

        records = apply_filters(records, primary_resource_filters, options)

        rows = records.pluck(*pluck_fields)

        relation_name = relationship.name.to_sym

        related_fragments = {}

        rows.each do |row|
          unless row[1].nil? || row[2].nil?
            related_klass = resource_klass_for(row[2])

            rid = JSONAPI::ResourceIdentity.new(related_klass, row[1])
            related_fragments[rid] ||= { identity: rid, related: { relation_name => [] } }
            related_fragments[rid][:related][relation_name] << JSONAPI::ResourceIdentity.new(self, row[0])

            relation_position = relation_positions[row[2]]
            model_fields = relation_position[:model_fields]
            cache_field = relation_position[:cache_field]
            field_offset = relation_position[:field_offset]

            attributes_offset = 0

            if cache_field
              related_fragments[rid][:cache] = cast_to_attribute_type(row[field_offset], cache_field[:type])
              attributes_offset+= 1
            end

            if attributes.length > 0
              related_fragments[rid][:attributes]= {}
              model_fields.each_with_index do |k, idx|
                related_fragments[rid][:attributes][k[0]] = cast_to_attribute_type(row[idx + field_offset + attributes_offset], k[1][:type])
              end
            end
          end
        end

        related_fragments
      end

      def find_records(filters, options = {})
        opts = options.dup

        sort_criteria = opts.fetch(:sort_criteria) { [] }

        join_tree = JoinTree.new(resource_klass: self,
                                 filters: filters,
                                 sort_criteria: sort_criteria,
                                 options: opts)

        records, joins = apply_joins(records(opts), join_tree, opts)

        opts[:joins] = joins

        records = filter_records(records, filters, opts)

        order_options = construct_order_options(sort_criteria)
        records = sort_records(records, order_options, opts)

        records = apply_pagination(records, opts[:paginator], order_options)

        records.distinct
      end

      def get_join_alias(records, &block)
        init_join_sources = records.arel.join_sources
        init_join_sources_length = init_join_sources.length

        records = yield(records)

        join_sources = records.arel.join_sources
        if join_sources.length > init_join_sources_length
          last_join = (join_sources - init_join_sources).last
          join_alias =
              case last_join.left
              when Arel::Table
                last_join.left.name
              when Arel::Nodes::TableAlias
                last_join.left.right
              when Arel::Nodes::StringJoin
                # :nocov:
                warn "get_join_alias: Unsupported join type - use custom filtering and sorting"
                nil
                # :nocov:
              end
        else
          # :nocov:
          warn "get_join_alias: No join added"
          join_alias = nil
          # :nocov:
        end

        return records, join_alias
      end

      def apply_joins(records, join_tree, _options)
        joins = join_tree.get_joins

        joins.each do |key, join_details|
          case join_details[:join_type]
          when :inner
            records, join_alias = get_join_alias(records) { |records| records.joins(join_details[:relation_path]) }
          when :left
            records, join_alias = get_join_alias(records) { |records| records.left_joins(join_details[:relation_path]) }
          end

          joins[key][:alias] = join_alias
        end

        return records, joins
      end

      def apply_pagination(records, paginator, order_options)
        records = paginator.apply(records, order_options) if paginator
        records
      end

      def apply_sort(records, order_options, options)
        if order_options.any?
          order_options.each_pair do |field, direction|
            records = apply_single_sort(records, field, direction, options)
          end
        end

        records
      end

      def apply_single_sort(records, field, direction, options)
        context = options[:context]

        strategy = _allowed_sort.fetch(field.to_sym, {})[:apply]

        if strategy
          call_method_or_proc(strategy, records, direction, context)
        else
          joins = options[:joins] || {}

          records.order("#{get_aliased_field(field, joins, options[:related_alias])} #{direction}")
        end
      end

      # Assumes ActiveRecord's counting. Override if you need a different counting method
      def count_records(records)
        records.count(:all)
      end

      def filter_records(records, filters, options)
        apply_filters(records, filters, options)
      end

      def sort_records(records, order_options, options)
        apply_sort(records, order_options, options)
      end

      def concat_table_field(table, field, quoted = false)
        if table.blank? || field.to_s.include?('.')
          # :nocov:
          if quoted
            "\"#{field.to_s}\""
          else
            field.to_s
          end
          # :nocov:
        else
          if quoted
            # :nocov:
            "\"#{table.to_s}\".\"#{field.to_s}\""
            # :nocov:
          else
            "#{table.to_s}.#{field.to_s}"
          end
        end
      end

      def apply_filters(records, filters, options = {})
        if filters
          filters.each do |filter, value|
            records = apply_filter(records, filter, value, options)
          end
        end

        records
      end

      def get_aliased_field(path_with_field, joins, related_alias)
        relationships, relationship_path, field = parse_relationship_path(path_with_field)
        relationship = relationships.last

        resource_klass = relationship ? relationship.resource_klass : self

        if field.empty?
          field_name = resource_klass._primary_key
        else
          field_name = resource_klass._attribute_delegated_name(field)
        end

        if relationship
          join_name = relationship_path

          join = joins.try(:[], join_name)

          table_alias = join.try(:[], :alias)
        else
          table_alias = related_alias
        end

        table_alias ||= resource_klass._table_name

        concat_table_field(table_alias, field_name)
      end

      def apply_filter(records, filter, value, options = {})
        strategy = _allowed_filters.fetch(filter.to_sym, Hash.new)[:apply]

        if strategy
          records = call_method_or_proc(strategy, records, value, options)
        else
          joins = options[:joins] || {}
          related_alias = options[:related_alias]
          records = records.where(get_aliased_field(filter, joins, related_alias) => value)
        end

        records
      end
    end
  end
end
