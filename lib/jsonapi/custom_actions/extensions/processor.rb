module JSONAPI
  class Processor
    define_jsonapi_resources_callbacks :custom_actions_instance, :custom_actions_collection

    # Processing custom actions results for model instance or other classes
    # It will handle for example: api/v1/posts/1/publish
    #
    # @return [ResourceOperationResult]
    def custom_actions_instance
      id = params[:id]
      return JSONAPI::OperationResult.new(:accepted, result_options) unless id

      key = resource_klass.verify_key(id, context)
      resource = resource_klass.find_by_key(key, custom_actions_options)
      JSONAPI::ResourceOperationResult.new(:ok, resource, result_options)
    end

    # Processing custom actions results for models collections
    # It will handle for example: api/v1/posts/remove-all
    #
    # @return [ResourceOperationResult]
    def custom_actions_collection
      resources = resource_klass.find_by_keys(params[:results], custom_actions_options)
      JSONAPI::ResourceOperationResult.new(:ok, resources, result_options)
    end

    private

    def custom_actions_options
      {
        context: context,
        fields: params[:fields],
        include_directives: params[:include_directives]
      }
    end
  end
end
