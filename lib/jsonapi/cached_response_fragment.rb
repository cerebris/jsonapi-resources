module JSONAPI
  class CachedResponseFragment
    def self.fetch_cached_fragments(resource_klass, serializer_config_key, cache_ids, context)
      context_json = resource_klass.attribute_caching_context(context).to_json
      context_b64 = JSONAPI.configuration.resource_cache_digest_function.call(context_json)
      context_key = "ATTR-CTX-#{context_b64.gsub("/", "_")}"

      results = self.lookup(resource_klass, serializer_config_key, context, context_key, cache_ids)

      if JSONAPI.configuration.resource_cache_usage_report_function
        miss_ids = results.select{|_k,v| v.nil? }.keys
        JSONAPI.configuration.resource_cache_usage_report_function.call(
            resource_klass.name,
            cache_ids.size - miss_ids.size,
            miss_ids.size
        )
      end

      results
    end

    attr_reader :resource_klass, :id, :type, :context, :fetchable_fields, :relationships,
                :links_json, :attributes_json, :meta_json

    def initialize(resource_klass, id, type, context, fetchable_fields, relationships,
                   links_json, attributes_json, meta_json)
      @resource_klass = resource_klass
      @id = id
      @type = type
      @context = context
      @fetchable_fields = Set.new(fetchable_fields)

      # Relationships left uncompiled because we'll often want to insert included ids on retrieval
      @relationships = relationships

      @links_json = CompiledJson.of(links_json)
      @attributes_json = CompiledJson.of(attributes_json)
      @meta_json = CompiledJson.of(meta_json)
    end

    def to_cache_value
      {
        id: id,
        type: type,
        fetchable: fetchable_fields,
        rels: relationships,
        links: links_json.try(:to_s),
        attrs: attributes_json.try(:to_s),
        meta: meta_json.try(:to_s)
      }
    end

    private

    def self.lookup(resource_klass, serializer_config_key, context, context_key, cache_ids)
      type = resource_klass._type

      keys = cache_ids.map do |(id, cache_key)|
        [type, id, cache_key, serializer_config_key, context_key]
      end

      hits = JSONAPI.configuration.resource_cache.read_multi(*keys).reject{|_,v| v.nil? }
      return keys.each_with_object({}) do |key, hash|
        (_, id, _, _) = key
        if hits.has_key?(key)
          hash[id] = self.from_cache_value(resource_klass, context, hits[key])
        else
          hash[id] = nil
        end
      end
    end

    def self.from_cache_value(resource_klass, context, h)
      new(
        resource_klass,
        h.fetch(:id),
        h.fetch(:type),
        context,
        h.fetch(:fetchable),
        h.fetch(:rels, nil),
        h.fetch(:links, nil),
        h.fetch(:attrs, nil),
        h.fetch(:meta, nil)
      )
    end

    def self.write(resource_klass, resource, serializer, serializer_config_key, context, context_key, relationship_data )
      (id, cache_key) = resource.cache_id

      json = serializer.object_hash(resource, relationship_data)

      cr = self.new(
        resource_klass,
        id,
        json['type'],
        context,
        resource.fetchable_fields,
        json['relationships'],
        json['links'],
        json['attributes'],
        json['meta']
      )

      key = [resource_klass._type, id, cache_key, serializer_config_key, context_key]
      JSONAPI.configuration.resource_cache.write(key, cr.to_cache_value)
      return [id, cr]
    end

  end
end
