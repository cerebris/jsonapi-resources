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
        filters = parse_filters(params)

        render json: JSON::API::ResourceSerializer.new.serialize(
            resource_klass.find({filters: filters}),
            include: include,
            fields: fields
        )
      rescue JSON::API::Errors::FilterNotAllowed => e
        filter_not_allowed(e.filter)
      rescue JSON::API::Errors::InvalidFilterValue => e
        invalid_filter_value(e.filter, e.value)
      rescue JSON::API::Errors::InvalidArgument => e
        invalid_argument(e.argument)
      rescue ActionController::UnpermittedParameters => e
        invalid_parameter(e.params)
      rescue JSON::API::Errors::InvalidField => e
        invalid_field(e.type, e.field)
      rescue JSON::API::Errors::InvalidFieldFormat
        invalid_field_format
      end

      def show
        return unless fields = parse_fields(params)
        include = params[:include]

        klass = resource_klass

        ids = parse_id_array(params[klass.key])

        resources = []
        klass.transaction do
          ids.each do |id|
            resources.push(klass.find_by_id(id))
          end
        end

        render json: JSON::API::ResourceSerializer.new.serialize(
            resources,
            include: include,
            fields: fields
        )
      rescue JSON::API::Errors::RecordNotFound => e
        record_not_found(e)
      rescue JSON::API::Errors::InvalidField => e
        invalid_field(e.type, e.field)
      rescue JSON::API::Errors::InvalidFieldFormat
        invalid_field_format
      rescue JSON::API::Errors::InvalidArgument => e
        invalid_argument(e.argument)
      end

      def create
        klass = resource_klass
        checked_params = verify_params(params, klass, klass._createable(klass._updateable_associations | klass._attributes.to_a))
        update_and_respond_with(klass.new, checked_params[0], checked_params[1])
      rescue JSON::API::Errors::ParamNotAllowed => e
        invalid_parameter(e.param)
      rescue ActionController::ParameterMissing => e
        missing_parameter(e.param)
      end

      def update
        klass = resource_klass
        checked_params = verify_params(params, klass, klass._updateable(klass._updateable_associations | klass._attributes.to_a))

        return unless obj = klass.find_by_id(params[klass.key])

        update_and_respond_with(obj, checked_params[0], checked_params[1])
      rescue JSON::API::Errors::ParamNotAllowed => e
        invalid_parameter(e.param)
      rescue ActionController::ParameterMissing => e
        missing_parameter(e.param)
      end

      def destroy
        klass = resource_klass

        ids = parse_id_array(params[klass.key])

        klass.transaction do
          ids.each do |id|
            klass.find_by_id(id).destroy
          end
        end
        render json: {}
      rescue JSON::API::Errors::RecordNotFound => e
        record_not_found(e)
      rescue JSON::API::Errors::ParamNotAllowed => e
        invalid_parameter(e.param)
      rescue ActionController::ParameterMissing => e
        missing_parameter(e.param)
      end

      private
      if RUBY_VERSION >= '2.0'
        def resource_klass
          begin
            @resource_klass ||= Object.const_get resource_klass_name
          rescue NameError
            nil
          end
        end
      else
        def resource_klass
          @resource_klass ||= resource_klass_name.safe_constantize
        end
      end

      def resource_klass_name
        @resource_klass_name ||= "#{self.class.name.demodulize.sub(/Controller$/, '').singularize}Resource"
      end

      def resource_name=(resource_klass_name)
        @resource_klass_name = resource_klass_name
      end

      def update_and_respond_with(obj, attributes, associated_sets)
        yield(obj) if block_given?
        if verify_attributes(attributes)
          obj.update(attributes)

          if verify_associated_sets(obj, associated_sets)
            associated_sets.each do |association, values|
              obj.send "#{association}=", values
            end
          end

          render json: JSON::API::ResourceSerializer.new.serialize(obj)
        end
      end

      def verify_attributes(attributes)
        true
      end

      def verify_associated_sets(obj, attributes)
        true
      end

      def verify_permitted_params(params, allowed_param_set)
        params_not_allowed = []
        params.keys.each do |key|
          param = key.to_sym
          params_not_allowed.push(param) unless allowed_param_set.include?(param)
        end
        raise JSON::API::Errors::ParamNotAllowed.new(params_not_allowed) if params_not_allowed.length > 0
      end

      def verify_params(params, klass, resource_param_set)
        object_params = params.require(klass._type)

        # push links into top level param list with attributes
        if object_params && object_params[:links]
          object_params[:links].each do |link, value|
            object_params[link] = value
          end
          object_params.delete(:links)
        end

        checked_params = {}
        checked_associations = {}

        verify_permitted_params(object_params, resource_param_set)

        object_params.each do |key, value|
          param = key.to_sym

          if klass._associations[param].is_a?(JSON::API::Association::HasOne)
            checked_params[klass._associations[param].key] = value
          elsif klass._associations[param].is_a?(JSON::API::Association::HasMany)
            checked_associations[klass._associations[param].key] = value
          else
            checked_params[param] = value
          end
        end
        return checked_params, checked_associations
      end

      def parse_filters(params)
        # Remove non-filter parameters
        # ToDo: Allow these the be set with a global setting
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

        filters = {}
        params.each do |key, value|
          filter = key.to_sym

          if resource_klass._allowed_filter?(filter)
            verified_filter = verify_filter(filter, value)
            filters[verified_filter[0]] = verified_filter[1]
          else
            raise JSON::API::Errors::FilterNotAllowed.new(filter)
          end
        end
        filters
      end

      def is_filter_association?(filter)
        filter == resource_klass.plural_model_symbol || resource_klass._associations.include?(filter)
      end

      def parse_id_array(raw)
        ids = []
        return raw.split(/,/).collect do |id|
          ids.push id
        end
        ids
      end

      def parse_fields(params)
        fields = {}

        return fields if params[:fields].nil?

        if params[:fields].is_a?(Hash)
          params[:fields].each do |type, values|
            type = type.to_sym
            fields[type] = []
            type_resource = self.class.resource_for(type)
            if type_resource.nil?
              return invalid_resource(type)
            end

            if values.respond_to?(:to_ary)
              values.each do |field|
                field = field.to_sym
                if type_resource._validate_field(field)
                  fields[type].push field
                else
                  raise JSON::API::Errors::InvalidField.new(type, field)
                end
              end

            else
              raise JSON::API::Errors::InvalidArgument.new(type)
            end
          end
        else
          raise JSON::API::Errors::InvalidFieldFormat.new
        end
        return fields
      end

      def verify_filter(filter, raw)
        if is_filter_association?(filter)
          verify_association_filter(filter, raw)
        else
          verify_custom_filter(filter, raw)
        end
      end

      # override to allow for custom filters
      def verify_custom_filter(filter, raw)
        return filter, raw
      end

      # override to allow for custom association logic, such as uuids, multiple ids or permission checks on ids
      def verify_association_filter(filter, raw)
        return resource_klass._associations[filter].primary_key, raw
      end

      def deny_access_common(status, msg)
        render(json: {error: msg}, status: status)
        return false
      end

      def record_not_found(id)
        deny_access_common(:bad_request, "Sorry - record identified by #{id} could not be found.")
      end

      def permission_denied(id)
        deny_access_common(:bad_request, "Sorry - permission denied for record identified by #{id}.")
      end

      def invalid_argument(key = 'key')
        deny_access_common(:bad_request, "Sorry - not a valid value for #{key}.")
      end

      def missing_parameter(param)
        deny_access_common(:bad_request, "Sorry - #{param} is required.")
      end

      def invalid_resource(resource = 'resource')
        deny_access_common(:bad_request, "Sorry - #{resource} is not a valid resource.")
      end

      def invalid_filter(filter)
        deny_access_common(:bad_request, "Sorry - #{filter} is not a valid filter.")
      end

      def filter_not_allowed(filter)
        deny_access_common(:bad_request, "Sorry - #{filter} is not allowed.")
      end

      def invalid_filter_value(filter, value)
        deny_access_common(:bad_request, "Sorry - #{value} is not a valid value for #{filter}.")
      end

      def invalid_field(type, field)
        deny_access_common(:bad_request, "Sorry - #{field} is not a valid field for #{type}.")
      end

      def invalid_field_format
        deny_access_common(:bad_request, "Sorry - 'fields' must contain a hash.")
      end

      def invalid_parameter(param_names = %w(unspecified))
        deny_access_common(:bad_request, "Sorry - The following parameters are not allowed here: #{param_names.join(', ')}.")
      end


    end
  end
end
