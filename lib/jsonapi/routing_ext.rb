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
          @resource_type = resources.first
          res = JSONAPI::Resource.resource_for(resource_type_with_module_prefix(@resource_type))

          options = resources.extract_options!.dup
          options[:controller] ||= @resource_type
          options.merge!(res.routing_resource_options)
          options[:path] = format_route(@resource_type)

          if options[:except]
            options[:except] << :new unless options[:except].include?(:new) || options[:except].include?('new')
            options[:except] << :edit unless options[:except].include?(:edit) || options[:except].include?('edit')
          else
            options[:except] = [:new, :edit]
          end

          resource @resource_type, options do
            @scope[:jsonapi_resource] = @resource_type

            if block_given?
              yield
            else
              jsonapi_relationships
            end
          end
        end

        def jsonapi_relationships(options = {})
          res = JSONAPI::Resource.resource_for(resource_type_with_module_prefix(@resource_type))
          res._associations.each do |association_name, association|
            if association.is_a?(JSONAPI::Association::HasMany)
              jsonapi_links(association_name, options)
              jsonapi_related_resources(association_name, options)
            else
              jsonapi_link(association_name, options)
              jsonapi_related_resource(association_name, options)
            end
          end
        end

        def jsonapi_resources(*resources, &block)
          @resource_type = resources.first
          res = JSONAPI::Resource.resource_for(resource_type_with_module_prefix(@resource_type))

          options = resources.extract_options!.dup
          options[:controller] ||= @resource_type
          options.merge!(res.routing_resource_options)

          options[:param] = :id

          options[:path] = format_route(@resource_type)

          if options[:except]
            options[:except] << :new unless options[:except].include?(:new) || options[:except].include?('new')
            options[:except] << :edit unless options[:except].include?(:edit) || options[:except].include?('edit')
          else
            options[:except] = [:new, :edit]
          end

          resources @resource_type, options do
            @scope[:jsonapi_resource] = @resource_type

            if block_given?
              yield
            else
              jsonapi_relationships
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

          res = JSONAPI::Resource.resource_for(resource_type_with_module_prefix)
          options[:controller] ||= res._type.to_s

          methods = links_methods(options)

          if methods.include?(:show)
            match "relationships/#{formatted_association_name}", controller: options[:controller],
                  action: 'show_association', association: link_type.to_s, via: [:get]
          end

          if methods.include?(:update)
            match "relationships/#{formatted_association_name}", controller: options[:controller],
                  action: 'update_association', association: link_type.to_s, via: [:put, :patch]
          end

          if methods.include?(:destroy)
            match "relationships/#{formatted_association_name}", controller: options[:controller],
                  action: 'destroy_association', association: link_type.to_s, via: [:delete]
          end
        end

        def jsonapi_links(*links)
          link_type = links.first
          formatted_association_name = format_route(link_type)
          options = links.extract_options!.dup

          res = JSONAPI::Resource.resource_for(resource_type_with_module_prefix)
          options[:controller] ||= res._type.to_s

          methods = links_methods(options)

          if methods.include?(:show)
            match "relationships/#{formatted_association_name}", controller: options[:controller],
                   action: 'show_association', association: link_type.to_s, via: [:get]
          end

          if methods.include?(:create)
            match "relationships/#{formatted_association_name}", controller: options[:controller],
                  action: 'create_association', association: link_type.to_s, via: [:post]
          end

          if methods.include?(:update)
            match "relationships/#{formatted_association_name}", controller: options[:controller],
                  action: 'update_association', association: link_type.to_s, via: [:put, :patch]
          end

          if methods.include?(:destroy)
            match "relationships/#{formatted_association_name}/:keys", controller: options[:controller],
                  action: 'destroy_association', association: link_type.to_s, via: [:delete]
          end
        end

        def jsonapi_related_resource(*association)
          source = JSONAPI::Resource.resource_for(resource_type_with_module_prefix)
          options = association.extract_options!.dup

          association_name = association.first
          association = source._associations[association_name]

          formatted_association_name = format_route(association.name)
          related_resource = JSONAPI::Resource.resource_for(resource_type_with_module_prefix(association.class_name.underscore.pluralize))
          options[:controller] ||= related_resource._type.to_s


          match "#{formatted_association_name}", controller: options[:controller],
                association: association.name, source: resource_type_with_module_prefix(source._type),
                action: 'get_related_resource', via: [:get]
        end

        def jsonapi_related_resources(*association)
          source = JSONAPI::Resource.resource_for(resource_type_with_module_prefix)
          options = association.extract_options!.dup

          association_name = association.first
          association = source._associations[association_name]

          formatted_association_name = format_route(association.name)
          related_resource = JSONAPI::Resource.resource_for(resource_type_with_module_prefix(association.class_name.underscore))
          options[:controller] ||= related_resource._type.to_s

          match "#{formatted_association_name}", controller: options[:controller],
                association: association.name, source: resource_type_with_module_prefix(source._type),
                action: 'get_related_resources', via: [:get]
        end

        private
        def resource_type_with_module_prefix(resource = nil)
          resource_name = resource || @scope[:jsonapi_resource]
          [@scope[:module], resource_name].compact.collect(&:to_s).join("/")
        end
      end
    end
  end
end
