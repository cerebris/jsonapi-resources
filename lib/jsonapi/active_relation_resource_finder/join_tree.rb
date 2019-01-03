module JSONAPI
  module ActiveRelationResourceFinder
    class JoinTree
      # Stores relationship paths starting from the resource_klass. This allows consolidation of duplicate paths from
      # relationships, filters and sorts. This enables the determination of table aliases as they are joined.

      attr_reader :resource_klass, :options, :source_relationship

      def initialize(resource_klass:, options: {}, source_relationship: nil, filters: nil, sort_criteria: nil)
        @resource_klass = resource_klass
        @options = options
        @source_relationship = source_relationship

        @join_relationships = {}

        add_sort_criteria(sort_criteria)
        add_filters(filters)
      end

      # A hash of joins that can be used to create the required joins
      def get_joins
        walk_relation_node(@join_relationships)
      end

      def add_filters(filters)
        return if filters.blank?
        filters.each_key do |filter|
          # Do not add joins for filters with an apply callable. This can be overridden by setting perform_joins to true
          next if resource_klass._allowed_filters[filter].try(:[], :apply) &&
              !resource_klass._allowed_filters[filter].try(:[], :perform_joins)

          add_join(filter)
        end
      end

      def add_sort_criteria(sort_criteria)
        return if sort_criteria.blank?

        sort_criteria.each do |sort|
          add_join(sort[:field], :left)
        end
      end

      private

      def add_join_relationship(parent_joins, join_name, relation_name, type)
        parent_joins[join_name] ||= {relation_name: relation_name, relationship: {}, type: type}
        if parent_joins[join_name][:type] == :left && type == :inner
          parent_joins[join_name][:type] = :inner
        end
        parent_joins[join_name][:relationship]
      end

      def add_join(path, default_type = :inner)
        relationships, _field = resource_klass.parse_relationship_path(path)

        current_joins = @join_relationships

        terminated = false

        relationships.each do |relationship|
          if terminated
            # ToDo: Relax this, if possible
            # :nocov:
            warn "Can not nest joins under polymorphic join"
            # :nocov:
          end

          if relationship.polymorphic?
            relation_names = relationship.polymorphic_relations
            relation_names.each do |relation_name|
              join_name = "#{relationship.name}[#{relation_name}]"
              add_join_relationship(current_joins, join_name, relation_name, :left)
            end
            terminated = true
          else
            join_name = relationship.name
            current_joins = add_join_relationship(current_joins, join_name, relationship.relation_name(options), default_type)
          end
        end
      end

      # Create a nested set of hashes from an array of path components. This will be used by the `join` methods.
      # [post, comments] => { post: { comments: {} }
      def relation_join_hash(path, path_hash = {})
        relation = path.shift
        if relation
          path_hash[relation] = {}
          relation_join_hash(path, path_hash[relation])
        end
        path_hash
      end

      # Returns the paths from shortest to longest, allowing the capture of the table alias for earlier paths. For
      # example posts, posts.comments and then posts.comments.author joined in that order will alow each
      # alias to be determined whereas just joining posts.comments.author will only record the author alias.
      # ToDo: Dependence on this specialized logic should be removed in the future, if possible.
      def walk_relation_node(node, paths = {}, current_relation_path = [], current_relationship_path = [])
        node.each do |key, value|
          if current_relation_path.empty? && source_relationship
            current_relation_path << source_relationship.relation_name(options)
          end

          current_relation_path << value[:relation_name].to_s
          current_relationship_path << key.to_s

          rel_path = current_relationship_path.join('.')
          paths[rel_path] ||= {
              alias: nil,
              join_type: value[:type],
              relation_join_hash: relation_join_hash(current_relation_path.dup)
          }

          walk_relation_node(value[:relationship],
                             paths,
                             current_relation_path,
                             current_relationship_path)

          current_relation_path.pop
          current_relationship_path.pop
        end
        paths
      end
    end
  end
end
