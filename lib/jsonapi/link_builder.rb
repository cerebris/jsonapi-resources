module JSONAPI
  class LinkBuilder
    attr_reader :base_url,
                :primary_resource_klass,
                :route_formatter

    def initialize(config = {})
      @base_url               = config[:base_url]
      @primary_resource_klass = config[:primary_resource_klass]
      @route_formatter        = config[:route_formatter]
      @is_engine              = !!engine_name
    end

    def engine?
      @is_engine
    end

    def engine_name
      @engine_name ||= build_engine_name
    end

    def primary_resources_url
      if engine?
        engine_primary_resources_url
      else
        regular_primary_resources_url
      end
    end

    def query_link(query_params)
      "#{ primary_resources_url }?#{ query_params.to_query }"
    end

    def relationships_related_link(source, relationship, query_params = {})
      url = "#{ self_link(source) }/#{ route_for_relationship(relationship) }"
      url = "#{ url }?#{ query_params.to_query }" if query_params.present?
      url
    end

    def relationships_self_link(source, relationship)
      "#{ self_link(source) }/relationships/#{ route_for_relationship(relationship) }"
    end

    def self_link(source)
      if engine?
        engine_resource_url(source)
      else
        regular_resource_url(source)
      end
    end

    private

    def build_engine_name
      scopes = module_scopes_from_class(primary_resource_klass)

      unless scopes.empty?
        "#{ scopes.first.to_s.camelize }::Engine".safe_constantize
      end
    end

    def engine_path_from_resource_class(klass)
      path_name = engine_resources_path_name_from_class(klass)
      engine_name.routes.url_helpers.public_send(path_name)
    end

    def engine_primary_resources_path
      engine_path_from_resource_class(primary_resource_klass)
    end

    def engine_primary_resources_url
      "#{ base_url }#{ engine_primary_resources_path }"
    end

    def engine_resource_path(source)
      resource_path_name = engine_resource_path_name_from_source(source)
      engine_name.routes.url_helpers.public_send(resource_path_name, source.id)
    end

    def engine_resource_path_name_from_source(source)
      scopes         = module_scopes_from_class(source.class)[1..-1]
      base_path_name = scopes.map { |scope| scope.underscore }.join("_")
      end_path_name  = source.class._type.to_s.singularize
      [base_path_name, end_path_name, "path"].reject(&:blank?).join("_")
    end

    def engine_resource_url(source)
      "#{ base_url }#{ engine_resource_path(source) }"
    end

    def engine_resources_path_name_from_class(klass)
      scopes         = module_scopes_from_class(klass)[1..-1]
      base_path_name = scopes.map { |scope| scope.underscore }.join("_")
      end_path_name  = klass._type.to_s
      "#{ base_path_name }_#{ end_path_name }_path"
    end

    def format_route(route)
      route_formatter.format(route.to_s)
    end

    def formatted_module_path_from_class(klass)
      scopes = module_scopes_from_class(klass)

      unless scopes.empty?
        "/#{ scopes.map(&:underscore).join('/') }/"
      else
        "/"
      end
    end

    def module_scopes_from_class(klass)
      klass.name.to_s.split("::")[0...-1]
    end

    def regular_primary_resources_path
      [
        formatted_module_path_from_class(primary_resource_klass),
        route_formatter.format(primary_resource_klass._type.to_s),
      ].join
    end

    def regular_primary_resources_url
      "#{ base_url }#{ regular_primary_resources_path }"
    end

    def regular_resource_path(source)
      [
        formatted_module_path_from_class(source.class),
        route_formatter.format(source.class._type.to_s),
        "/#{ source.id }",
      ].join
    end

    def regular_resource_url(source)
      "#{ base_url }#{ regular_resource_path(source) }"
    end

    def route_for_relationship(relationship)
      format_route(relationship.name)
    end
  end
end
