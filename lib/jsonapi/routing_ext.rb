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

        def jsonapi_resource(*resources, &_block)
          resource_type = resources.first
          options = resources.extract_options!.dup
          options[:controller] ||= resource_type
          res = jsonapi_controller(options[:controller]).resource_klass

          options.merge!(res.routing_resource_options)
          options[:path] = format_route(resource_type)

          if options[:except]
            options[:except] << :new unless options[:except].include?(:new) || options[:except].include?('new')
            options[:except] << :edit unless options[:except].include?(:edit) || options[:except].include?('edit')
          else
            options[:except] = [:new, :edit]
          end

          if res._immutable
            options[:except] << :create  unless options[:except].include?(:create)  || options[:except].include?('create')
            options[:except] << :update  unless options[:except].include?(:update)  || options[:except].include?('update')
            options[:except] << :destroy unless options[:except].include?(:destroy) || options[:except].include?('destroy')
          end

          resource resource_type, options do
            # :nocov:
            if @scope.respond_to? :[]=
              # Rails 4
              @scope[:jsonapi_controller] = options[:controller]

              if block_given?
                yield
              else
                jsonapi_relationships
              end
            else
              # Rails 5
              jsonapi_resource_scope(SingletonResource.new(resource_type, api_only?, @scope[:shallow], options)) do
                if block_given?
                  yield
                else
                  jsonapi_relationships
                end
              end
            end
            # :nocov:
          end
        end

        def jsonapi_relationships(options = {})
          res = jsonapi_controller.resource_klass
          res._relationships.each do |relationship_name, relationship|
            if relationship.is_a?(JSONAPI::Relationship::ToMany)
              jsonapi_links(relationship_name, options)
              jsonapi_related_resources(relationship_name, options)
            else
              jsonapi_link(relationship_name, options)
              jsonapi_related_resource(relationship_name, options)
            end
          end
        end

        def jsonapi_resources(*resources, &_block)
          resource_type = resources.first
          options = resources.extract_options!.dup
          options[:controller] ||= resource_type
          res = jsonapi_controller(options[:controller]).resource_klass

          options.merge!(res.routing_resource_options)

          options[:param] = :id

          options[:path] = format_route(resource_type)

          if res.resource_key_type == :uuid
            options[:constraints] ||= {}
            options[:constraints][:id] ||= /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
          end

          if options[:except]
            options[:except] = Array(options[:except])
            options[:except] << :new unless options[:except].include?(:new) || options[:except].include?('new')
            options[:except] << :edit unless options[:except].include?(:edit) || options[:except].include?('edit')
          else
            options[:except] = [:new, :edit]
          end

          if res._immutable
            options[:except] << :create  unless options[:except].include?(:create)  || options[:except].include?('create')
            options[:except] << :update  unless options[:except].include?(:update)  || options[:except].include?('update')
            options[:except] << :destroy unless options[:except].include?(:destroy) || options[:except].include?('destroy')
          end

          resources resource_type, options do
            # :nocov:
            if @scope.respond_to? :[]=
              # Rails 4
              @scope[:jsonapi_controller] = options[:controller]

              if block_given?
                yield
              else
                jsonapi_relationships
              end
            else
              # Rails 5
              jsonapi_resource_scope(Resource.new(resource_type, api_only?, @scope[:shallow], options)) do
                if block_given?
                  yield
                else
                  jsonapi_relationships
                end
              end
            end
            # :nocov:
          end
        end

        def links_methods(options)
          default_methods = [:show, :create, :destroy, :update]
          if only = options[:only]
            Array(only).map(&:to_sym)
          elsif except = options[:except]
            default_methods - Array(except)
          else
            default_methods
          end
        end

        def jsonapi_link(*links)
          link_type = links.first
          formatted_relationship_name = format_route(link_type)
          options = links.extract_options!.dup

          res = jsonapi_controller.resource_klass
          options[:controller] ||= jsonapi_default_controller

          methods = links_methods(options)

          if methods.include?(:show)
            match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                                                                  action: 'show_relationship', relationship: link_type.to_s, via: [:get]
          end

          if res.mutable?
            if methods.include?(:update)
              match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                                                                    action: 'update_relationship', relationship: link_type.to_s, via: [:put, :patch]
            end

            if methods.include?(:destroy)
              match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                                                                    action: 'destroy_relationship', relationship: link_type.to_s, via: [:delete]
            end
          end
        end

        def jsonapi_links(*links)
          link_type = links.first
          formatted_relationship_name = format_route(link_type)
          options = links.extract_options!.dup

          res = jsonapi_controller.resource_klass
          options[:controller] ||= jsonapi_default_controller

          methods = links_methods(options)

          if methods.include?(:show)
            match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                                                                  action: 'show_relationship', relationship: link_type.to_s, via: [:get]
          end

          if res.mutable?
            if methods.include?(:create)
              match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                                                                    action: 'create_relationship', relationship: link_type.to_s, via: [:post]
            end

            if methods.include?(:update)
              match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                                                                    action: 'update_relationship', relationship: link_type.to_s, via: [:put, :patch]
            end

            if methods.include?(:destroy)
              match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                                                                          action: 'destroy_relationship', relationship: link_type.to_s, via: [:delete]
            end
          end
        end

        def jsonapi_related_resource(*relationship)
          source = jsonapi_controller.resource_klass
          options = relationship.extract_options!.dup

          relationship_name = relationship.first
          relationship = source._relationships[relationship_name]

          formatted_relationship_name = format_route(relationship.name)
          options[:controller] ||= relationship.type.to_s
          source_name = source.name.underscore.sub(/_resource$/, '').pluralize

          match "#{formatted_relationship_name}", controller: options[:controller],
                                                  relationship: relationship.name, source: source_name,
                                                  action: 'get_related_resource', via: [:get]
        end

        def jsonapi_related_resources(*relationship)
          source = jsonapi_controller.resource_klass
          options = relationship.extract_options!.dup

          relationship_name = relationship.first
          relationship = source._relationships[relationship_name]

          formatted_relationship_name = format_route(relationship.name)
          options[:controller] ||= relationship.type.to_s
          source_name = source.name.underscore.sub(/_resource$/, '').pluralize

          match "#{formatted_relationship_name}", controller: options[:controller],
                                                  relationship: relationship.name, source: source_name,
                                                  action: 'get_related_resources', via: [:get]
        end

        protected
        # :nocov:
        def jsonapi_resource_scope(resource) #:nodoc:
          @scope = @scope.new(scope_level_resource: resource)

          controller(resource.resource_scope) { yield }
        ensure
          @scope = @scope.parent
        end
        # :nocov:
        private

        def jsonapi_controller(controller_name = nil)
          controller_name ||= jsonapi_default_controller
          controller_name_with_module = [@scope[:module], controller_name].compact.collect(&:to_s).join('/')
          "#{controller_name_with_module}_controller".camelize.constantize
        end

        def jsonapi_default_controller
          @scope[:jsonapi_controller] || @scope[:scope_level_resource].try!(:controller)
        end

      end
    end
  end
end
