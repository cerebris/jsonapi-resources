require 'jsonapi/active_relation_resource_finder/adapters/join_left_active_record_adapter'

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
        sort_criteria = options.fetch(:sort_criteria) { [] }

        join_tree = JoinTree.new(resource_klass: self,
                                 options: options,
                                 filters: filters,
                                 sort_criteria: sort_criteria)

        paginator = options[:paginator]

        records = find_records(records: records(options),
                               filters: filters,
                               join_tree: join_tree,
                               paginator: paginator,
                               options: options)

        resources_for(records, options[:context])
      end

      # Counts Resources found using the `filters`
      #
      # @param filters [Hash] the filters hash
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [Integer] the count
      def count(filters, options = {})
        join_tree = JoinTree.new(resource_klass: self,
                                 options: options,
                                 filters: filters)

        records = find_records(records: records(options),
                               filters: filters,
                               join_tree: join_tree,
                               options: options)

        count_records(records)
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
      # Note: This is incompatible with Polymorphic resources (which are going to come from two separate tables)
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
        include_directives = options[:include_directives] ? options[:include_directives].include_directives : {}
        resource_klass = self
        linkage_relationships = to_one_relationships_for_linkage(include_directives[:include_related])

        sort_criteria = options.fetch(:sort_criteria) { [] }

        join_tree = JoinTree.new(resource_klass: resource_klass,
                                 source_relationship: nil,
                                 relationships: linkage_relationships,
                                 sort_criteria: sort_criteria,
                                 filters: filters,
                                 options: options)

        paginator = options[:paginator]

        records = find_records(records: records(options),
                               filters: filters,
                               sort_criteria: sort_criteria,
                               paginator: paginator,
                               join_tree: join_tree,
                               options: options)

        joins = join_tree.joins

        # This alias is going to be resolve down to the model's table name and will not actually be an alias
        resource_table_alias = joins[''][:alias]

        pluck_fields = [Arel.sql("#{concat_table_field(resource_table_alias, resource_klass._primary_key)} AS #{resource_table_alias}_#{resource_klass._primary_key}")]

        cache_field = attribute_to_model_field(:_cache_field) if options[:cache]
        if cache_field
          pluck_fields << Arel.sql("#{concat_table_field(resource_table_alias, cache_field[:name])} AS #{resource_table_alias}_#{cache_field[:name]}")
        end

        linkage_fields = []

        linkage_relationships.each do |name|
          linkage_relationship = resource_klass._relationship(name)

          if linkage_relationship.polymorphic? && linkage_relationship.belongs_to?
            linkage_relationship.resource_types.each do |resource_type|
              klass = resource_klass_for(resource_type)
              linkage_fields << {relationship_name: name, resource_klass: klass}

              linkage_table_alias = joins["#{linkage_relationship.name.to_s}##{resource_type}"][:alias]
              primary_key = klass._primary_key
              pluck_fields << Arel.sql("#{concat_table_field(linkage_table_alias, primary_key)} AS #{linkage_table_alias}_#{primary_key}")
            end
          else
            klass = linkage_relationship.resource_klass
            linkage_fields << {relationship_name: name, resource_klass: klass}

            linkage_table_alias = joins[name.to_s][:alias]
            primary_key = klass._primary_key
            pluck_fields << Arel.sql("#{concat_table_field(linkage_table_alias, primary_key)} AS #{linkage_table_alias}_#{primary_key}")
          end
        end

        model_fields = {}
        attributes = options[:attributes]
        attributes.try(:each) do |attribute|
          model_field = resource_klass.attribute_to_model_field(attribute)
          model_fields[attribute] = model_field
          pluck_fields << Arel.sql("#{concat_table_field(resource_table_alias, model_field[:name])} AS #{resource_table_alias}_#{model_field[:name]}")
        end

        fragments = {}
        rows = records.pluck(*pluck_fields)
        rows.collect do |row|
          rid = JSONAPI::ResourceIdentity.new(resource_klass, pluck_fields.length == 1 ? row : row[0])

          fragments[rid] ||= JSONAPI::ResourceFragment.new(rid)
          attributes_offset = 1

          if cache_field
            fragments[rid].cache = cast_to_attribute_type(row[1], cache_field[:type])
            attributes_offset+= 1
          end

          linkage_fields.each do |linkage_field_details|
            fragments[rid].initialize_related(linkage_field_details[:relationship_name])
            related_id = row[attributes_offset]
            if related_id
              related_rid = JSONAPI::ResourceIdentity.new(linkage_field_details[:resource_klass], related_id)
              fragments[rid].add_related_identity(linkage_field_details[:relationship_name], related_rid)
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
      def find_related_fragments(source_rids, relationship_name, options = {})
        relationship = _relationship(relationship_name)

        if relationship.polymorphic? # && relationship.foreign_key_on == :self
          find_related_polymorphic_fragments(source_rids, relationship, options, false)
        else
          find_related_monomorphic_fragments(source_rids, relationship, options, false)
        end
      end

      def find_included_fragments(source_rids, relationship_name, options)
        relationship = _relationship(relationship_name)

        if relationship.polymorphic? # && relationship.foreign_key_on == :self
          find_related_polymorphic_fragments(source_rids, relationship, options, true)
        else
          find_related_monomorphic_fragments(source_rids, relationship, options, true)
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

        filters = options.fetch(:filters, {})

        # Joins in this case are related to the related_klass
        join_tree = JoinTree.new(resource_klass: self,
                                 source_relationship: relationship,
                                 filters: filters,
                                 options: options)

        records = find_records(records: records(options),
                               resource_klass: related_klass,
                               primary_keys: source_rid.id,
                               join_tree: join_tree,
                               filters: filters,
                               options: options)

        joins = join_tree.joins
        related_alias = joins[''][:alias]

        records = records.select(Arel.sql("#{concat_table_field(related_alias, related_klass._primary_key)}"))

        count_records(records)
      end

      def records(_options = {})
        _model_class.distinct.all
      end

      protected

      def to_one_relationships_for_linkage(include_related)
        include_related ||= {}
        relationships = []
        _relationships.each do |name, relationship|
          if relationship.is_a?(JSONAPI::Relationship::ToOne) && !include_related.has_key?(name) && relationship.include_optional_linkage_data?
            relationships << name
          end
        end
        relationships
      end

      def find_record_by_key(key, options = {})
        record = find_records(records: records(options), primary_keys: key, options: options).first
        fail JSONAPI::Exceptions::RecordNotFound.new(key) if record.nil?
        record
      end

      def find_records_by_keys(keys, options = {})
        find_records(records: records(options), primary_keys: keys, options: options)
      end

      def find_related_monomorphic_fragments(source_rids, relationship, options, connect_source_identity)
        filters = options.fetch(:filters, {})
        source_ids = source_rids.collect {|rid| rid.id}

        include_directives = options[:include_directives] ? options[:include_directives].include_directives : {}
        resource_klass = relationship.resource_klass
        linkage_relationships = resource_klass.to_one_relationships_for_linkage(include_directives[:include_related])

        sort_criteria = []
        options[:sort_criteria].try(:each) do |sort|
          field = sort[:field].to_s == 'id' ? resource_klass._primary_key : sort[:field]
          sort_criteria << { field: field, direction: sort[:direction] }
        end

        join_tree = JoinTree.new(resource_klass: self,
                                 source_relationship: relationship,
                                 relationships: linkage_relationships,
                                 sort_criteria: sort_criteria,
                                 filters: filters,
                                 options: options)

        paginator = options[:paginator] if source_rids.count == 1

        records = find_records(records: records(options),
                               resource_klass: resource_klass,
                               sort_criteria: sort_criteria,
                               primary_keys: source_ids,
                               paginator: paginator,
                               filters: filters,
                               join_tree: join_tree,
                               options: options)

        joins = join_tree.joins
        resource_table_alias = joins[''][:alias]

        pluck_fields = [
            Arel.sql("#{_table_name}.#{_primary_key} AS source_id"),
            Arel.sql("#{concat_table_field(resource_table_alias, resource_klass._primary_key)} AS #{resource_table_alias}_#{resource_klass._primary_key}")
        ]

        cache_field = resource_klass.attribute_to_model_field(:_cache_field) if options[:cache]
        if cache_field
          pluck_fields << Arel.sql("#{concat_table_field(resource_table_alias, cache_field[:name])} AS #{resource_table_alias}_#{cache_field[:name]}")
        end

        linkage_fields = []

        linkage_relationships.each do |name|
          linkage_relationship = resource_klass._relationship(name)

          if linkage_relationship.polymorphic? && linkage_relationship.belongs_to?
            linkage_relationship.resource_types.each do |resource_type|
              klass = resource_klass_for(resource_type)
              linkage_fields << {relationship_name: name, resource_klass: klass}

              linkage_table_alias = joins["#{linkage_relationship.name.to_s}##{resource_type}"][:alias]
              primary_key = klass._primary_key
              pluck_fields << Arel.sql("#{concat_table_field(linkage_table_alias, primary_key)} AS #{linkage_table_alias}_#{primary_key}")
            end
          else
            klass = linkage_relationship.resource_klass
            linkage_fields << {relationship_name: name, resource_klass: klass}

            linkage_table_alias = joins[name.to_s][:alias]
            primary_key = klass._primary_key
            pluck_fields << Arel.sql("#{concat_table_field(linkage_table_alias, primary_key)} AS #{linkage_table_alias}_#{primary_key}")
          end
        end

        model_fields = {}
        attributes = options[:attributes]
        attributes.try(:each) do |attribute|
          model_field = resource_klass.attribute_to_model_field(attribute)
          model_fields[attribute] = model_field
          pluck_fields << Arel.sql("#{concat_table_field(resource_table_alias, model_field[:name])} AS #{resource_table_alias}_#{model_field[:name]}")
        end

        fragments = {}
        rows = records.pluck(*pluck_fields)
        rows.each do |row|
          rid = JSONAPI::ResourceIdentity.new(resource_klass, row[1])

          fragments[rid] ||= JSONAPI::ResourceFragment.new(rid)

          attributes_offset = 2

          if cache_field
            fragments[rid].cache = cast_to_attribute_type(row[attributes_offset], cache_field[:type])
            attributes_offset+= 1
          end

          model_fields.each_with_index do |k, idx|
            fragments[rid].add_attribute(k[0], cast_to_attribute_type(row[idx + attributes_offset], k[1][:type]))
            attributes_offset+= 1
          end

          source_rid = JSONAPI::ResourceIdentity.new(self, row[0])

          fragments[rid].add_related_from(source_rid)

          linkage_fields.each do |linkage_field|
            fragments[rid].initialize_related(linkage_field[:relationship_name])
            related_id = row[attributes_offset]
            if related_id
              related_rid = JSONAPI::ResourceIdentity.new(linkage_field[:resource_klass], related_id)
              fragments[rid].add_related_identity(linkage_field[:relationship_name], related_rid)
            end
            attributes_offset+= 1
          end

          if connect_source_identity
            related_relationship = resource_klass._relationships[relationship.inverse_relationship]
            if related_relationship
              fragments[rid].add_related_identity(related_relationship.name, source_rid)
            end
          end
        end

        fragments
      end

      # Gets resource identities where the related resource is polymorphic and the resource type and id
      # are stored on the primary resources. Cache fields will always be on the related resources.
      def find_related_polymorphic_fragments(source_rids, relationship, options, connect_source_identity)
        filters = options.fetch(:filters, {})
        source_ids = source_rids.collect {|rid| rid.id}

        resource_klass = relationship.resource_klass
        include_directives = options[:include_directives] ? options[:include_directives].include_directives : {}

        linkage_relationships = []

        resource_types = relationship.resource_types

        resource_types.each do |resource_type|
          related_resource_klass = resource_klass_for(resource_type)
          relationships = related_resource_klass.to_one_relationships_for_linkage(include_directives[:include_related])
          relationships.each do |r|
            linkage_relationships << "##{resource_type}.#{r}"
          end
        end

        join_tree = JoinTree.new(resource_klass: self,
                                 source_relationship: relationship,
                                 relationships: linkage_relationships,
                                 filters: filters,
                                 options: options)

        paginator = options[:paginator] if source_rids.count == 1

        # Note: We will sort by the source table. Without using unions we can't sort on a polymorphic relationship
        # in any manner that makes sense
        records = find_records(records: records(options),
                               resource_klass: resource_klass,
                               sort_primary: true,
                               primary_keys: source_ids,
                               paginator: paginator,
                               filters: filters,
                               join_tree: join_tree,
                               options: options)

        joins = join_tree.joins

        primary_key = concat_table_field(_table_name, _primary_key)
        related_key = concat_table_field(_table_name, relationship.foreign_key)
        related_type = concat_table_field(_table_name, relationship.polymorphic_type)

        pluck_fields = [
            Arel.sql("#{primary_key} AS #{_table_name}_#{_primary_key}"),
            Arel.sql("#{related_key} AS #{_table_name}_#{relationship.foreign_key}"),
            Arel.sql("#{related_type} AS #{_table_name}_#{relationship.polymorphic_type}")
        ]

        # Get the additional fields from each relation. There's a limitation that the fields must exist in each relation

        relation_positions = {}
        relation_index = pluck_fields.length

        attributes = options.fetch(:attributes, [])

        # Add resource specific fields
        if resource_types.nil? || resource_types.length == 0
          # :nocov:
          warn "No resource types found for polymorphic relationship."
          # :nocov:
        else
          resource_types.try(:each) do |type|
            related_klass = resource_klass_for(type.to_s)

            cache_field = related_klass.attribute_to_model_field(:_cache_field) if options[:cache]

            table_alias = joins["##{type}"][:alias]

            cache_offset = relation_index
            if cache_field
              pluck_fields << Arel.sql("#{concat_table_field(table_alias, cache_field[:name])} AS cache_#{type}_#{cache_field[:name]}")
              relation_index+= 1
            end

            model_fields = {}
            field_offset = relation_index
            attributes.try(:each) do |attribute|
              model_field = related_klass.attribute_to_model_field(attribute)
              model_fields[attribute] = model_field
              pluck_fields << Arel.sql("#{concat_table_field(table_alias, model_field[:name])} AS #{table_alias}_#{model_field[:name]}")
              relation_index+= 1
            end

            model_offset = relation_index
            model_fields.each do |_k, v|
              pluck_fields << Arel.sql("#{concat_table_field(table_alias, v[:name])}")
              relation_index+= 1
            end

            relation_positions[type] = {relation_klass: related_klass,
                                        cache_field: cache_field,
                                        cache_offset: cache_offset,
                                        model_fields: model_fields,
                                        model_offset: model_offset,
                                        field_offset: field_offset}
          end
        end

        # Add to_one linkage fields
        linkage_fields = []
        linkage_offset = relation_index

        linkage_relationships.each do |linkage_relationship_path|
          path = JSONAPI::Path.new(resource_klass: self,
                                   path_string: "#{relationship.name}#{linkage_relationship_path}",
                                   ensure_default_field: false)

          linkage_relationship = path.segments[-1].relationship

          if linkage_relationship.polymorphic? && linkage_relationship.belongs_to?
            linkage_relationship.resource_types.each do |resource_type|
              klass = resource_klass_for(resource_type)
              linkage_fields << {relationship: linkage_relationship, resource_klass: klass}

              linkage_table_alias = joins[linkage_relationship_path][:alias]
              primary_key = klass._primary_key
              pluck_fields << Arel.sql("#{concat_table_field(linkage_table_alias, primary_key)} AS #{linkage_table_alias}_#{primary_key}")
            end
          else
            klass = linkage_relationship.resource_klass
            linkage_fields << {relationship: linkage_relationship, resource_klass: klass}

            linkage_table_alias = joins[linkage_relationship_path.to_s][:alias]
            primary_key = klass._primary_key
            pluck_fields << Arel.sql("#{concat_table_field(linkage_table_alias, primary_key)} AS #{linkage_table_alias}_#{primary_key}")
          end
        end

        rows = records.pluck(*pluck_fields)

        related_fragments = {}

        rows.each do |row|
          unless row[1].nil? || row[2].nil?
            related_klass = resource_klass_for(row[2])

            rid = JSONAPI::ResourceIdentity.new(related_klass, row[1])
            related_fragments[rid] ||= JSONAPI::ResourceFragment.new(rid)

            source_rid = JSONAPI::ResourceIdentity.new(self, row[0])
            related_fragments[rid].add_related_from(source_rid)

            if connect_source_identity
              related_relationship = related_klass._relationships[relationship.inverse_relationship]
              if related_relationship
                related_fragments[rid].add_related_identity(related_relationship.name, source_rid)
              end
            end

            relation_position = relation_positions[row[2].downcase.pluralize]
            model_fields = relation_position[:model_fields]
            cache_field = relation_position[:cache_field]
            cache_offset = relation_position[:cache_offset]
            field_offset = relation_position[:field_offset]

            if cache_field
              related_fragments[rid].cache = cast_to_attribute_type(row[cache_offset], cache_field[:type])
            end

            if attributes.length > 0
              model_fields.each_with_index do |k, idx|
                related_fragments[rid].add_attribute(k[0], cast_to_attribute_type(row[idx + field_offset], k[1][:type]))
              end
            end

            linkage_fields.each_with_index do |linkage_field_details, idx|
              relationship = linkage_field_details[:relationship]
              related_fragments[rid].initialize_related(relationship.name)
              related_id = row[linkage_offset + idx]
              if related_id
                related_rid = JSONAPI::ResourceIdentity.new(linkage_field_details[:resource_klass], related_id)
                related_fragments[rid].add_related_identity(relationship.name, related_rid)
              end
            end
          end
        end

        related_fragments
      end

      def find_records(records:,
                       join_tree: JoinTree.new(resource_klass: self),
                       resource_klass: self,
                       filters: nil,
                       primary_keys: nil,
                       sort_criteria: nil,
                       sort_primary: nil,
                       paginator: nil,
                       options: {})

        opts = options.dup
        records = resource_klass.apply_joins(records, join_tree, opts)

        if primary_keys
          records = records.where(_primary_key => primary_keys)
        end

        opts[:joins] = join_tree.joins

        if filters
          records = resource_klass.filter_records(records, filters, opts)
        end

        if sort_primary
          records = records.order(_primary_key => :asc)
        else
          order_options = resource_klass.construct_order_options(sort_criteria)
          records = resource_klass.sort_records(records, order_options, opts)
        end

        if paginator
          records = resource_klass.apply_pagination(records, paginator, order_options)
        end

        records
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
        joins = join_tree.joins

        joins.each_value do |join|
          case join[:join_type]
          when :inner
            records, join_alias = get_join_alias(records) { |records| records.joins(join[:relation_join_hash]) }
            join[:alias] = join_alias
          when :left
            records, join_alias = get_join_alias(records) { |records| records.joins_left(join[:relation_join_hash]) }
            join[:alias] = join_alias
          end
        end

        return records
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
          records = call_method_or_proc(strategy, records, direction, context)
        else
          joins = options[:joins] || {}

          records = records.order("#{get_aliased_field(field, joins)} #{direction}")
        end
        records
      end

      # Assumes ActiveRecord's counting. Override if you need a different counting method
      def count_records(records)
        if Rails::VERSION::MAJOR >= 5 && ActiveRecord::VERSION::MINOR >= 1
          records.count(:all)
        else
          records.count
        end
      end

      def filter_records(records, filters, options)
        if _polymorphic
          _polymorphic_resource_klasses.each do |klass|
            records = klass.apply_filters(records, filters, options)
          end
        else
          records = apply_filters(records, filters, options)
        end
        records
      end

      def construct_order_options(sort_params)
        if _polymorphic
          warn "Sorting is not supported on polymorphic relationships"
        else
          super(sort_params)
        end
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

      def get_aliased_field(path_with_field, joins)
        path = JSONAPI::Path.new(resource_klass: self, path_string: path_with_field)

        relationship = path.segments[-2]
        field = path.segments[-1]
        relationship_path = path.relationship_path_string

        if relationship
          join_name = relationship_path
          join = joins.try(:[], join_name)
          table_alias = join.try(:[], :alias)
        end

        table_alias ||= joins[''][:alias]

        concat_table_field(table_alias, field.delegated_field_name)
      end

      def apply_filter(records, filter, value, options = {})
        strategy = _allowed_filters.fetch(filter.to_sym, Hash.new)[:apply]

        if strategy
          records = call_method_or_proc(strategy, records, value, options)
        else
          joins = options[:joins] || {}
          records = records.where(get_aliased_field(filter, joins) => value)
        end

        records
      end
    end
  end
end