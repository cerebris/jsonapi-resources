module JSONAPI
  class LegacyResource < BasicResource
    root_resource

    # Override this on a resource to customize how the associated records
    # are fetched for a model. Particularly helpful for authorization.
    def records_for(relation_name)
      _model.public_send relation_name
    end

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
        resources_for(find_records(filters, options), options[:context])
      end

      def find_resource_id_tree(options, include_related)
        tree = PrimaryResourceIdTree.new

        resources = find(options[:filters], options)
        add_resources_to_tree(tree,
                              resources,
                              include_related)

        load_included(self, tree, include_related, options.except(:filters, :sort_criteria))

        tree
      end

      def find_related_resource_id_tree(parent_resource, relationship_name, options, include_related)
        tree = PrimaryResourceIdTree.new

        related_resources = parent_resource.send(relationship_name, options)
        related = related_resources.is_a?(Array) ? related_resources : [related_resources]
        add_resources_to_tree(tree,
                              related,
                              include_related,
                              source_relationship_name: relationship_name,
                              connect_source_identity: false)

        load_included(self, tree, include_related, options.except(:filters, :sort_criteria))

        tree
      end

      def find_resource_id_tree_from_relationship(parent_resource, relationship_name, options, include_related)
        tree = PrimaryResourceIdTree.new

        related_resources = parent_resource.send(relationship_name, options)
        related = related_resources.is_a?(Array) ? related_resources : [related_resources]
        add_resources_to_tree(tree, related, include_related, source_relationship_name: relationship_name)

        load_included(self, tree, include_related, options.except(:filters, :sort_criteria))

        tree
      end

      def load_included(resource_klass, source_resource_id_tree, include_related, options)
        # For each included relationship get related fragments
        include_related.try(:each_key) do |key|
          relationship = resource_klass._relationship(key)
          relationship_name = relationship.name.to_sym

          relationship_include_related = include_related[relationship_name][:include_related]

          tree = source_resource_id_tree.fetch_related_resource_id_tree(relationship)

          # Get related for each source relationship
          source_resource_id_tree.fragments.each do |source_rid, source_fragment|
            related_resources = source_fragment.resource.send(relationship_name)
            next unless related_resources

            related = related_resources.is_a?(Array) ? related_resources : [related_resources]

            add_resources_to_tree(tree,
                                  related,
                                  relationship_include_related,
                                  source_rid: source_rid,
                                  source_relationship_name: relationship_name,
                                  connect_source_identity: true)
          end

          # Now recursively get the related resources for the currently found resources
          load_included(relationship.resource_klass,
                        tree,
                        relationship_include_related,
                        options)
        end
      end

      # Counts Resources found using the `filters`
      #
      # @param filters [Hash] the filters hash
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [Integer] the count
      def count(filters, options = {})
        count_records(records)
      end

      # Returns the single Resource identified by `key`
      #
      # @param key the primary key of the resource to find
      # @option options [Hash] :context The context of the request, set in the controller
      def find_by_key(key, options = {})
        records = find_records({ _primary_key => key }, options.except(:paginator, :sort_criteria))
        record = records.first
        fail JSONAPI::Exceptions::RecordNotFound.new(key) if record.nil?

        resource_for(record, options[:context])
      end

      # Returns an array of Resources identified by the `keys` array
      #
      # @param keys [Array<key>] Array of primary keys to find resources for
      # @option options [Hash] :context The context of the request, set in the controller
      def find_by_keys(keys, options = {})
        records = records(options)
        records = apply_includes(records, options).where({ _primary_key => keys })
        resources_for(records, options[:context])
      end

      # Returns an array of Resources identified by the `keys` array. The resources are not filtered as this
      # will have been done in a prior step
      #
      # @param keys [Array<key>] Array of primary keys to find resources for
      # @option options [Hash] :context The context of the request, set in the controller
      def find_to_populate_by_keys(keys, options = {})
        find_by_keys(keys, options)
      end

      # Counts Resources related to the source resource through the specified relationship
      #
      # @param source_rid [ResourceIdentity] Source resource identifier
      # @param relationship_name [String | Symbol] The name of the relationship
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [Integer] the count
      def count_related(source_resource, relationship_name, options = {})
        relationship = _relationship(relationship_name)
        records = case relationship
                  when JSONAPI::Relationship::ToOne
                    source_resource.public_send("record_for_" + relationship.name)
                  when JSONAPI::Relationship::ToMany
                    source_resource.public_send("records_for_" + relationship.name)
                  end

        records = filter_records(options[:filters], options, records)

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

      # end `records` methods
      def resolve_relationship_names_to_relations(resource_klass, model_includes, options = {})
        case model_includes
        when Array
          model_includes.map do |value|
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

      def apply_includes(records, options = {})
        include_directives = options[:include_directives]
        if include_directives
          model_includes = resolve_relationship_names_to_relations(self, include_directives.model_includes, options)
          records = records.includes(model_includes) if model_includes.present?
        end

        records
      end

      def apply_pagination(records, paginator, order_options)
        records = paginator.apply(records, order_options) if paginator
        records
      end

      def apply_sort(records, order_options, _context = {})
        if order_options&.any?
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
        strategy = _allowed_filters.fetch(filter.to_sym, Hash.new)[:apply]

        if strategy
          if strategy.is_a?(Symbol) || strategy.is_a?(String)
            send(strategy, records, value, options)
          else
            strategy.call(records, value, options)
          end
        else
          records.where(filter => value)
        end
      end

      def apply_filters(records, filters, options = {})
        required_includes = []

        if filters
          filters.each do |filter, value|
            if _relationships.include?(filter)
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

      def apply_included_resources_filters(records, options = {})
        include_directives = options[:include_directives]
        return records unless include_directives
        related_directives = include_directives.include_directives.fetch(:include_related)
        related_directives.reduce(records) do |memo, (relationship_name, config)|
          relationship = _relationship(relationship_name)
          next memo unless relationship && relationship.is_a?(JSONAPI::Relationship::ToMany)
          filtering_resource = relationship.resource_klass

          # Don't try to merge where clauses when relation isn't already being joined to query.
          next memo unless config[:include_in_join]

          filters = config[:include_filters]
          next memo unless filters

          rel_records = filtering_resource.apply_filters(filtering_resource.records(options), filters, options).references(relationship_name)
          memo.merge(rel_records)
        end
      end

      def filter_records(filters, options, records = records(options))
        records = apply_filters(records, filters, options)
        records = apply_includes(records, options)
        apply_included_resources_filters(records, options)
      end

      def sort_records(records, order_options, context = {})
        apply_sort(records, order_options, context)
      end

      protected

      def to_one_relationships_for_linkage(resource_klass, include_related)
        relationships = []
        resource_klass._relationships.each do |name, relationship|
          if relationship.is_a?(JSONAPI::Relationship::ToOne) && !include_related&.has_key?(name) && relationship.include_optional_linkage_data?
            relationships << name
          end
        end
        relationships
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

      # Assumes ActiveRecord's counting. Override if you need a different counting method
      def count_records(records)
        if Rails::VERSION::MAJOR >= 5 && ActiveRecord::VERSION::MINOR >= 1
          records.count(:all)
        else
          records.count
        end
      end

      def construct_order_options(sort_params)
        if _polymorphic
          warn "Sorting is not supported on polymorphic relationships"
        else
          super(sort_params)
        end
      end

      # ResourceBuilder methods
      def define_relationship_methods(relationship_name, relationship_klass, options)
        super

        relationship = _relationship(relationship_name)

        case relationship
        when JSONAPI::Relationship::ToOne
          associated = define_resource_relationship_accessor(:one, relationship_name)
          args = [relationship, relationship.foreign_key, associated, relationship_name]

          relationship.belongs_to? ? build_belongs_to(*args) : build_has_one(*args)
        when JSONAPI::Relationship::ToMany
          associated = define_resource_relationship_accessor(:many, relationship_name)

          build_to_many(relationship, relationship.foreign_key, associated, relationship_name)
        end
      end


      def define_resource_relationship_accessor(type, relationship_name)
        associated_records_method_name = {
          one: "record_for_#{relationship_name}",
          many: "records_for_#{relationship_name}"
        }.fetch(type)

        define_on_resource associated_records_method_name do |options = {}|
          relationship = self.class._relationships[relationship_name]
          relation_name = relationship.relation_name(context: @context)
          records = self.records_for(relation_name)

          resource_klass = relationship.resource_klass

          records = resource_klass.apply_includes(records, options)

          filters = options.fetch(:filters, {})
          unless filters.nil? || filters.empty?
            records = resource_klass.apply_filters(records, filters, options)
          end

          sort_criteria = options.fetch(:sort_criteria, {})
          order_options = relationship.resource_klass.send(:construct_order_options, sort_criteria)
          records = resource_klass.apply_sort(records, order_options, @context)

          paginator = options[:paginator]
          if paginator
            records = resource_klass.apply_pagination(records, paginator, order_options)
          end

          records
        end

        associated_records_method_name
      end

      def build_belongs_to(relationship, foreign_key, associated_records_method_name, relationship_name)
        # Calls method matching foreign key name on model instance
        # define_on_resource foreign_key do
        #   @model.method(foreign_key).call
        # end

        # Returns instantiated related resource object or nil
        define_on_resource relationship_name do |options = {}|
          relationship = self.class._relationships[relationship_name]

          if relationship.polymorphic?
            associated_model = public_send(associated_records_method_name)
            resource_klass = self.class.resource_klass_for_model(associated_model) if associated_model
            return resource_klass.new(associated_model, @context) if resource_klass
          else
            resource_klass = relationship.resource_klass
            if resource_klass
              associated_model = public_send(associated_records_method_name)
              return associated_model ? resource_klass.new(associated_model, @context) : nil
            end
          end
        end
      end

      def build_has_one(relationship, foreign_key, associated_records_method_name, relationship_name)
        # Returns primary key name of related resource class
        # define_on_resource foreign_key do
        #   relationship = self.class._relationships[relationship_name]
        #
        #   record = public_send(associated_records_method_name)
        #   return nil if record.nil?
        #   record.public_send(relationship.resource_klass._primary_key)
        # end

        # Returns instantiated related resource object or nil
        define_on_resource relationship_name do |options = {}|
          relationship = self.class._relationships[relationship_name]

          if relationship.polymorphic?
            associated_model = public_send(associated_records_method_name)
            resource_klass = self.class.resource_klass_for_model(associated_model) if associated_model
            return resource_klass.new(associated_model, @context) if resource_klass && associated_model
          else
            resource_klass = relationship.resource_klass
            if resource_klass
              associated_model = public_send(associated_records_method_name)
              return associated_model ? resource_klass.new(associated_model, @context) : nil
            end
          end
        end
      end

      def build_to_many(relationship, foreign_key, associated_records_method_name, relationship_name)
        # Returns array of primary keys of related resource classes
        define_on_resource foreign_key do
          records = public_send(associated_records_method_name)
          return records.collect do |record|
            record.public_send(relationship.resource_klass._primary_key)
          end
        end

        # Returns array of instantiated related resource objects
        define_on_resource relationship_name do |options = {}|
          relationship = self.class._relationships[relationship_name]

          resource_klass = relationship.resource_klass
          records = public_send(associated_records_method_name, options)

          return records.collect do |record|
            if relationship.polymorphic?
              resource_klass = self.class.resource_klass_for_model(record)
            end
            resource_klass.new(record, @context)
          end
        end
      end

      def add_resources_to_tree(tree,
                                resources,
                                include_related,
                                source_rid: nil,
                                source_relationship_name: nil,
                                connect_source_identity: true)
        fragments = {}

        resources.each do |resource|
          next unless resource

          # fragments[resource.identity] ||= ResourceFragment.new(resource.identity, resource: resource)
          # resource_fragment = fragments[resource.identity]
          # ToDo: revert when not needed for testing
          resource_fragment = if fragments[resource.identity]
                                fragments[resource.identity]
                              else
                                fragments[resource.identity] = ResourceFragment.new(resource.identity, resource: resource)
                                fragments[resource.identity]
                              end

          if resource.class.caching?
            resource_fragment.cache = resource.cache_field_value
          end

          linkage_relationships = to_one_relationships_for_linkage(resource.class, include_related)
          linkage_relationships.each do |relationship_name|
            related_resource = resource.send(relationship_name)
            resource_fragment.add_related_identity(relationship_name, related_resource&.identity)
          end

          if source_rid && connect_source_identity
            resource_fragment.add_related_from(source_rid)
            source_klass = source_rid.resource_klass
            related_relationship_name = source_klass._relationships[source_relationship_name].inverse_relationship
            if related_relationship_name
              resource_fragment.add_related_identity(related_relationship_name, source_rid)
            end
          end
        end

        tree.add_resource_fragments(fragments, include_related)
      end
    end
  end
end
