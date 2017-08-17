module JSONAPI
  class RequestParser
    # It setups custom_actions action for RequestParser
    #
    # @param [Hash] params Controller's action params
    # @param [Class] resource_klass class of the hitted resource
    # @return [Operation] operation instance
    def setup_custom_actions_action(params, resource_klass)
      action_resource = custom_action_resource(params[resource_klass._as_parent_key], resource_klass)
      custom_action = params.require(:custom_action)
      data = custom_action[:type] == :get ? params.except('custom_action') : transform_data(params[:data])

      action_result = resolve_custom_action(custom_action[:name], action_resource, data)

      resource_klass = result_klass(resource_klass, action_result)
      options = operation_params(resource_klass, custom_action[:includes])

      resolve_operation(action_result, resource_klass, options)
    end

    private

    def resolve_operation(action_result, resource_klass, options)
      case action_result
      when ActiveRecord::Relation, Array
        return action_operation(resource_klass, options.merge(results: action_result), false)
      when ActiveRecord::Base
        return action_operation(resource_klass, options.merge(result: action_result))
      end

      action_operation(resource_klass, result: nil, context: @context)
    end

    def transform_data(data)
      data.nil? ? {} : data.to_unsafe_h.deep_transform_keys { |key| unformat_key(key) }
    end

    def action_operation(resource_klass, options, instance = true)
      action_name = instance ? :custom_actions_instance : :custom_actions_collection
      JSONAPI::Operation.new(action_name, resource_klass, options)
    end

    def result_klass(resource_klass, result)
      return resource_klass unless result

      begin
        case result
        when ActiveRecord::Relation
          return resource_klass.resource_klass_for(result.klass.to_s)
        when ActiveRecord::Base
          return resource_klass.resource_klass_for_model(result)
        end
      rescue
        nil
      end

      resource_klass
    end

    def operation_params(resource_klass, action_includes)
      includes = request_includes(resource_klass, action_includes)

      {
        include_directives: parse_include_directives(resource_klass, includes),
        fields: parse_fields(resource_klass, params[:fields]),
        context: @context
      }
    end

    def request_includes(resource_klass, action_includes)
      if params[:include].present?
        params[:include]
      elsif action_includes == true
        includable_string(resource_klass)
      elsif action_includes.present?
        action_includes
      end
    end

    def custom_action_resource(resource_id, resource_klass)
      resource_id ? resource_klass.find_by_key(resource_id, context: @context) : resource_klass.new(nil, @context)
    end

    def resolve_custom_action(action_method, resource, data)
      result = resource.call_custom_action(action_method, data)
      return result unless result && result.try(:errors).present?

      attribute, value = result.errors.first
      raise JSONAPI::Exceptions::InvalidFieldValue.new(attribute, value)
    end

    def includable_string(resource_klass)
      resource_klass.includable_relationship_names.map { |key| format_key(key) }.join(',')
    end
  end
end
