require "json/api/resources/version"

module JSON
  module API
    module Resources
      def self.included base
        base.extend ClassMethods
      end

      module ClassMethods
        if RUBY_VERSION >= '2.0'
          def resource_for(type)
            begin
              resource_name = JSON::API::Resource._resource_name_from_type(type)
              Object.const_get resource_name if resource_name
            rescue NameError
              nil
            end
          end
        else
          def resource_for(type)
            resource_name = JSON::API::Resource._resource_name_from_type(type)
            resource_name.safe_constantize if resource_name
          end
        end
      end
    end
  end
end
