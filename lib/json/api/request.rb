require 'json/api/resource_for'

module JSON
  module API
    class Request
      include ResourceFor

      attr_accessor :fields, :includes, :filters, :errors

      def initialize(resource_klass, params)
        @errors = []
        @resource_klass = resource_klass

        case params[:action]
          when 'index'
            parse_fields(params)
            parse_includes(params)
            parse_filters(params)
          when 'show', 'create', 'update'
            parse_fields(params)
            parse_includes(params)
          else
            return
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
    end
  end
end
