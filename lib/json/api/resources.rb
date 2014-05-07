require "json/api/resources/version"

module JSON
  module API
    module Resources
      def self.included base
        base.extend ClassMethods
      end

      module ClassMethods
        if RUBY_VERSION >= '2.0'
          def resource_for(resource_name)
            begin
              Object.const_get "#{resource_name}Resource"
            rescue NameError
              nil
            end
          end
        else
          def resource_for(resource)
            "#{resource.class.name}Resource".safe_constantize
          end
        end
      end
    end
  end
end
