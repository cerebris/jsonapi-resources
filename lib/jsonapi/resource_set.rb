module JSONAPI
  # Contains a hash of resource types which contain a hash of resources, relationships and primary status keyed by
  # resource id.
  class ResourceSet

    attr_reader :resource_klasses, :populated

    def initialize(resource_id_tree = nil)
      @populated = false
      @resource_klasses = resource_id_tree.nil? ? {} : flatten_resource_id_tree(resource_id_tree)
    end

    def populate!(serializer, context, find_options)
      # For each resource klass we want to generate the caching key

      # Hash for collecting types and ids
      # @type [Hash<Class<Resource>, Id[]]]
      missed_resource_ids = {}

      # Array for collecting CachedResponseFragment::Lookups
      # @type [Lookup[]]
      lookups = []


      # Step One collect all of the lookups for the cache, or keys that don't require cache access
      @resource_klasses.each_key do |resource_klass|

        serializer_config_key = serializer.config_key(resource_klass).gsub("/", "_")
        context_json = resource_klass.attribute_caching_context(context).to_json
        context_b64 = JSONAPI.configuration.resource_cache_digest_function.call(context_json)
        context_key = "ATTR-CTX-#{context_b64.gsub("/", "_")}"

        if resource_klass.caching?
          cache_ids = @resource_klasses[resource_klass].map do |(k, v)|
            # Store the hashcode of the cache_field to avoid storing objects and to ensure precision isn't lost
            # on timestamp types (i.e. string conversions dropping milliseconds)
            [k, resource_klass.hash_cache_field(v[:cache_id])]
          end

          lookups.push(
            CachedResponseFragment::Lookup.new(
              resource_klass,
              serializer_config_key,
              context,
              context_key,
              cache_ids
            )
          )
        else
          missed_resource_ids[resource_klass] = @resource_klasses[resource_klass].keys
        end
      end

      if lookups.any?
        raise "You've declared some Resources as caching without providing a caching store" if JSONAPI.configuration.resource_cache.nil?

        # Step Two execute the cache lookup
        found_resources = CachedResponseFragment.lookup(lookups, context)
      else
        found_resources = {}
      end


      # Step Three collect the results and collect hit/miss stats
      stats = {}
      found_resources.each do |resource_klass, resources|
        resources.each do |id, cached_resource|
          stats[resource_klass] ||= {}

          if cached_resource.nil?
            stats[resource_klass][:misses] ||= 0
            stats[resource_klass][:misses] += 1

            # Collect misses
            missed_resource_ids[resource_klass] ||= []
            missed_resource_ids[resource_klass].push(id)
          else
            stats[resource_klass][:hits] ||= 0
            stats[resource_klass][:hits] += 1

            register_resource(resource_klass, cached_resource)
          end
        end
      end

      report_stats(stats)

      writes = []

      # Step Four find any of the missing resources and join them into the result
      missed_resource_ids.each_pair do |resource_klass, ids|
        find_opts = {context: context, fields: find_options[:fields]}
        found_resources = resource_klass.find_to_populate_by_keys(ids, find_opts)

        found_resources.each do |resource|
          relationship_data = @resource_klasses[resource_klass][resource.id][:relationships]

          if resource_klass.caching?

            serializer_config_key = serializer.config_key(resource_klass).gsub("/", "_")
            context_json = resource_klass.attribute_caching_context(context).to_json
            context_b64 = JSONAPI.configuration.resource_cache_digest_function.call(context_json)
            context_key = "ATTR-CTX-#{context_b64.gsub("/", "_")}"

            writes.push(CachedResponseFragment::Write.new(
              resource_klass,
              resource,
              serializer,
              serializer_config_key,
              context,
              context_key,
              relationship_data
            ))
          end

          register_resource(resource_klass, resource)
        end
      end

      # Step Five conditionally write to the cache
      CachedResponseFragment.write(writes) unless JSONAPI.configuration.resource_cache.nil?

      mark_populated!
      self
    end

    def mark_populated!
      @populated = true
    end

    def register_resource(resource_klass, resource, primary = false)
      @resource_klasses[resource_klass] ||= {}
      @resource_klasses[resource_klass][resource.id] ||= {primary: resource.try(:primary) || primary, relationships: {}}
      @resource_klasses[resource_klass][resource.id][:resource] = resource
    end

    private

    def report_stats(stats)
      return unless JSONAPI.configuration.resource_cache_usage_report_function || JSONAPI.configuration.resource_cache.nil?

      stats.each_pair do |resource_klass, stat|
        JSONAPI.configuration.resource_cache_usage_report_function.call(
          resource_klass.name,
          stat[:hits] || 0,
          stat[:misses] || 0
        )
      end
    end

    def flatten_resource_id_tree(resource_id_tree, flattened_tree = {})
      resource_id_tree.fragments.each_pair do |resource_rid, fragment|

        resource_klass = resource_rid.resource_klass
        id = resource_rid.id
        custom_id = resource_rid.custom_id
        

        flattened_tree[resource_klass] ||= {}

        if custom_id
          flattened_tree[resource_klass][custom_id] ||= {primary: fragment.primary, relationships: {}}
          flattened_tree[resource_klass][custom_id][:cache_id] ||= fragment.custom_cache
        else
          flattened_tree[resource_klass][id] ||= {primary: fragment.primary, relationships: {}}
          flattened_tree[resource_klass][id][:cache_id] ||= fragment.cache
        end

        fragment.related.try(:each_pair) do |relationship_name, related_rids|
          final_key = custom_id ? custom_id : id
          flattened_tree[resource_klass][final_key][:relationships][relationship_name] ||= Set.new
          flattened_tree[resource_klass][final_key][:relationships][relationship_name].merge(related_rids)
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
