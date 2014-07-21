require 'json/api/resource_for'
require 'json/api/operation'

module JSON
  module API
    class Request
      include ResourceFor

      attr_accessor :fields, :includes, :filters, :errors, :operations

      def initialize(resource_klass, params, context = {})
        @errors = []
        @resource_klass = resource_klass
        @context = context
        @operations = []

        unless params.nil?
          case params[:action]
            when 'index'
              parse_fields(params)
              parse_includes(params)
              parse_filters(params)
            when 'show'
              parse_fields(params)
              parse_includes(params)
            when 'create'
              parse_fields(params)
              parse_includes(params)
              parse_add_operation(params)
            when 'update'
              parse_fields(params)
              parse_includes(params)
              parse_replace_operation(params)
            when 'destroy'
              parse_remove_operation(params)
            else
              return
          end
        end
      end

      def parse_fields(params)
        fields = {}

        # Extract the fields for each type from the fields parameters
        unless params[:fields].nil?
          if params[:fields].is_a?(String)
            value = params[:fields]
            resource_fields = value.split(',').map {|s| s.to_sym } unless value.nil? || value.empty?
            type = @resource_klass._serialize_as
            fields[type] = resource_fields
          elsif params[:fields].is_a?(ActionController::Parameters)
            params[:fields].each do |param, value|
              resource_fields = value.split(',').map {|s| s.to_sym } unless value.nil? || value.empty?
              type = param.to_sym
              fields[type] = resource_fields
            end
          end
        end

        # Validate the fields
        fields.each do |type, values|
          fields[type] = []
          type_resource = self.class.resource_for(type)
          if type_resource.nil? || !(@resource_klass._type == type || @resource_klass._has_association?(type))
            @errors.concat(JSON::API::Exceptions::InvalidResource.new(type).errors)
          else
            unless values.nil?
              values.each do |field|
                if type_resource._validate_field(field)
                  fields[type].push field
                else
                  @errors.concat(JSON::API::Exceptions::InvalidField.new(type, field).errors)
                end
              end
            else
              @errors.concat(JSON::API::Exceptions::InvalidField.new(type, 'nil').errors)
            end
          end
        end

        @fields = fields
      end

      def parse_includes(params)
        includes = params[:include]
        included_resources = []
        included_resources += CSV.parse_line(includes) unless includes.nil? || includes.empty?
        @includes = included_resources
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
          elsif @resource_klass._allowed_filter?(filter)
            filters[filter] = value
          else
            @errors.concat(JSON::API::Exceptions::FilterNotAllowed.new(filter).errors)
          end
        end
        @filters = filters
      end

      def parse_add_operation(params)
        object_params_raw = params.require(@resource_klass._type)

        if object_params_raw.is_a?(Array)
          object_params_raw.each do |p|
            @operations.push JSON::API::Operation.new(@resource_klass, :add, nil, '', @resource_klass.verify_params(p, :create, @context))
          end
        else
          @operations.push JSON::API::Operation.new(@resource_klass, :add, nil, '', @resource_klass.verify_params(object_params_raw, :create, @context))
        end

      rescue ActionController::ParameterMissing => e
        @errors.concat(JSON::API::Exceptions::ParameterMissing.new(e.param).errors)
      rescue JSON::API::Exceptions::Error => e
        @errors.concat(e.errors)
      end

      def parse_replace_operation(params)
        object_params_raw = params.require(@resource_klass._type)

        if object_params_raw.is_a?(Array)

          ids = params[@resource_klass._key]
          if ids.count != object_params_raw.count
            raise JSON::API::Exceptions::CountMismatch
          end

          object_params_raw.each_index do |i|
            id = ids[i]
            p = object_params_raw[i]
            @operations.push JSON::API::Operation.new(@resource_klass, :replace, id, '', @resource_klass.verify_params(p, :replace, @context))
          end
        else
          @operations.push JSON::API::Operation.new(@resource_klass, :replace, params[@resource_klass._key], '', @resource_klass.verify_params(object_params_raw, :replace, @context))
        end

      rescue ActionController::ParameterMissing => e
        @errors.concat(JSON::API::Exceptions::ParameterMissing.new(e.param).errors)
      rescue JSON::API::Exceptions::Error => e
        @errors.concat(e.errors)
      end

      def parse_remove_operation(params)
        ids = parse_id_array(params.permit(@resource_klass._key)[@resource_klass._key])

        ids.each do |id|
          @operations.push JSON::API::Operation.new(@resource_klass, :remove, id, '', '')
        end
      rescue ActionController::UnpermittedParameters => e
        @errors.concat(JSON::API::Exceptions::ParametersNotAllowed.new(e.params).errors)
      rescue JSON::API::Exceptions::Error => e
        @errors.concat(e.errors)
      end

      def parse_id_array(raw)
        ids = []
        raw.split(/,/).collect do |id|
          ids.push @resource_klass.verify_id(id)
        end
        return ids
      end
    end
  end
end
