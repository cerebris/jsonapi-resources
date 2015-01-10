module JSONAPI
  module ResourceFor
    def self.included base
      base.extend ClassMethods
    end

    module ClassMethods
      # :nocov:
      if RUBY_VERSION >= '2.0'
        def resource_for(type)
          resource_name = JSONAPI::Resource._resource_name_from_type(type)
          Object.const_get(resource_name, false) if resource_name
        rescue NameError
          raise NameError, "JSONAPI: Could not find resource '#{type}'. (Class #{resource_name} not found)"
        end
      else
        def resource_for(type)
          resource_name = JSONAPI::Resource._resource_name_from_type(type)
          resource = resource_name.safe_constantize if resource_name
          if resource.nil?
            raise NameError, "JSONAPI: Could not find resource '#{type}'. (Class #{resource_name} not found)"
          end
          resource
        end
      end
      # :nocov:
    end
  end
end
