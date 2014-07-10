require 'json/api/resource_for'
require 'json/api/resource_serializer'
require 'action_controller'
require 'json/api/exceptions'
require 'json/api/error'
require 'json/api/error_codes'
require 'json/api/request'
require 'csv'

module JSON
  module API
    class ResourceController < ActionController::Base
      include ResourceFor

      before_filter {
        @request = JSON::API::Request.new(resource_klass, params)
        render_errors(@request.errors) unless @request.errors.empty?
      }

      def index
        render json: JSON::API::ResourceSerializer.new.serialize(
            resource_klass.find({filters: verify_filters(@request.filters)}, find_options),
            {include: @request.includes,
            fields: @request.fields}.merge(serialize_options)
        )
      rescue Exception => e
        handle_json_api_error(e)
      end

      def show
        ids = parse_id_array(params[resource_klass._key])

        resources = []
        ids.each do |id|
          resources.push(resource_klass.find_by_key(id, find_options))
        end

        render json: JSON::API::ResourceSerializer.new.serialize(
            resources,
            {include: @request.includes,
             fields: @request.fields}.merge(serialize_options)
        )
      rescue Exception => e
        handle_json_api_error(e)
      end

      def create
        checked_params = verify_params(params,
                                       resource_klass,
                                       resource_klass.createable(resource_klass._updateable_associations | resource_klass._attributes.to_a))

        before_create(checked_params[0], checked_params[1])

        update_and_respond_with(resource_klass.new,
                                checked_params[0],
                                checked_params[1],
                                true,
                                {include: @request.includes,
                                 fields: @request.fields}.merge(serialize_options).merge(update_options)
        )
      rescue Exception => e
        handle_json_api_error(e)
      end

      def update
        checked_params = verify_params(params,
                                       resource_klass,
                                       resource_klass.updateable(resource_klass._updateable_associations | resource_klass._attributes.to_a))

        return unless obj = resource_klass.find_by_key(params[resource_klass._key], find_options)

        before_update(obj, checked_params[0], checked_params[1])

        update_and_respond_with(obj,
                                checked_params[0],
                                checked_params[1],
                                false,
                                {include: @request.includes,
                                 fields: @request.fields}.merge(serialize_options).merge(update_options)
        )
      rescue Exception => e
        handle_json_api_error(e)
      end

      def destroy
        ids = parse_id_array(params.permit(resource_klass._key)[resource_klass._key])

        resource_klass.transaction do
          ids.each do |id|
            obj = resource_klass.find_by_key(id, find_options)
            before_destroy(obj)
            obj.destroy
          end
        end
        render status: :no_content, json: nil
      rescue Exception => e
        handle_json_api_error(e)
      end

      private
      if RUBY_VERSION >= '2.0'
        def resource_klass
          @resource_klass ||= Object.const_get resource_klass_name
        end
      else
        def resource_klass
          @resource_klass ||= resource_klass_name.safe_constantize
        end
      end

      def resource_klass_name
        @resource_klass_name ||= "#{self.class.name.demodulize.sub(/Controller$/, '').singularize}Resource"
      end

      def update_and_respond_with(obj, attributes, associated_sets, new_record, options = {})
        yield(obj) if block_given?
        if verify_attributes(attributes)

          obj.update(attributes, options)

          if verify_associated_sets(obj, associated_sets)
            associated_sets.each do |association, values|
              obj.send "#{association}=", values
            end
          end

          render :status => :created, json: JSON::API::ResourceSerializer.new.serialize(obj, options)
        end

      rescue ActiveRecord::RecordInvalid => e
        errors = []
        e.record.errors.messages.each do |element|
          element[1].each do |message|
            errors.push(JSON::API::Error.new(
                            code: JSON::API::VALIDATION_ERROR,
                            status: :bad_request,
                            title: "#{element[0]} - #{message}",
                            detail: "can't be blank",
                            path: "\\#{element[0]}",
                            links: JSON::API::ResourceSerializer.new.serialize(obj)))
          end
        end
        raise JSON::API::Exceptions::ValidationErrors.new(errors)
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
        raise JSON::API::Exceptions::ParametersNotAllowed.new(params_not_allowed) if params_not_allowed.length > 0
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

      rescue ActionController::ParameterMissing => e
        raise JSON::API::Exceptions::ParameterMissing.new(e.param)

      end

      def verify_filters(filters)
        verified_filters = {}
        filters.each do |filter, raw_value|
          verified_filter = verify_filter(filter, raw_value)
          verified_filters[verified_filter[0]] = verified_filter[1]
        end
        verified_filters
      end

      def is_filter_association?(filter)
        filter == resource_klass._serialize_as || resource_klass._associations.include?(filter)
      end

      def parse_id_array(raw)
        ids = []
        raw.split(/,/).collect do |id|
          ids.push verify_id(resource_klass, id)
        end
        return ids
      end

      def verify_filter(filter, raw)
        filter_values = []
        filter_values += CSV.parse_line(raw) unless raw.nil? || raw.empty?

        if is_filter_association?(filter)
          verify_association_filter(filter, filter_values)
        else
          verify_custom_filter(resource_klass, filter, filter_values)
        end
      end

      # override to allow for id processing and checking
      def verify_id(resource_klass, id)
        return id
      end

      # override to allow for custom filters
      def verify_custom_filter(resource_klass, filter, values)
        return filter, values
      end

      # override to allow for custom association logic, such as uuids, multiple ids or permission checks on ids
      def verify_association_filter(filter, raw)
        return resource_klass._associations[filter].primary_key, raw
      end

      # override to set standard serializer options
      def serialize_options
        {}
      end

      # override to set standard update options
      def update_options
        {}
      end

      # override to set standard find options
      def find_options
        {}
      end

      def before_create(checked_params, checked_associations)
      end

      def before_update(obj, checked_params, checked_associations)
      end

      def before_destroy(obj)
      end

      def deny_access_common(status, msg)
        render(json: {errors: [{error: msg, status: status}]}, status: status)
        return false
      end

      def render_errors(errors, status = :bad_request)
        render(json: {errors: errors}, status: errors.count == 1 ? errors[0].status : status)
      end

      def handle_json_api_error(e)
        case e
        when ActionController::UnpermittedParameters
          handle_json_api_error(JSON::API::Exceptions::ParametersNotAllowed.new(e.params).errors)
        when ActiveRecord::DeleteRestrictionError
          handle_json_api_error(JSON::API::Exceptions::RecordLocked.new(e.message).errors)
        when ActionController::ParameterMissing
          handle_json_api_error(JSON::API::Exceptions::ParameterMissing.new(e.param).errors)
        when JSON::API::Exceptions::Error
          render_errors(e.errors)
        else
          raise e
        end
      end
    end
  end
end
