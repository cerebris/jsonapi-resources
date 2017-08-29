module JSONAPI
  class Processor
    define_jsonapi_resources_callbacks :custom_actions_instance, :custom_actions_collection

    # Processing custom actions results for single model
    # It will handle action result if returns one single model
    #
    # @return [ResourceOperationResult]
    def custom_actions_instance
      resource = resource_klass.resource_for(params[:result], context)
      JSONAPI::ResourceOperationResult.new(:ok, resource, result_options)
    rescue
      JSONAPI::OperationResult.new(:accepted, result_options)
    end

    # Processing custom actions results for many models
    # It will handle action result if returns array or ActiveRecord::Relation
    #
    # @return [ResourcesOperationResult]
    def custom_actions_collection
      resources = resource_klass.resources_for(params[:results], context)
      JSONAPI::ResourcesOperationResult.new(:ok, resources, result_options)
    end
  end
end
