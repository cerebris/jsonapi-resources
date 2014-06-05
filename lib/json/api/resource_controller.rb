require 'json/api/resource_for'
require 'json/api/resource_serializer'
require 'action_controller'
require 'json/api/errors'
require 'csv'

module JSON
  module API
    class ResourceController < ActionController::Base
      include ResourceFor

      def index
        fields = parse_fields(params)
        include = parse_includes(params[:include])
        filters = parse_filters(params)

        render json: JSON::API::ResourceSerializer.new.serialize(
            resource_klass.find({filters: filters}),
            include: include,
            fields: fields
        )
      rescue JSON::API::Errors::Error => e
        handle_json_api_error(e)
      end

      def show
        fields = parse_fields(params)
        include = parse_includes(params[:include])

        klass = resource_klass

        ids = parse_id_array(params[klass._key])

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
      rescue JSON::API::Errors::Error => e
        handle_json_api_error(e)
      end

      def create
        fields = parse_fields(params)
        include = parse_includes(params[:include])

        klass = resource_klass
        checked_params = verify_params(params, klass, klass.createable(klass._updateable_associations | klass._attributes.to_a))
        update_and_respond_with(klass.new, checked_params[0], checked_params[1], include: include, fields: fields)
      rescue JSON::API::Errors::Error => e
        handle_json_api_error(e)
      end

      def update
        fields = parse_fields(params)
        include = parse_includes(params[:include])

        klass = resource_klass
        checked_params = verify_params(params, klass, klass.updateable(klass._updateable_associations | klass._attributes.to_a))

        return unless obj = klass.find_by_id(params[klass._key])

        update_and_respond_with(obj, checked_params[0], checked_params[1], include: include, fields: fields)
      rescue JSON::API::Errors::Error => e
        handle_json_api_error(e)
      end

      def destroy
        klass = resource_klass

        ids = parse_id_array(params[klass._key])

        klass.transaction do
          ids.each do |id|
            klass.find_by_id(id).destroy
          end
        end
        render status: :no_content, json: nil
      rescue JSON::API::Errors::Error => e
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

      def update_and_respond_with(obj, attributes, associated_sets, options = {})
        yield(obj) if block_given?
        if verify_attributes(attributes)
          obj.update(attributes)

          if verify_associated_sets(obj, associated_sets)
            associated_sets.each do |association, values|
              obj.send "#{association}=", values
            end
          end

          render :status => :created, json: JSON::API::ResourceSerializer.new.serialize(obj, options)
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

      def parse_includes(includes)
        included_resources = []
        included_resources += CSV.parse_line(includes) unless includes.nil? || includes.empty?
        included_resources
      end

      def parse_filters(params)
        # Coerce :ids -> :id
        if params[:ids]
          params[:id] = params[:ids]
          params.delete(:ids)
        end

        filters = {}
        params.each do |key, value|
          filter = key.to_sym

          if [:include, :fields, :format, :controller, :action, :sort].include?(filter)
            # Ignore non-filter parameters
          elsif resource_klass._allowed_filter?(filter)
            verified_filter = verify_filter(filter, value)
            filters[verified_filter[0]] = verified_filter[1]
          else
            raise JSON::API::Errors::FilterNotAllowed.new(filter)
          end
        end
        filters
      end

      def is_filter_association?(filter)
        filter == resource_klass._serialize_as || resource_klass._associations.include?(filter)
      end

      def parse_id_array(raw)
        ids = []
        return raw.split(/,/).collect do |id|
          ids.push verify_id(resource_klass, id)
        end
      end

      def parse_fields(params)
        fields = {}

        # Extract the fields for each type from the fields parameters
        if params[:fields].nil?
          return fields
        elsif params[:fields].is_a?(String)
          value = params[:fields]
          resource_fields = CSV.parse_line(value, { :converters => [lambda{|s|s.to_sym}]})
          type = resource_klass._serialize_as
          fields[type] = resource_fields
        elsif params[:fields].is_a?(ActionController::Parameters)
          params[:fields].each do |param, value|
            resource_fields = CSV.parse_line(value, { :converters => [lambda{|s|s.to_sym}]}) unless value.nil? || value.empty?
            type = param.to_sym
            fields[type] = resource_fields
          end
        end

        # Validate the fields
        fields.each do |type, values|
          fields[type] = []
          type_resource = self.class.resource_for(type)
          if type_resource.nil? || !(resource_klass._type == type || resource_klass._has_association?(type))
            raise JSON::API::Errors::InvalidResource.new(type)
          end

          unless values.nil?
            values.each do |field|
              if type_resource._validate_field(field)
                fields[type].push field
              else
                raise JSON::API::Errors::InvalidField.new(type, field)
              end
            end
          else
            raise JSON::API::Errors::InvalidField.new(type, 'nil')
          end
        end
        fields
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

      def deny_access_common(status, msg)
        render(json: {error: msg}, status: status)
        return false
      end

      def handle_json_api_error(e)
        case e
          when JSON::API::Errors::InvalidResource
            deny_access_common(:bad_request, "Sorry - #{e.resource} is not a valid resource.")
          when JSON::API::Errors::RecordNotFound
            deny_access_common(:bad_request, "Sorry - record identified by #{e.id} could not be found.")
          when JSON::API::Errors::FilterNotAllowed
            deny_access_common(:bad_request, "Sorry - #{e.filter} is not allowed.")
          when JSON::API::Errors::InvalidFieldValue
            deny_access_common(:bad_request, "Sorry - #{e.value} is not a valid value for #{e.field}.")
          when JSON::API::Errors::InvalidField
            deny_access_common(:bad_request, "Sorry - #{e.field} is not a valid field for #{e.type}.")
          when JSON::API::Errors::ParamNotAllowed
            deny_access_common(:bad_request, "Sorry - The following parameters are not allowed here: #{e.params.join(', ')}.")
        end
      end
    end
  end
end
