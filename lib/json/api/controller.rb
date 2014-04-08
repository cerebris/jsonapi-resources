require 'action_controller'

module JSON
  module API
    class Controller < ActionController::Base

      private
        if RUBY_VERSION >= '2.0'
          def resource
            begin
              @resource ||= Object.const_get resource_name
            rescue NameError
              nil
            end
          end
        else
          def resource
            @resource ||= resource_name.safe_constantize
          end
        end

        def resource_name
          @resource_name ||= "#{self.class.name.demodulize.sub(/Controller$/, '').singularize}Resource"
        end

        def resource_name=(resource)
          @resource_name = resource
        end
    end
  end
end
