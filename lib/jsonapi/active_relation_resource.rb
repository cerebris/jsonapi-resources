module JSONAPI
  class ActiveRelationResource < BasicResource
    root_resource

    class << self
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

        join_manager = ActiveRelation::JoinManager.new(resource_klass: self,
                                                       filters: filters,
                                                       sort_criteria: sort_criteria)

        paginator = options[:paginator]

        records = apply_request_settings_to_records(records: records(options),
                               sort_criteria: sort_criteria,filters: filters,
                               join_manager: join_manager,
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
        join_manager = ActiveRelation::JoinManager.new(resource_klass: self,
                                                       filters: filters)

        records = apply_request_settings_to_records(records: records(options),
                               filters: filters,
                               join_manager: join_manager,
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

      # Returns an array of Resources identified by the `keys` array. The resources are not filtered as this
      # will have been done in a prior step
      #
      # @param keys [Array<key>] Array of primary keys to find resources for
      # @option options [Hash] :context The context of the request, set in the controller
      def find_to_populate_by_keys(keys, options = {})
        records = 
          if resource_key_type == :id
            records_for_populate(options).where(_primary_key => keys)
          else
            records_for_populate(options).where(resource_key_type => keys)
          end
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

        join_manager = ActiveRelation::JoinManager.new(resource_klass: resource_klass,
                                                       source_relationship: nil,
                                                       relationships: linkage_relationships,
                                                       sort_criteria: sort_criteria,
                                                       filters: filters)

        paginator = options[:paginator]

        records = apply_request_settings_to_records(records: records(options),
                               filters: filters,
                               sort_criteria: sort_criteria,
                               paginator: paginator,
                               join_manager: join_manager,
                               options: options)

        # This alias is going to be resolve down to the model's table name and will not actually be an alias
        resource_table_alias = resource_klass._table_name

        pluck_fields = [Arel.sql("#{concat_table_field(resource_table_alias, resource_klass._primary_key)} AS #{resource_table_alias}_#{resource_klass._primary_key}")]
        
        if resource_klass.resource_key_type != :id
          pluck_fields << Arel.sql("#{concat_table_field(resource_table_alias, resource_klass.resource_key_type)} AS #{resource_table_alias}_#{resource_klass.resource_key_type}")
        end

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

              linkage_table_alias = join_manager.join_details_by_polymorphic_relationship(linkage_relationship, resource_type)[:alias]
              primary_key = klass._primary_key
              # TODO: maybe an update here too for `custom` key?
              pluck_fields << Arel.sql("#{concat_table_field(linkage_table_alias, primary_key)} AS #{linkage_table_alias}_#{primary_key}")
            end
          else
            klass = linkage_relationship.resource_klass
            linkage_fields << {relationship_name: name, resource_klass: klass}

            linkage_table_alias = join_manager.join_details_by_relationship(linkage_relationship)[:alias]
            primary_key = klass._primary_key
            # TODO: maybe an update here too for `custom` key?
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

        sort_fields = options.dig(:_relation_helper_options, :sort_fields)
        sort_fields.try(:each) do |field|
          pluck_fields << Arel.sql(field)
        end

        fragments = {}
        rows = records.pluck(*pluck_fields)
        rows.each do |row|
          nb_ids = resource_klass.resource_key_type == 'id' ? 1 : 2
          rid = JSONAPI::ResourceIdentity.new(resource_klass, *row.first(nb_ids))

          fragments[rid] ||= JSONAPI::ResourceFragment.new(rid)
          attributes_offset = 1

          if cache_field
            fragments[rid].cache = cast_to_attribute_type(row[1], cache_field[:type])
            unless resource_klass.resource_key_type == 'id'
              fragments[rid].custom_cache = cast_to_attribute_type(row[2], cache_field[:type])
              attributes_offset+= 1
            end
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

        if JSONAPI.configuration.warn_on_performance_issues && (rows.length > fragments.length)
          warn "Performance issue detected: `#{self.name.to_s}.records` returned non-normalized results in `#{self.name.to_s}.find_fragments`."
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
        join_manager = ActiveRelation::JoinManager.new(resource_klass: self,
                                                       source_relationship: relationship,
                                                       filters: filters)

        records = apply_request_settings_to_records(records: records(options),
                               resource_klass: related_klass,
                               primary_keys: source_rid.id,
                               custom_primary_keys: source_rids.custom_id,
                               join_manager: join_manager,
                               filters: filters,
                               options: options)

        related_alias = join_manager.join_details_by_relationship(relationship)[:alias]

        records =
          if resource_klass.resource_key_type != 'id'
            records.select(Arel.sql("#{concat_table_field(related_alias, related_klass.resource_key_type)}"))
          else
            records.select(Arel.sql("#{concat_table_field(related_alias, related_klass._primary_key)}"))
          end
         

        count_records(records)
      end

      # This resource class (ActiveRelationResource) uses an `ActiveRecord::Relation` as the starting point for
      # retrieving models. From this relation filters, sorts and joins are applied as needed.
      # Depending on which phase of the request processing different `records` methods will be called, giving the user
      # the opportunity to override them differently for performance and security reasons.

      # begin `records`methods

      # Base for the `records` methods that follow and is not directly used for accessing model data by this class.
      # Overriding this method gives a single place to affect the `ActiveRecord::Relation` used for the resource.
      #
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [ActiveRecord::Relation]
      def records_base(_options = {})
        _model_class.all
      end

      # The `ActiveRecord::Relation` used for finding user requested models. This may be overridden to enforce
      # permissions checks on the request.
      #
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [ActiveRecord::Relation]
      def records(options = {})
        records_base(options)
      end

      # The `ActiveRecord::Relation` used for populating the ResourceSet. Only resources that have been previously
      # identified through the `records` method will be accessed. Thus it should not be necessary to reapply permissions
      # checks. However if the model needs to include other models adding `includes` is appropriate
      #
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [ActiveRecord::Relation]
      def records_for_populate(options = {})
        records_base(options)
      end

      # The `ActiveRecord::Relation` used for the finding related resources. Only resources that have been previously
      # identified through the `records` method will be accessed and used as the basis to find related resources. Thus
      # it should not be necessary to reapply permissions checks.
      #
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [ActiveRecord::Relation]
      def records_for_source_to_related(options = {})
        records_base(options)
      end

      # end `records` methods

      def apply_join(records:, relationship:, resource_type:, join_type:, options:)
        if relationship.polymorphic? && relationship.belongs_to?
          case join_type
          when :inner
            records = records.joins(resource_type.to_s.singularize.to_sym)
          when :left
            records = records.joins_left(resource_type.to_s.singularize.to_sym)
          end
        else
          relation_name = relationship.relation_name(options)
          case join_type
          when :inner
            records = records.joins(relation_name)
          when :left
            records = records.joins_left(relation_name)
          end
        end
        records
      end

      def relationship_records(relationship:, join_type: :inner, resource_type: nil, options: {})
        records = relationship.parent_resource.records_for_source_to_related(options)
        strategy = relationship.options[:apply_join]

        if strategy
          records = call_method_or_proc(strategy, records, relationship, resource_type, join_type, options)
        else
          records = apply_join(records: records,
                               relationship: relationship,
                               resource_type: resource_type,
                               join_type: join_type,
                               options: options)
        end

        records
      end

      def join_relationship(records:, relationship:, resource_type: nil, join_type: :inner, options: {})
        relationship_records = relationship_records(relationship: relationship,
                                                    join_type: join_type,
                                                    resource_type: resource_type,
                                                    options: options)
        records.merge(relationship_records)
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
        custom_key = nil
        if resource_key_type != 'id'
          custom_key = key
          key = nil
        end
        record = apply_request_settings_to_records(records: records(options), primary_keys: key, custom_primary_keys: custom_key, options: options).first
        fail JSONAPI::Exceptions::RecordNotFound.new(key) if record.nil?
        record
      end

      def find_records_by_keys(keys, options = {})
        apply_request_settings_to_records(records: records(options), primary_keys: keys, options: options)
      end

      def find_related_monomorphic_fragments(source_rids, relationship, options, connect_source_identity)
        filters = options.fetch(:filters, {})
        source_ids = source_rids.collect {|rid| rid.id}
        custom_source_ids = source_rids.collect {|rid| rid.custom_id}

        include_directives = options[:include_directives] ? options[:include_directives].include_directives : {}
        resource_klass = relationship.resource_klass
        linkage_relationships = resource_klass.to_one_relationships_for_linkage(include_directives[:include_related])

        sort_criteria = []
        options[:sort_criteria].try(:each) do |sort|
          field = sort[:field].to_s == 'id' ? resource_klass._primary_key : sort[:field]
          sort_criteria << { field: field, direction: sort[:direction] }
        end

        join_manager = ActiveRelation::JoinManager.new(resource_klass: self,
                                                       source_relationship: relationship,
                                                       relationships: linkage_relationships,
                                                       sort_criteria: sort_criteria,
                                                       filters: filters)

        paginator = options[:paginator]

        records = apply_request_settings_to_records(records: records_for_source_to_related(options),
                               resource_klass: resource_klass,
                               sort_criteria: sort_criteria,
                               primary_keys: source_ids,
                               custom_primary_keys: custom_source_ids,
                               paginator: paginator,
                               filters: filters,
                               join_manager: join_manager,
                               options: options)
        resource_table_alias = join_manager.join_details_by_relationship(relationship)[:alias]

        pluck_fields = [Arel.sql("#{_table_name}.#{_primary_key} AS source_id")]
        if resource_key_type != 'id'
          custom_primary_key = concat_table_field(_table_name, resource_key_type)
          pluck_fields << Arel.sql("#{custom_primary_key} AS #{_table_name}_#{resource_key_type}")
        end
        pluck_fields << Arel.sql("#{concat_table_field(resource_table_alias, resource_klass._primary_key)} AS #{resource_table_alias}_#{resource_klass._primary_key}")
        if resource_klass.resource_key_type != 'id'
          custom_resource_primary_key = concat_table_field(resource_table_alias, resource_klass.resource_key_type)
          pluck_fields << Arel.sql("#{custom_resource_primary_key} AS #{resource_table_alias}_#{resource_klass.resource_key_type}")
        end
        # TODO: maybe an update here too for `custom` key?

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

              linkage_table_alias = join_manager.join_details_by_polymorphic_relationship(linkage_relationship, resource_type)[:alias]
              primary_key = klass._primary_key
              # TODO: maybe an update here too for `custom` key?
              pluck_fields << Arel.sql("#{concat_table_field(linkage_table_alias, primary_key)} AS #{linkage_table_alias}_#{primary_key}")
            end
          else
            klass = linkage_relationship.resource_klass
            linkage_fields << {relationship_name: name, resource_klass: klass}

            linkage_table_alias = join_manager.join_details_by_relationship(linkage_relationship)[:alias]
            primary_key = klass._primary_key
            # TODO: maybe an update here too for `custom` key?
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

        sort_fields = options.dig(:_relation_helper_options, :sort_fields)
        sort_fields.try(:each) do |field|
          pluck_fields << Arel.sql(field)
        end

        fragments = {}
        rows = records.distinct.pluck(*pluck_fields)
        rows.each do |row|
          field_offset = 1
          field_offset += 1 if resource_key_type != 'id'
          nb_after_offset = resource_klass.resource_key_type == 'id' ? 1 : 2
          rid = JSONAPI::ResourceIdentity.new(resource_klass, *row[field_offset, nb_after_offset])

          fragments[rid] ||= JSONAPI::ResourceFragment.new(rid)

          attributes_offset = field_offset + nb_after_offset

          if cache_field
            fragments[rid].cache = cast_to_attribute_type(row[attributes_offset], cache_field[:type])
            attributes_offset+= 1
          end

          model_fields.each_with_index do |k, idx|
            fragments[rid].add_attribute(k[0], cast_to_attribute_type(row[idx + attributes_offset], k[1][:type]))
            attributes_offset+= 1
          end

          source_rid = JSONAPI::ResourceIdentity.new(self, *row.first(nb_after_offset))
          
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
        custom_source_ids = source_rids.collect {|rid| rid.custom_id}

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

        join_manager = ActiveRelation::JoinManager.new(resource_klass: self,
                                                       source_relationship: relationship,
                                                       relationships: linkage_relationships,
                                                       filters: filters)

        paginator = options[:paginator]

        # Note: We will sort by the source table. Without using unions we can't sort on a polymorphic relationship
        # in any manner that makes sense
        records = apply_request_settings_to_records(records: records_for_source_to_related(options),
                               resource_klass: resource_klass,
                               sort_primary: true,
                               primary_keys: source_ids,
                               custom_primary_keys: custom_source_ids,
                               paginator: paginator,
                               filters: filters,
                               join_manager: join_manager,
                               options: options)

        primary_key = concat_table_field(_table_name, _primary_key)
        related_key = concat_table_field(_table_name, relationship.foreign_key)
        related_type = concat_table_field(_table_name, relationship.polymorphic_type)

        pluck_fields = [Arel.sql("#{primary_key} AS #{_table_name}_#{_primary_key}")]
        if resource_klass.resource_key_type != 'id'
          custom_primary_key = concat_table_field(_table_name, resource_key_type)
          pluck_fields << Arel.sql("#{custom_primary_key} AS #{_table_name}_#{resource_key_type}")
        end
        pluck_fields << Arel.sql("#{related_key} AS #{_table_name}_#{relationship.foreign_key}")
        pluck_fields << Arel.sql("#{related_type} AS #{_table_name}_#{relationship.polymorphic_type}")

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

            table_alias = join_manager.source_join_details(type)[:alias]

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

              linkage_table_alias = join_manager.join_details_by_polymorphic_relationship(linkage_relationship, resource_type)[:alias]
              primary_key = klass._primary_key
              # TODO: maybe an update here too for `custom` key?
              pluck_fields << Arel.sql("#{concat_table_field(linkage_table_alias, primary_key)} AS #{linkage_table_alias}_#{primary_key}")
            end
          else
            klass = linkage_relationship.resource_klass
            linkage_fields << {relationship: linkage_relationship, resource_klass: klass}

            linkage_table_alias = join_manager.join_details_by_relationship(linkage_relationship)[:alias]
            primary_key = klass._primary_key
            pluck_fields << Arel.sql("#{concat_table_field(linkage_table_alias, primary_key)} AS #{linkage_table_alias}_#{primary_key}")
          end
        end

        rows = records.distinct.pluck(*pluck_fields)

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

      def apply_request_settings_to_records(records:,
                                            join_manager: ActiveRelation::JoinManager.new(resource_klass: self),
                                            resource_klass: self,
                                            filters: {},
                                            primary_keys: nil,
                                            custom_primary_keys: nil,
                                            sort_criteria: nil,
                                            sort_primary: nil,
                                            paginator: nil,
                                            options: {})

        options[:_relation_helper_options] = { join_manager: join_manager, sort_fields: [] }

        records = resource_klass.apply_joins(records, join_manager, options)

        if primary_keys
          records = records.where(_primary_key => primary_keys)
        elsif custom_primary_keys
          records = records.where(resource_key_type => custom_primary_keys)
        end


        unless filters.empty?
          records = resource_klass.filter_records(records, filters, options)
        end

        if sort_primary
          records = records.order(_primary_key => :asc)
        else
          order_options = resource_klass.construct_order_options(sort_criteria)
          records = resource_klass.sort_records(records, order_options, options)
        end

        if paginator
          records = resource_klass.apply_pagination(records, paginator, order_options)
        end

        records
      end

      def apply_joins(records, join_manager, options)
        join_manager.join(records, options)
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

        options[:_relation_helper_options] ||= {}
        options[:_relation_helper_options][:sort_fields] ||= []

        if strategy
          records = call_method_or_proc(strategy, records, direction, context)
        else
          join_manager = options.dig(:_relation_helper_options, :join_manager)
          sort_field = join_manager ? get_aliased_field(field, join_manager) : field
          options[:_relation_helper_options][:sort_fields].push("#{sort_field}")
          records = records.order(Arel.sql("#{sort_field} #{direction}"))
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

      def get_aliased_field(path_with_field, join_manager)
        path = JSONAPI::Path.new(resource_klass: self, path_string: path_with_field)

        relationship_segment = path.segments[-2]
        field_segment = path.segments[-1]

        if relationship_segment
          join_details = join_manager.join_details[path.last_relationship]
          table_alias = join_details[:alias]
        else
          table_alias = self._table_name
        end

        concat_table_field(table_alias, field_segment.delegated_field_name)
      end

      def apply_filter(records, filter, value, options = {})
        strategy = _allowed_filters.fetch(filter.to_sym, Hash.new)[:apply]

        if strategy
          records = call_method_or_proc(strategy, records, value, options)
        else
          join_manager = options.dig(:_relation_helper_options, :join_manager)
          field = join_manager ? get_aliased_field(filter, join_manager) : filter
          records = records.where(Arel.sql(field) => value)
        end

        records
      end
    end
  end
end
