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
          @resource_type = resources.first
          res = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix(@resource_type))

          options = resources.extract_options!.dup
          options[:controller] ||= @resource_type
          options.merge!(res.routing_resource_options)
          options[:path] = format_route(@resource_type)

          if options[:except]
            options[:except] << :new if (options[:except] & [:new, 'new']).empty?
            options[:except] << :edit if (options[:except] & [:edit, 'edit']).empty?
          else
            options[:except] = [:new, :edit]
          end

          if res._immutable
            options[:except] << :create if (options[:except] & [:create, 'create']).empty?
            options[:except] << :update if (options[:except] & [:update, 'update']).empty?
            options[:except] << :destroy if (options[:except] & [:destroy, 'destroy']).empty?
          end

          resource @resource_type, options do
            # :nocov:
            if @scope.respond_to? :[]=
              # Rails 4
              @scope[:jsonapi_resource] = @resource_type
              block_given? ? yield : jsonapi_relationships
            else
              # Rails 5
              singleton_resource = SingletonResource.new(@resource_type, api_only?, @scope[:shallow], options)
              jsonapi_resource_scope(singleton_resource, @resource_type) do
                block_given? ? yield : jsonapi_relationships
              end
            end
            # :nocov:
          end
        end

        def jsonapi_relationships(options = {})
          res = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix(@resource_type))
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
          @resource_type = resources.first
          res = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix(@resource_type))

          options = resources.extract_options!.dup
          options[:controller] ||= @resource_type
          options.merge!(res.routing_resource_options)

          options[:param] = :id

          options[:path] = format_route(@resource_type)

          if res.resource_key_type == :uuid
            options[:constraints] ||= {}
            options[:constraints][:id] ||= /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
          end

          if options[:except]
            options[:except] = Array(options[:except])
            options[:except] << :new if (options[:except] & [:new, 'new']).empty?
            options[:except] << :edit if (options[:except] & [:edit, 'edit']).empty?
          else
            options[:except] = [:new, :edit]
          end

          if res._immutable
            options[:except] << :create if (options[:except] & [:create, 'create']).empty?
            options[:except] << :update if (options[:except] & [:update, 'update']).empty?
            options[:except] << :destroy if (options[:except] & [:destroy, 'destroy']).empty?
          end

          resources @resource_type, options do
            # :nocov:
            if @scope.respond_to? :[]=
              # Rails 4
              @scope[:jsonapi_resource] = @resource_type
              block_given? ? yield : jsonapi_relationships
            else
              # Rails 5
              resource = Resource.new(@resource_type, api_only?, @scope[:shallow], options)
              jsonapi_resource_scope(resource, @resource_type) do
                block_given? ? yield : jsonapi_relationships
              end
            end
            # :nocov:
          end
        end

        def links_methods(options)
          default_methods = [:show, :create, :destroy, :update]

          if options[:only]
            Array(options[:only]).map(&:to_sym)
          elsif options[:except]
            default_methods - Array(options[:except]).map(&:to_sym)
          else
            default_methods
          end
        end

        def jsonapi_link(*links)
          link_type = links.first
          formatted_relationship_name = format_route(link_type)
          options = links.extract_options!.dup

          res = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix)
          options[:controller] ||= res._type.to_s

          methods = links_methods(options)
          route_name = "relationships/#{formatted_relationship_name}"
          route_options = { controller: options[:controller], relationship: link_type.to_s }

          match route_name, route_options.merge(action: 'show_relationship', via: [:get]) if methods.include?(:show)

          return unless res.mutable?

          if methods.include?(:update)
            match route_name, route_options.merge(action: 'update_relationship', via: [:put, :patch])
          end

          return unless methods.include?(:destroy)
          match route_name, route_options.merge(action: 'destroy_relationship', via: [:delete])
        end

        def jsonapi_links(*links)
          link_type = links.first
          formatted_relationship_name = format_route(link_type)
          options = links.extract_options!.dup

          res = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix)
          options[:controller] ||= res._type.to_s

          methods = links_methods(options)
          route_name = "relationships/#{formatted_relationship_name}"
          route_options = { controller: options[:controller], relationship: link_type.to_s }

          match route_name, route_options.merge(action: 'show_relationship', via: [:get]) if methods.include?(:show)

          return unless res.mutable?

          if methods.include?(:create)
            match route_name, route_options.merge(action: 'create_relationship', via: [:post])
          end

          if methods.include?(:update)
            match route_name, route_options.merge(action: 'update_relationship', via: [:put, :patch])
          end

          return unless methods.include?(:destroy)
          match route_name, route_options.merge(action: 'destroy_relationship', via: [:delete])
        end

        def jsonapi_related_resource(*relationship)
          source = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix)
          options = relationship.extract_options!.dup

          relationship_name = relationship.first
          relationship = source._relationships[relationship_name]

          formatted_relationship_name = format_route(relationship.name)

          if relationship.polymorphic?
            options[:controller] ||= relationship.class_name.underscore.pluralize
          else
            type_with_module = resource_type_with_module_prefix(relationship.class_name.underscore.pluralize)
            related_resource = JSONAPI::Resource.resource_klass_for(type_with_module)
            options[:controller] ||= related_resource._type.to_s
          end

          match formatted_relationship_name, controller: options[:controller],
                                             relationship: relationship.name,
                                             source: resource_type_with_module_prefix(source._type),
                                             action: 'get_related_resource', via: [:get]
        end

        def jsonapi_related_resources(*relationship)
          source = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix)
          options = relationship.extract_options!.dup

          relationship_name = relationship.first
          relationship = source._relationships[relationship_name]

          formatted_relationship_name = format_route(relationship.name)
          type_with_module = resource_type_with_module_prefix(relationship.class_name.underscore)
          related_resource = JSONAPI::Resource.resource_klass_for(type_with_module)
          options[:controller] ||= related_resource._type.to_s

          match formatted_relationship_name,
                controller: options[:controller],
                relationship: relationship.name, source: resource_type_with_module_prefix(source._type),
                action: 'get_related_resources', via: [:get]
        end

        protected

        # :nocov:
        def jsonapi_resource_scope(resource, resource_type) #:nodoc:
          @scope = @scope.new(scope_level_resource: resource, jsonapi_resource: resource_type)

          controller(resource.resource_scope) { yield }
        ensure
          @scope = @scope.parent
        end

        # :nocov:
        private

        def resource_type_with_module_prefix(resource = nil)
          resource_name = resource || @scope[:jsonapi_resource]
          [@scope[:module], resource_name].compact.collect(&:to_s).join('/')
        end
      end
    end
  end
end
