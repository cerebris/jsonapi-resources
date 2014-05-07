require 'json/api/resources'
require 'json/api/resource_serializer'
require 'action_controller'
require 'json/api/errors'

module JSON
  module API
    class ResourceController < ActionController::Base
      include Resources

      def index
        return unless fields = parse_fields(params)
        include = params[:include]
        filters = find_filters(params, resource.plural_model_symbol)

        render json: JSON::API::ResourceSerializer.new.serialize(
            resource.find({#scope: current_user,
                           filters: filters
                          }
            ),
            include: include,
            fields: fields
        )
      rescue JSON::API::Errors::InvalidArgument
        invalid_argument
      end

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

      def respond_with(*resources, &block)
        #TODO: Rails is not setting status codes properly for destroy and update actions
        if @_action_name == 'destroy'
          resources[1] ||= {}
          resources[1][:status] ||= 200
          resources[1][:location] ||= nil #Todo: look into location related to caching
        elsif @_action_name == 'update'
          resources[1] ||= {}
          resources[1][:status] ||= 200
        end
        super(*resources, &block)
      end

      # override this in the controller to apply a different set of rules
      def verify_filter_params(params)
        params.permit(*resource._allowed_filters)
      end

      def find_filters(params, plural_type)
        # Remove non-filter parameters
        params.delete(:include) if params[:include].present?
        params.delete(:fields) if params[:fields].present?
        params.delete(:format) if params[:format].present?
        params.delete(:controller) if params[:controller].present?
        params.delete(:action) if params[:action].present?
        params.delete(:sort) if params[:sort].present?

        # Coerce :ids -> :id
        if params[:ids]
          params[:id] = params[:ids]
          params.delete(:ids)
        end
        params = resource._verify_filter_params(params)
        filters = {}
        filter = nil
        params.each do |key, value|
          filter = key.to_sym
          # filters[filter] = verify_filter((filter == resource.key.to_sym ? plural_type : filter), value)
          filters[filter] = verify_filter(filter, value)
        end
        filters
      rescue ActiveRecord::RecordNotFound
        not_found(filter)
      rescue JSON::API::Errors::InvalidArgument
        invalid_argument(filter)
      rescue ActionController::UnpermittedParameters => e
        invalid_parameter(e.params)
      rescue ActionController::ParameterMissing
        missing_parameter
      end

      def is_filter_association?(filter)
        filter == resource.plural_model_symbol || resource._associations.include?(filter)
      end

      def parse_fields(params)
        fields = {}

        return fields if params[:fields].nil?

        if params[:fields].is_a?(Hash)
          params[:fields].each do |type, values|
            type = type.to_sym
            fields[type] = []
            type_resource = self.class.resource_for(type.to_s.singularize.capitalize)
            if type_resource.nil?
              return invalid_resource(type)
            end

            if values.respond_to?(:to_ary)
              values.each do |field|
                field = field.to_sym
                if type_resource._validate_field(field)
                  fields[type].push field
                else
                  return invalid_field(type, field)
                end
              end

            else
              return invalid_argument(type)
            end
          end
        else
          return invalid_argument('fields')
        end
        return fields
      end

      def verify_filter(filter, raw)
        if is_filter_association?(filter)
          # process comma-separated lists of associations
          return raw.split(/,/).collect do |value|
            key = association_key_from_filter(filter)
            if key == :currency_code
              id = value
            else
              id = to_uuid(value.strip, filter)
            end
            find_association(key, id)
          end
        else
          custom_filter_value = verify_custom_filter(filter, raw)
          if custom_filter_value.nil?
            raise JSON::API::Errors::InvalidArgument.new
          else
            return custom_filter_value
          end
        end
      end

      # override in individual controllers to allow for custom filters
      def verify_custom_filter(filter, raw)
        raw
      end

      def deny_access_common(status, msg)
        render(json: {error: msg}, status: status)
        return false
      end

      def invalid_argument(key = 'key')
        deny_access_common(:bad_request, "Sorry - not a valid value for #{key}.")
      end

      def invalid_resource(resource = 'resource')
        deny_access_common(:bad_request, "Sorry - #{resource} is not a valid resource.")
      end

      def invalid_field(resource_name, field)
        deny_access_common(:bad_request, "Sorry - #{field} is not a valid field for #{resource_name}.")
      end

      def invalid_parameter(param_names = %w(unspecified))
        deny_access_common(:bad_request, "Sorry - The following parameters are not allowed here: #{param_names.join(', ')}.")
      end


    end
  end
end
