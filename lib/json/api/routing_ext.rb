module ActionDispatch
  module Routing
    class Mapper
      Resources.class_eval do
        def jsonapi_resource(*resources)
          resource_type = resources.first
          options = resources.extract_options!.dup

          res = JSON::API::Resource.resource_for(resource_type)
          resource resource_type, options.merge(res.routing_resource_options) do
            res._associations.each do |association_name, association|
              match "links/#{association_name}", controller: res._type.to_s, action: 'show_association', association: association_name.to_s, via: [:get]
              match "links/#{association_name}", controller: res._type.to_s, action: 'create_association', association: association_name.to_s, via: [:post]

              if association.is_a?(JSON::API::Association::HasMany)
                match "links/#{association_name}/:keys", controller: res._type.to_s, action: 'destroy_association', association: association_name.to_s, via: [:delete]
              else
                match "links/#{association_name}", controller: res._type.to_s, action: 'destroy_association', association: association_name.to_s, via: [:delete]
              end
            end
          end
        end

        def jsonapi_resources(*resources)
          resource_type = resources.first
          options = resources.extract_options!.dup

          res = JSON::API::Resource.resource_for(resource_type)
          resources resource_type, options.merge(res.routing_resource_options) do
            res._associations.each do |association_name, association|
              match "links/#{association_name}", controller: res._type.to_s, action: 'show_association', association: association_name.to_s, via: [:get]
              match "links/#{association_name}", controller: res._type.to_s, action: 'create_association', association: association_name.to_s, via: [:post]

              if association.is_a?(JSON::API::Association::HasMany)
                match "links/#{association_name}/:keys", controller: res._type.to_s, action: 'destroy_association', association: association_name.to_s, via: [:delete]
              else
                match "links/#{association_name}", controller: res._type.to_s, action: 'destroy_association', association: association_name.to_s, via: [:delete]
              end
            end
          end
        end

        def jsonapi_all_resources
          JSON::API::Resource._resource_types.each do |resource_type|
            jsonapi_resources(resource_type)
          end
        end
      end
    end
  end
end