module ActionDispatch
  module Routing
    class Mapper

      Resource.class_eval do
        def unformat_route(route)
          JSONAPI.configuration.route_formatter.unformat(route.to_s)
        end

        def nested_param
          :"#{unformat_route(singular)}_#{param}"
        end
      end

      Resources.class_eval do
        def format_route(route)
          JSONAPI.configuration.route_formatter.format(route.to_s)
        end

        def jsonapi_resource(*resources, &block)
          resource_type = resources.first
          res = JSONAPI::Resource.resource_for(resource_type)

          options = resources.extract_options!.dup
          options[:controller] ||= resource_type
          options.merge!(res.routing_resource_options)

          resource format_route(resource_type), options do
            @scope[:jsonapi_resource] = resource_type

            if block_given?
              yield
            else
              res._associations.each do |association_name, association|
                if association.is_a?(JSONAPI::Association::HasMany)
                  jsonapi_links(association_name)
                else
                  jsonapi_link(association_name)
                end
              end
            end
          end
        end

        def jsonapi_resources(*resources, &block)
          resource_type = resources.first
          res = JSONAPI::Resource.resource_for(resource_type)

          options = resources.extract_options!.dup
          options[:controller] ||= resource_type
          options.merge!(res.routing_resource_options)

          # Route using the primary_key. Can be overridden using routing_resource_options
          options[:param] ||= res._primary_key

          resources format_route(resource_type), options do
            @scope[:jsonapi_resource] = resource_type
            @scope[:nested_param] = "#{format_route(resource_type.to_s.singularize)}_#{res._primary_key}"

            if block_given?
              yield
            else
              res._associations.each do |association_name, association|
                if association.is_a?(JSONAPI::Association::HasMany)
                  jsonapi_links(association_name)
                else
                  jsonapi_link(association_name)
                end
              end
            end
          end
        end

        def links_methods(options)
          default_methods = [:show, :create, :destroy, :update]
          if only = options[:only]
            Array(only).map(&:to_sym)
          elsif except = options[:except]
            default_methods - except
          else
            default_methods
          end
        end

        def jsonapi_link(*links)
          link_type = links.first
          formatted_association_name = format_route(link_type)
          options = links.extract_options!.dup

          res = JSONAPI::Resource.resource_for(@scope[:jsonapi_resource])

          methods = links_methods(options)

          if methods.include?(:show)
            match "links/#{formatted_association_name}", controller: res._type.to_s,
                  action: 'show_association', association: link_type.to_s, via: [:get]
          end

          if methods.include?(:create)
            match "links/#{formatted_association_name}", controller: res._type.to_s,
                  action: 'create_association', association: link_type.to_s, via: [:post]
          end

          if methods.include?(:update)
            match "links/#{formatted_association_name}", controller: res._type.to_s,
                  action: 'update_association', association: link_type.to_s, via: [:put]
          end

          if methods.include?(:destroy)
            match "links/#{formatted_association_name}", controller: res._type.to_s,
                  action: 'destroy_association', association: link_type.to_s, via: [:delete]
          end
        end

        def jsonapi_links(*links)
          link_type = links.first
          formatted_association_name = format_route(link_type)
          options = links.extract_options!.dup

          res = JSONAPI::Resource.resource_for(@scope[:jsonapi_resource])

          methods = links_methods(options)

          if methods.include?(:show)
            match "links/#{formatted_association_name}", controller: res._type.to_s,
                  action: 'show_association', association: link_type.to_s, via: [:get]
          end

          if methods.include?(:create)
            match "links/#{formatted_association_name}", controller: res._type.to_s,
                  action: 'create_association', association: link_type.to_s, via: [:post]
          end

          if methods.include?(:update) && res._association(link_type).acts_as_set
            match "links/#{formatted_association_name}", controller: res._type.to_s,
                  action: 'update_association', association: link_type.to_s, via: [:put]
          end

          if methods.include?(:destroy)
            match "links/#{formatted_association_name}/:keys", controller: res._type.to_s,
                  action: 'destroy_association', association: link_type.to_s, via: [:delete]
          end
        end
      end
    end
  end
end