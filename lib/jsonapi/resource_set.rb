module JSONAPI
  # Contains a hash of resource types which contain a hash of resources, relationships and primary status keyed by
  # resource id.
  class ResourceSet

    attr_reader :resource_klasses, :populated

    def initialize(resource_id_tree)
      @populated = false
      @resource_klasses = flatten_resource_id_tree(resource_id_tree)
    end

    def populate!(serializer, context, find_options)
      @resource_klasses.each_key do |resource_klass|
        missed_ids = []

        serializer_config_key = serializer.config_key(resource_klass).gsub("/", "_")
        context_json = resource_klass.attribute_caching_context(context).to_json
        context_b64 = JSONAPI.configuration.resource_cache_digest_function.call(context_json)
        context_key = "ATTR-CTX-#{context_b64.gsub("/", "_")}"

        if resource_klass.caching?
          cache_ids = []

          @resource_klasses[resource_klass].each_pair do |k, v|
            # Store the hashcode of the cache_field to avoid storing objects and to ensure precision isn't lost
            # on timestamp types (i.e. string conversions dropping milliseconds)
            cache_ids.push([k, resource_klass.hash_cache_field(v[:cache_id])])
          end

          found_resources = CachedResponseFragment.fetch_cached_fragments(
              resource_klass,
              serializer_config_key,
              cache_ids,
              context)

          found_resources.each do |found_result|
            resource = found_result[1]
            if resource.nil?
              missed_ids.push(found_result[0])
            else
              @resource_klasses[resource_klass][resource.id][:resource] = resource
            end
          end
        else
          missed_ids = @resource_klasses[resource_klass].keys
        end

        # fill in any missed resources
        unless missed_ids.empty?
          filters = {resource_klass._primary_key => missed_ids}
          find_opts = {
              context: context,
              fields: find_options[:fields] }

          found_resources = resource_klass.find(filters, find_opts)

          found_resources.each do |resource|
            relationship_data = @resource_klasses[resource_klass][resource.id][:relationships]

            if resource_klass.caching?
              (id, cr) = CachedResponseFragment.write(
                  resource_klass,
                  resource,
                  serializer,
                  serializer_config_key,
                  context,
                  context_key,
                  relationship_data)

              @resource_klasses[resource_klass][id][:resource] = cr
            else
              @resource_klasses[resource_klass][resource.id][:resource] = resource
            end
          end
        end
      end
      @populated = true
      self
    end

    private
    def flatten_resource_id_tree(resource_id_tree, flattened_tree = {})
      resource_id_tree.fragments.each_pair do |resource_rid, fragment|

        resource_klass = resource_rid.resource_klass
        id = resource_rid.id

        flattened_tree[resource_klass] ||= {}

        flattened_tree[resource_klass][id] ||= { primary: fragment.primary, relationships: {} }
        flattened_tree[resource_klass][id][:cache_id] ||= fragment.cache

        fragment.related.try(:each_pair) do |relationship_name, related_rids|
          flattened_tree[resource_klass][id][:relationships][relationship_name] ||= Set.new
          flattened_tree[resource_klass][id][:relationships][relationship_name].merge(related_rids)
        end
      end

      related_resource_id_trees = resource_id_tree.related_resource_id_trees
      related_resource_id_trees.try(:each_value) do |related_resource_id_tree|
        flatten_resource_id_tree(related_resource_id_tree, flattened_tree)
      end

      flattened_tree
    end
  end
end