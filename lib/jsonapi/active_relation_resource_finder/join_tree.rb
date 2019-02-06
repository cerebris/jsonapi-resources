module JSONAPI
  module ActiveRelationResourceFinder
    class JoinTree
      # Stores relationship paths starting from the resource_klass. This allows consolidation of duplicate paths from
      # relationships, filters and sorts. This enables the determination of table aliases as they are joined.

      attr_reader :resource_klass, :options, :source_relationship, :resource_joins, :joins

      def initialize(resource_klass:,
                     options: {},
                     source_relationship: nil,
                     relationships: nil,
                     filters: nil,
                     sort_criteria: nil)

        @resource_klass = resource_klass
        @options = options

        @resource_joins = {
            root: {
                join_type: :root,
                resource_klasses: {
                    resource_klass => {
                        relationships: {}
                    }
                }
            }
        }
        add_source_relationship(source_relationship)
        add_sort_criteria(sort_criteria)
        add_filters(filters)
        add_relationships(relationships)

        @joins = {}
        construct_joins(@resource_joins)
      end

      private

      def add_join(path, default_type = :inner, default_polymorphic_join_type = :left)
        if source_relationship
          if source_relationship.polymorphic?
            # Polymorphic paths will come it with the resource_type as the first part (for example `#documents.comments`)
            # We just need to prepend the relationship portion the
            sourced_path = "#{source_relationship.name}#{path}"
          else
            sourced_path = "#{source_relationship.name}.#{path}"
          end
        else
          sourced_path = path
        end

        join_tree, _field = parse_path_to_tree(sourced_path, resource_klass, default_type, default_polymorphic_join_type)

        @resource_joins[:root].deep_merge!(join_tree) { |key, val, other_val|
          if key == :join_type
            if val == other_val
              val
            else
              :inner
            end
          end
        }
      end

      def process_path_to_tree(path_parts, resource_klass, default_join_type, default_polymorphic_join_type)
        node = {
            resource_klasses: {
                resource_klass => {
                    relationships: {}
                }
            }
        }

        part = path_parts.shift

        if part.is_a?(PathPart::Relationship)
          node[:resource_klasses][resource_klass][:relationships][part.relationship] ||= {}

          # join polymorphic as left joins
          node[:resource_klasses][resource_klass][:relationships][part.relationship][:join_type] ||=
              part.relationship.polymorphic? ? default_polymorphic_join_type : default_join_type

          part.relationship.resource_types.each do |related_resource_type|
            related_resource_klass = resource_klass.resource_klass_for(related_resource_type)
            if !part.path_specified_resource_klass? || related_resource_klass == part.resource_klass
              related_resource_tree = process_path_to_tree(path_parts.dup, related_resource_klass, default_join_type, default_polymorphic_join_type)
              node[:resource_klasses][resource_klass][:relationships][part.relationship].deep_merge!(related_resource_tree)
            end
          end
        end
        node
      end

      def parse_path_to_tree(path_string, resource_klass, default_join_type = :inner, default_polymorphic_join_type = :left)
        path = JSONAPI::Path.new(resource_klass: resource_klass, path_string: path_string)
        field = path.parts[-1]
        return process_path_to_tree(path.parts, resource_klass, default_join_type, default_polymorphic_join_type), field
      end

      def add_source_relationship(source_relationship)
        @source_relationship = source_relationship

        if @source_relationship
          resource_klasses = {}
          source_relationship.resource_types.each do |related_resource_type|
            related_resource_klass = resource_klass.resource_klass_for(related_resource_type)
            resource_klasses[related_resource_klass] = {relationships: {}}
          end

          join_type = source_relationship.polymorphic? ? :left : :inner

          @resource_joins[:root][:resource_klasses][resource_klass][:relationships][@source_relationship] = {
              source: true, resource_klasses: resource_klasses, join_type: join_type
          }
        end
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

      def add_relationships(relationships)
        return if relationships.blank?
        relationships.each do |relationship|
          add_join(relationship, :left)
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
      # example posts, posts.comments and then posts.comments.author joined in that order will allow each
      # alias to be determined whereas just joining posts.comments.author will only record the author alias.
      # ToDo: Dependence on this specialized logic should be removed in the future, if possible.
      def construct_joins(node, current_relation_path = [], current_relationship_path = [])
        node.each do |relationship, relationship_details|
          join_type = relationship_details[:join_type]
          if relationship == :root
            @joins[:root] = {alias: resource_klass._table_name, join_type: :root}

            # alias to the default table unless a source_relationship is specified
            unless source_relationship
              @joins[''] = {alias: resource_klass._table_name, join_type: :root}
            end

            return construct_joins(relationship_details[:resource_klasses].values[0][:relationships],
                                   current_relation_path,
                                   current_relationship_path)
          end

          relationship_details[:resource_klasses].each do |resource_klass, resource_details|
            if relationship.polymorphic? && relationship.belongs_to?
              current_relationship_path << "#{relationship.name.to_s}##{resource_klass._type.to_s}"
              relation_name = resource_klass._type.to_s.singularize
            else
              current_relationship_path << relationship.name.to_s
              relation_name = relationship.relation_name(options).to_s
            end

            current_relation_path << relation_name

            rel_path = calc_path_string(current_relationship_path)

            @joins[rel_path] = {
                alias: nil,
                join_type: join_type,
                relation_join_hash: relation_join_hash(current_relation_path.dup)
            }

            construct_joins(resource_details[:relationships],
                            current_relation_path.dup,
                            current_relationship_path.dup)

            current_relation_path.pop
            current_relationship_path.pop
          end
        end
      end

      def calc_path_string(path_array)
        if source_relationship
          if source_relationship.polymorphic?
            _relationship_name, resource_name = path_array[0].split('#', 2)
            path = path_array.dup
            path[0] = "##{resource_name}"
          else
            path = path_array.dup.drop(1)
          end
        else
          path = path_array.dup
        end

        path.join('.')
      end
    end
  end
end