module ActionDispatch
  module Routing
    class Mapper
      Resources.class_eval do
        private

        # Defining routes for instance custom actions
        def jsonapi_custom_actions
          resource_klass = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix(@resource_type))

          resource_klass._custom_actions.each_value do |custom_action|
            path = format_route(custom_action[:name])

            next unless custom_action[:level] == :instance
            match path,
                  to: "#{@resource_type}#custom_actions",
                  via: [custom_action[:type]],
                  custom_action: custom_action
          end
        end

        # Defining routes for collection custom actions
        def custom_actions_collections
          resource_klass = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix(@resource_type))

          resource_klass._custom_actions.each_value do |custom_action|
            path = format_route("#{@resource_type}/#{custom_action[:name]}")

            next unless custom_action[:level] == :collection
            match path,
                  to: "#{@resource_type}#custom_actions",
                  via: [custom_action[:type]],
                  custom_action: custom_action
          end
        end
      end
    end
  end
end
