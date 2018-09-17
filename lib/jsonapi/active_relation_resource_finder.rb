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
        count_records(filter_records(filters, options))
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
      def find_fragments(filters, include_directives, options = {})
        records = find_records(filters, options)

        table_name = _model_class.table_name
        pluck_fields = [Arel.sql("#{concat_table_field(table_name, _primary_key)} AS #{table_name}_#{_primary_key}")]

        cache_field = attribute_to_model_field(:_cache_field) if options[:cache]
        if cache_field
          pluck_fields << Arel.sql("#{concat_table_field(table_name, cache_field[:name])} AS #{table_name}_#{cache_field[:name]}")
        end

        linkage_fields = {}
        if include_directives[:include_linkage]
          include_directives[:include_linkage].each_key do |relationship_name|
            relationship = self._relationships[relationship_name]
            if relationship.is_a?(JSONAPI::Relationship::ToOne)
              linkage_fields[relationship_name] = {resource_klass: relationship.resource_klass}

              if relationship.belongs_to?
                foreign_key = relationship.foreign_key
                pluck_fields << "#{concat_table_field(self._table_name, foreign_key)} AS #{relationship_name}_#{foreign_key}"
                if relationship.polymorphic?
                  pluck_fields << "#{concat_table_field(self._table_name, relationship.polymorphic_type)} AS #{relationship_name}_#{relationship.polymorphic_type}"
                  linkage_fields[relationship_name][:polymorphic] = true
                end
              else
                records, table_alias = apply_related_linkage_join(records, relationship, table_name, options)
                linkage_field = "#{table_alias}_#{relationship.resource_klass._primary_key}"
                pluck_fields << "#{concat_table_field(table_alias, relationship.resource_klass._primary_key)} AS #{linkage_field}"
                linkage_fields[relationship_name] = {resource_klass: relationship.resource_klass}
              end
            end
          end
        end

        model_fields = {}
        attributes = options[:attributes]
        attributes.try(:each) do |attribute|
          model_field = attribute_to_model_field(attribute)
          model_fields[attribute] = model_field
          pluck_fields << Arel.sql("#{concat_table_field(table_name, model_field[:name])} AS #{table_name}_#{model_field[:name]}")
        end

        fragments = {}
        rows = records.pluck(*pluck_fields)
        rows.collect do |row|
          rid = JSONAPI::ResourceIdentity.new(self, pluck_fields.length == 1 ? row : row[0])

          fragments[rid] ||= JSONAPI::ResourceFragment.new(rid)
          attributes_offset = 1

          if cache_field
            fragments[rid].cache = cast_to_attribute_type(row[1], cache_field[:type])
            attributes_offset+= 1
          end

          linkage_fields.each do |relationship_name, linkage_field_details|
            fragments[rid].initialize_related(relationship_name)
            related_id = row[attributes_offset]
            if related_id
              if linkage_field_details[:polymorphic]
                attributes_offset+= 1
                related_type = row[attributes_offset]
                related_rid = JSONAPI::ResourceIdentity.new(JSONAPI::Resource.resource_klass_for(related_type), related_id)
              else
                related_rid = JSONAPI::ResourceIdentity.new(linkage_field_details[:resource_klass], related_id)
              end
              fragments[rid].add_related_identity(relationship_name, related_rid)
            end
            attributes_offset+= 1
          end

          model_fields.each_with_index do |k, idx|
            fragments[rid].attributes[k[0]]= cast_to_attribute_type(row[idx + attributes_offset], k[1][:type])
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
      def find_related_fragments(source_rids, include_directives, relationship_name, options, included_key = nil)
        relationship = _relationship(relationship_name)

        if relationship.polymorphic?
          find_related_polymorphic_fragments(source_rids, include_directives, relationship, options, false)
        else
          find_related_monomorphic_fragments(source_rids, include_directives, relationship, included_key, options, false)
        end
      end

      def find_relationship_fragments(source_rids, include_directives, relationship_name, options)
        relationship = _relationship(relationship_name)

        if relationship.polymorphic?
          find_related_polymorphic_fragments(source_rids, include_directives, relationship, options, true)
        else
          find_related_monomorphic_fragments(source_rids, include_directives, relationship, nil, options, true)
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
        relationship = _relationship(relationship_name)
        related_klass = relationship.resource_klass

        context = options[:context]

        records, table_alias = apply_join(records(context: context), relationship, options)

        filters = options.fetch(:filters, {})

        primary_key_field = concat_table_field(_table_name, _primary_key)
        filters[primary_key_field] = source_rid.id

        filter_options = options.dup
        filter_options[:table_alias] = table_alias
        records = related_klass.apply_filters(records, filters, filter_options)
        records.count(:all)
      end

      # Determine if a resource can provide linkage data for a relationship.
      # Currently this Resource Finder can return Linkage data for to_one relationships, with the exception of
      # to_one where the inverse relationship is polymorphic or the inverse_relationship is not resolved
      #
      # @param relationship_name [String | Symbol] The name of the relationship
      #
      # @return [Boolean]
      def include_additional_relationship_linkage_data?(relationship_name)
        relationship = _relationship(relationship_name.to_sym)

        # relationship.is_a?(JSONAPI::Relationship::ToOne) && relationship.belongs_to? && relationship.include_linkage_data?
        if relationship.include_linkage_data?
          if relationship.is_a?(JSONAPI::Relationship::ToOne)
            if relationship.foreign_key_on == :self
              return true
            end

            inverse_relationship = relationship.resource_klass._relationship(relationship.inverse_relationship.to_sym)
            if inverse_relationship && !inverse_relationship.polymorphic?
              return true
            end
          end
        end

        false
      end

      protected

      def find_record_by_key(key, options = {})
        records = find_records({ _primary_key => key }, options.except(:paginator, :sort_criteria))
        record = records.first
        fail JSONAPI::Exceptions::RecordNotFound.new(key) if record.nil?
        record
      end

      def find_records_by_keys(keys, options = {})
        records = records(options)
        records = apply_includes(records, options)
        records.where({ _primary_key => keys })
      end

      def find_related_monomorphic_fragments(source_rids, include_directives, relationship, included_key, options, relationship_request)
        source_ids = source_rids.collect {|rid| rid.id}

        context = options[:context]

        related_klass = relationship.resource_klass

        records, table_alias = apply_join(records(context: context), relationship, options)

        sort_criteria = []
        options[:sort_criteria].try(:each) do |sort|
          field = sort[:field].to_s == 'id' ? related_klass._primary_key : sort[:field]
          sort_criteria << { field: concat_table_field(table_alias, field),
                             direction: sort[:direction] }
        end

        order_options = related_klass.construct_order_options(sort_criteria)

        paginator = options[:paginator]

        # ToDO: Remove count check. Currently pagination isn't working with multiple source_rids (i.e. it only works
        # for show relationships, not related includes).
        # Check included_key to not paginate included resources but ensure that nested resources can be paginated
        if paginator && source_rids.count == 1 && !included_key
          records = related_klass.apply_pagination(records, paginator, order_options)
        end

        records = related_klass.apply_basic_sort(records, order_options, context: context)

        filters = options.fetch(:filters, {})

        primary_key_field = concat_table_field(_table_name, _primary_key)

        filters[primary_key_field] = source_ids

        filter_options = options.dup
        filter_options[:table_alias] = table_alias

        records = related_klass.apply_filters(records, filters, filter_options)

        pluck_fields = [
            Arel.sql("#{primary_key_field} AS #{_table_name}_#{_primary_key}"),
            Arel.sql("#{concat_table_field(table_alias, related_klass._primary_key)} AS #{table_alias}_#{related_klass._primary_key}")
        ]

        cache_field = related_klass.attribute_to_model_field(:_cache_field) if options[:cache]
        if cache_field
          pluck_fields << Arel.sql("#{concat_table_field(table_alias, cache_field[:name])} AS #{table_alias}_#{cache_field[:name]}")
        end

        linkage_fields = {}
        if include_directives[:include_linkage]
          include_directives[:include_linkage].each_key do |relationship_name|
            include_relationship = related_klass._relationships[relationship_name]
            if include_relationship.is_a?(JSONAPI::Relationship::ToOne)
              linkage_fields[relationship_name] = {resource_klass: include_relationship.resource_klass}

              if include_relationship.belongs_to?
                foreign_key = include_relationship.foreign_key
                pluck_fields << "#{concat_table_field(table_alias, foreign_key)} AS #{table_alias}_#{foreign_key}"
              else
                if relationship.inverse_relationship == relationship_name
                  # This is the parent relationship so no need for joins
                  pluck_fields << "#{primary_key_field} AS linkage_#{_table_name}_#{_primary_key}"
                else
                  records, related_table_alias = apply_related_linkage_join(records, include_relationship, table_alias, options)
                  linkage_field = "#{related_table_alias}_#{include_relationship.resource_klass._primary_key}"
                  pluck_fields << "#{concat_table_field(related_table_alias, include_relationship.resource_klass._primary_key)} AS #{linkage_field}"
                end
              end
            end
          end
        end

        model_fields = {}
        attributes = options[:attributes]
        attributes.try(:each) do |attribute|
          model_field = related_klass.attribute_to_model_field(attribute)
          model_fields[attribute] = model_field
          pluck_fields << Arel.sql("#{concat_table_field(table_alias, model_field[:name])} AS #{table_alias}_#{model_field[:name]}")
        end

        rows = records.pluck(*pluck_fields)

        related_fragments = {}

        rows.each do |row|
          unless row[1].nil?
            rid = JSONAPI::ResourceIdentity.new(related_klass, row[1])

            related_fragments[rid] ||= JSONAPI::ResourceFragment.new(rid)

            attributes_offset = 2

            if cache_field
              related_fragments[rid].cache = cast_to_attribute_type(row[attributes_offset], cache_field[:type])
              attributes_offset+= 1
            end

            model_fields.each_with_index do |k, idx|
              related_fragments[rid].add_attribute(k[0], cast_to_attribute_type(row[idx + attributes_offset], k[1][:type]))
              attributes_offset+= 1
            end

            source_rid = JSONAPI::ResourceIdentity.new(self, row[0])

            related_fragments[rid].add_related_from(source_rid)

            linkage_fields.each do |relationship_name, linkage_field_details|
              related_fragments[rid].initialize_related(relationship_name)
              related_id = row[attributes_offset]
              if related_id
                related_rid = JSONAPI::ResourceIdentity.new(linkage_field_details[:resource_klass], related_id)
                related_fragments[rid].add_related_identity(relationship_name, related_rid)
              end
              attributes_offset+= 1
            end

            unless relationship_request
              related_relationship = related_klass._relationships[relationship.inverse_relationship]
              if related_relationship
                related_fragments[rid].add_related_identity(related_relationship.name, source_rid)
              end
            end
          end
        end

        related_fragments
      end

      # Gets resource identities where the related resource is polymorphic and the resource type and id
      # are stored on the primary resources. Cache fields will always be on the related resources.
      def find_related_polymorphic_fragments(source_rids, include_directives, relationship, options, relationship_request)
        source_ids = source_rids.collect {|rid| rid.id}

        context = options[:context]

        records = records(context: context)

        primary_key_field = concat_table_field(_table_name, _primary_key)
        related_key = concat_table_field(_table_name, relationship.foreign_key)
        related_type = concat_table_field(_table_name, relationship.polymorphic_type)

        pluck_fields = [
            Arel.sql("#{primary_key_field} AS #{_table_name}_#{_primary_key}"),
            Arel.sql("#{related_key} AS #{_table_name}_#{relationship.foreign_key}"),
            Arel.sql("#{related_type} AS #{_table_name}_#{relationship.polymorphic_type}")
        ]

        relations = relationship.polymorphic_resource_names

        # Get the additional fields from each relation. There's a limitation that the fields must exist in each relation

        relation_positions = {}
        relation_index = 3

        attributes = options.fetch(:attributes, [])

        if relations.nil? || relations.length == 0
          warn "No relations found for polymorphic relationship."
        else
          relations.try(:each) do |relation|
            related_klass = resource_klass_for(relation.to_s)

            cache_field = related_klass.attribute_to_model_field(:_cache_field) if options[:cache]

            # We only need to join the relations if we are getting additional fields, including the cache field
            if cache_field || attributes.length > 0 || (include_directives[:include_linkage] && include_directives[:include_linkage][relation])
              records, table_alias = apply_join(records, relationship, options, relation)
            end

            cache_offset = relation_index
            if cache_field
              pluck_fields << "#{concat_table_field(table_alias, cache_field[:name])} as cache_#{relation}_#{cache_field[:name]}"
              relation_index+= 1
            end

            model_fields = {}
            field_offset = relation_index
            attributes.try(:each) do |attribute|
              model_field = related_klass.attribute_to_model_field(attribute)
              model_fields[attribute] = model_field
              relation_index+= 1
            end

            model_fields.each do |_k, v|
              pluck_fields << concat_table_field(table_alias, v[:name])
            end

            linkage_fields = {}
            linkage_offset = relation_index
            if include_directives[:include_linkage] && include_directives[:include_linkage][relation]
              include_directives[:include_linkage][relation].each_key do |relationship_name|
                include_relationship = related_klass._relationships[relationship_name]
                if include_relationship.is_a?(JSONAPI::Relationship::ToOne)
                  linkage_fields[relationship_name] = {resource_klass: include_relationship.resource_klass}

                  if include_relationship.belongs_to?
                    foreign_key = include_relationship.foreign_key
                    relation_index+= 1
                    pluck_fields << "#{concat_table_field(table_alias, foreign_key)} AS #{table_alias}_#{foreign_key}"
                  end
                else
                  if relationship.inverse_relationship == relationship_name
                    pluck_fields << "#{primary_key_field} AS linkage_#{relation}_#{_primary_key}"
                  end
                end
              end
            end

            related = related_klass._model_class.name
            relation_positions[related] = { relation_klass: related_klass,
                                            cache_field: cache_field,
                                            cache_offset: cache_offset,
                                            model_fields: model_fields,
                                            field_offset: field_offset,
                                            linkage_fields: linkage_fields,
                                            linkage_offset: linkage_offset
            }
          end
        end

        primary_resource_filters = options[:filters]
        primary_resource_filters ||= {}

        primary_resource_filters[_primary_key] = source_ids

        records = apply_filters(records, primary_resource_filters, options)

        rows = records.pluck(*pluck_fields)

        related_fragments = {}

        rows.each do |row|
          unless row[1].nil? || row[2].nil?
            related_klass = resource_klass_for(row[2])

            rid = JSONAPI::ResourceIdentity.new(related_klass, row[1])
            related_fragments[rid] ||= JSONAPI::ResourceFragment.new(rid)

            source_rid = JSONAPI::ResourceIdentity.new(self, row[0])

            related_fragments[rid].add_related_from(source_rid)

            unless relationship_request
              related_relationship = related_klass._relationships[relationship.inverse_relationship]
              if related_relationship
                related_fragments[rid].add_related_identity(related_relationship.name, source_rid)
              end
            end

            relation_position = relation_positions[row[2]]
            model_fields = relation_position[:model_fields]
            cache_field = relation_position[:cache_field]
            cache_offset = relation_position[:cache_offset]
            field_offset = relation_position[:field_offset]
            linkage_fields = relation_position[:linkage_fields]
            linkage_offset = relation_position[:linkage_offset]

            if cache_field
              related_fragments[rid].cache = cast_to_attribute_type(row[cache_offset], cache_field[:type])
            end

            if attributes.length > 0
              model_fields.each_with_index do |k, idx|
                related_fragments[rid].add_attribute(k[0], cast_to_attribute_type(row[idx + field_offset], k[1][:type]))
              end
            end

            linkage_fields.each_with_index do |(relationship_name, linkage_field_details), idx|
              related_fragments[rid].initialize_related(relationship_name)
              related_id = row[linkage_offset + idx]
              if related_id
                related_rid = JSONAPI::ResourceIdentity.new(linkage_field_details[:resource_klass], related_id)
                related_fragments[rid].add_related_identity(relationship_name, related_rid)
              end
            end
          end
        end

        related_fragments
      end

      def find_records(filters, options = {})
        context = options[:context]

        records = filter_records(filters, options)

        sort_criteria = options.fetch(:sort_criteria) { [] }
        order_options = construct_order_options(sort_criteria)
        records = sort_records(records, order_options, context)

        records = apply_pagination(records, options[:paginator], order_options)

        records
      end

      def apply_includes(records, options = {})
        include_directives = options[:include_directives]
        if include_directives
          model_includes = resolve_relationship_names_to_relations(self, include_directives.model_includes, options)
          records = records.joins(model_includes).references(model_includes)
        end

        records
      end

      def apply_pagination(records, paginator, order_options)
        records = paginator.apply(records, order_options) if paginator
        records
      end

      def apply_sort(records, order_options, context = {})
        if order_options.any?
          order_options.each_pair do |field, direction|
            records = apply_single_sort(records, field, direction, context)
          end
        end

        records
      end

      def apply_single_sort(records, field, direction, context = {})
        strategy = _allowed_sort.fetch(field.to_sym, {})[:apply]

        if strategy
          call_method_or_proc(strategy, records, direction, context)
        else
          if field.to_s.include?(".")
            *model_names, column_name = field.split(".")

            associations = _lookup_association_chain([records.model.to_s, *model_names])
            joins_query = _build_joins([records.model, *associations])

            order_by_query = "#{_join_table_name(associations.last)}.#{column_name} #{direction}"
            records.joins(joins_query).order(order_by_query)
          else
            field = _attribute_delegated_name(field)
            records.order(field => direction)
          end
        end
      end

      def apply_basic_sort(records, order_options, _context = {})
        if order_options.any?
          order_options.each_pair do |field, direction|
            records = records.order("#{field} #{direction}")
          end
        end

        records
      end

      def _build_joins(associations)
        joins = []

        associations.inject do |prev, current|
          prev_table_name = _join_table_name(prev)
          curr_table_name = _join_table_name(current)
          relationship_primary_key = current.options.fetch(:primary_key, "id")
          if current.belongs_to?
            joins << "LEFT JOIN #{current.table_name} AS #{curr_table_name} ON #{curr_table_name}.#{relationship_primary_key} = #{prev_table_name}.#{current.foreign_key}"
          else
            joins << "LEFT JOIN #{current.table_name} AS #{curr_table_name} ON #{curr_table_name}.#{current.foreign_key} = #{prev_table_name}.#{relationship_primary_key}"
          end

          current
        end
        joins.join("\n")
      end

      # _sorting is appended to avoid name clashes with manual joins eg. overridden filters
      def _join_table_name(association)
        if association.is_a?(ActiveRecord::Reflection::AssociationReflection)
          "#{association.name}_sorting"
        else
          association.table_name
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
            unless relationship
              warn "relationship no found."
            end
            return relationship.relation_name(options)
        end
      end

      def apply_filter(records, filter, value, options = {})
        strategy = _allowed_filters.fetch(filter.to_sym, Hash.new)[:apply]

        if strategy
          call_method_or_proc(strategy, records, value, options)
        else
          filter = _attribute_delegated_name(filter)
          table_alias = options[:table_alias]
          records.where(concat_table_field(table_alias, filter) => value)
        end
      end

      def apply_filters(records, filters, options = {})
        required_includes = []

        if filters
          filters.each do |filter, value|
            strategy = _allowed_filters.fetch(filter.to_sym, Hash.new)[:apply]

            if strategy
              records = apply_filter(records, filter, value, options)
            elsif _relationships.include?(filter)
              if _relationships[filter].belongs_to?
                records = apply_filter(records, _relationships[filter].foreign_key, value, options)
              else
                required_includes.push(filter.to_s)
                records = apply_filter(records, "#{_relationships[filter].table_name}.#{_relationships[filter].primary_key}", value, options)
              end
            else
              records = apply_filter(records, filter, value, options)
            end
          end
        end

        if required_includes.any?
          records = apply_includes(records, options.merge(include_directives: IncludeDirectives.new(self, required_includes, force_eager_load: true)))
        end

        records
      end

      def filter_records(filters, options, records = records(options))
        apply_filters(records, filters, options)
      end

      def sort_records(records, order_options, context = {})
        apply_sort(records, order_options, context)
      end

      def concat_table_field(table, field, quoted = false)
        if table.nil? || field.to_s.include?('.')
          if quoted
            "\"#{field.to_s}\""
          else
            field.to_s
          end
        else
          if quoted
            "\"#{table.to_s}\".\"#{field.to_s}\""
          else
            "#{table.to_s}.#{field.to_s}"
          end
        end
      end

      def apply_join(records, relationship, options, polymorphic_relation_name = nil)
        custom_apply_join = relationship.custom_methods[:apply_join]

        if custom_apply_join
          # Set a default alias for the join to use, which it may change by updating the option
          table_alias = relationship.resource_klass._table_name

          custom_apply_options = {
              relationship: relationship,
              polymorphic_relation_name: polymorphic_relation_name,
              context: options[:context],
              records: records,
              table_alias: table_alias,
              options: options}

          records = custom_apply_join.call(custom_apply_options)

          # Get the table alias in case it was changed
          table_alias = custom_apply_options[:table_alias]
        else
          if relationship.polymorphic?
            parent_table_alias = relationship.parent_resource._table_name

            relation_name = polymorphic_relation_name
            related_klass = resource_klass_for(relation_name.to_s)
            related_table_name = related_klass._table_name

            join_statement = "LEFT OUTER JOIN #{related_table_name} ON #{parent_table_alias}.#{relationship.foreign_key} = #{related_table_name}.#{related_klass._primary_key} AND #{concat_table_field(parent_table_alias, relationship.polymorphic_type, true)} = \"#{relation_name.capitalize}\""
            records = records.joins(join_statement)

            table_alias = related_klass._table_name
          else
            relation_name = relationship.relation_name(options)
            related_klass = relationship.resource_klass
            table_alias = related_klass._table_name

            records = records.joins(relation_name).references(relation_name)
          end
        end

        return records, table_alias
      end

      def apply_related_linkage_join(records, relationship, parent_table_alias, options, polymorphic_relation_name = nil)
        custom_apply_join = relationship.custom_methods[:apply_join]

        if custom_apply_join
          # Set a default alias for the join to use, which it may change by updating the option
          table_alias = relationship.resource_klass._table_name

          custom_apply_options = {
              relationship: relationship,
              polymorphic_relation_name: polymorphic_relation_name,
              context: options[:context],
              records: records,
              parent_table_alias: parent_table_alias,
              related_linkage_join: true,
              table_alias: table_alias,
              options: options}

          records = custom_apply_join.call(custom_apply_options)

          # Get the table alias in case it was changed
          table_alias = custom_apply_options[:table_alias]
        else
          related_klass = relationship.resource_klass
          parent_resource_klass = relationship.parent_resource
          related_table_name = related_klass._table_name

          table_alias = "#{parent_table_alias}_#{relationship.name}"

          join_statement = "LEFT OUTER JOIN #{related_table_name} #{table_alias} ON #{table_alias}.#{relationship.foreign_key} = #{parent_table_alias}.#{parent_resource_klass._primary_key}"
          records = records.joins(join_statement)
        end

        return records, table_alias
      end
    end
  end
end
