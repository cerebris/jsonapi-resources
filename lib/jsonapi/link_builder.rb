module JSONAPI
  class LinkBuilder
    attr_reader :base_url,
                :primary_resource_klass,
                :engine,
                :routes

    def initialize(config = {})
      @base_url               = config[:base_url]
      @primary_resource_klass = config[:primary_resource_klass]
      @engine                 = build_engine

      if engine?
        @routes = @engine.routes
      else
        @routes = Rails.application.routes
      end

      # ToDo: Use NaiveCache for values. For this we need to not return nils and create composite keys which work
      # as efficient cache lookups. This could be an array of the [source.identifier, relationship] since the
      # ResourceIdentity will compare equality correctly
    end

    def engine?
      !!@engine
    end

    def primary_resources_url
      @primary_resources_url_cached ||= "#{ base_url }#{ primary_resources_path }"
    rescue NoMethodError
      warn "primary_resources_url for #{@primary_resource_klass} could not be generated" if JSONAPI.configuration.warn_on_missing_routes
    end

    def query_link(query_params)
      "#{ primary_resources_url }?#{ query_params.to_query }"
    end

    def relationships_related_link(source, relationship, query_params = {})
      if relationship.parent_resource.singleton?
        url_helper_name = singleton_related_url_helper_name(relationship)
        url = call_url_helper(url_helper_name)
      else
        url_helper_name = related_url_helper_name(relationship)
        url = call_url_helper(url_helper_name, source.id)
      end

      url = "#{ base_url }#{ url }"
      url = "#{ url }?#{ query_params.to_query }" if query_params.present?
      url
    rescue NoMethodError
      warn "related_link for #{relationship} could not be generated" if JSONAPI.configuration.warn_on_missing_routes
    end

    def relationships_self_link(source, relationship)
      if relationship.parent_resource.singleton?
        url_helper_name = singleton_relationship_self_url_helper_name(relationship)
        url = call_url_helper(url_helper_name)
      else
        url_helper_name = relationship_self_url_helper_name(relationship)
        url = call_url_helper(url_helper_name, source.id)
      end

      url = "#{ base_url }#{ url }"
      url
    rescue NoMethodError
      warn "self_link for #{relationship} could not be generated" if JSONAPI.configuration.warn_on_missing_routes
    end

    def self_link(source)
      "#{ base_url }#{ resource_path(source) }"
    rescue NoMethodError
      warn "self_link for #{source.class} could not be generated" if JSONAPI.configuration.warn_on_missing_routes
    end

    private

    def build_engine
      scopes = module_scopes_from_class(primary_resource_klass)

      begin
        unless scopes.empty?
          "#{ scopes.first.to_s.camelize }::Engine".safe_constantize
        end
      # :nocov:
      rescue LoadError => _e
        nil
      # :nocov:
      end
    end

    def call_url_helper(method, *args)
      routes.url_helpers.public_send(method, args)
    rescue NoMethodError => e
      raise e
    end

    def path_from_resource_class(klass)
      url_helper_name = resources_url_helper_name_from_class(klass)
      call_url_helper(url_helper_name)
    end

    def resource_path(source)
      url_helper_name = resource_url_helper_name_from_source(source)
      if source.class.singleton?
        call_url_helper(url_helper_name)
      else
        call_url_helper(url_helper_name, source.id)
      end
    end

    def primary_resources_path
      path_from_resource_class(primary_resource_klass)
    end

    def url_helper_name_from_parts(parts)
      (parts << "path").reject(&:blank?).join("_")
    end

    def resources_path_parts_from_class(klass)
      if engine?
        scopes = module_scopes_from_class(klass)[1..-1]
      else
        scopes = module_scopes_from_class(klass)
      end

      base_path_name = scopes.map { |scope| scope.underscore }.join("_")
      end_path_name  = klass._type.to_s
      [base_path_name, end_path_name]
    end

    def resources_url_helper_name_from_class(klass)
      url_helper_name_from_parts(resources_path_parts_from_class(klass))
    end

    def resource_path_parts_from_class(klass)
      if engine?
        scopes = module_scopes_from_class(klass)[1..-1]
      else
        scopes = module_scopes_from_class(klass)
      end

      base_path_name = scopes.map { |scope| scope.underscore }.join("_")
      end_path_name  = klass._type.to_s.singularize
      [base_path_name, end_path_name]
    end

    def resource_url_helper_name_from_source(source)
       url_helper_name_from_parts(resource_path_parts_from_class(source.class))
    end

    def related_url_helper_name(relationship)
      relationship_parts = resource_path_parts_from_class(relationship.parent_resource)
      relationship_parts << "related"
      relationship_parts << relationship.name
      url_helper_name_from_parts(relationship_parts)
    end

    def singleton_related_url_helper_name(relationship)
      relationship_parts = []
      relationship_parts << "related"
      relationship_parts << relationship.name
      relationship_parts += resource_path_parts_from_class(relationship.parent_resource)
      url_helper_name_from_parts(relationship_parts)
    end

    def relationship_self_url_helper_name(relationship)
      relationship_parts = resource_path_parts_from_class(relationship.parent_resource)
      relationship_parts << "relationships"
      relationship_parts << relationship.name
      url_helper_name_from_parts(relationship_parts)
    end

    def singleton_relationship_self_url_helper_name(relationship)
      relationship_parts = []
      relationship_parts << "relationships"
      relationship_parts << relationship.name
      relationship_parts += resource_path_parts_from_class(relationship.parent_resource)
      url_helper_name_from_parts(relationship_parts)
    end

    def module_scopes_from_class(klass)
      klass.name.to_s.split("::")[0...-1]
    end
  end
end
