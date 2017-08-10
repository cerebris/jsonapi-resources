module JSONAPI
  class Resource
    class << self
      attr_accessor :_custom_actions

      # It define custom action for the resource
      #
      # @param [String, Symbol] name name of the custom action
      # @param [Hash, nil] options = {} you can pass optional custom actions options
      #   @param [Symbol] type request type eg. :get, :post, :put | default: :get
      #   @param [Proc] apply Proc with custom action logic | receive: model, context, data
      #   @param [Symbol] method a name of the method with logic of custom action | default: custom action :name
      #   @param [Symbol] level a level of custom action :instance or :collection | default: :instance
      #   @param [String] includes includes for resource eg. 'user,project.owner'
      # @return [nil]
      def custom_action(name, options = {})
        @_custom_actions ||= {}

        @_custom_actions[name.to_sym] = {
          name: name,
          type: options[:type] || :get,
          apply: options[:apply],
          method: options[:method] || name,
          level: options[:level] || :instance,
          includes: options[:includes]
        }

        define_jsonapi_resources_callbacks "#{name}_action"
      end

      # @return [Array] names of available includes
      def includable_relationship_names
        _relationships.keys.map(&:to_s)
      end
    end

    define_jsonapi_resources_callbacks :custom_actions

    # It is resolving custom action logic and running callbacks for given custom action
    #
    # @param [String, Symbol] name of custom action
    # @param [Hash] data = {} params which will be passed to custom action | default: {}
    # @return result of custom action
    def call_custom_action(name, data = {})
      @custom_action = self.class._custom_actions[name]
      return unless @custom_action

      run_custom_actions_callbacks(name, @custom_action, data).tap do
        @custom_action = nil
      end
    end

    private

    def run_custom_actions_callbacks(name, custom_action, data)
      result = nil

      run_callbacks :custom_actions do
        run_callbacks "#{name}_action" do
          params = data.is_a?(ActionController::Parameters) ? data : ActionController::Parameters.new(data)
          result = _call_custom_action(custom_action, params)
        end
      end

      result
    end

    def _call_custom_action(custom_action, data)
      if custom_action[:apply]
        custom_action[:apply].call(@model, context, data)
      elsif custom_action[:method]
        send(custom_action[:method], data)
      end
    end
  end
end
