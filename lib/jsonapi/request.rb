require 'jsonapi/resource_for'
require 'jsonapi/operation'

module JSONAPI
  class Request
    include ResourceFor

    attr_accessor :fields, :includes, :filters, :errors, :operations, :resource_klass, :context

    def initialize(context = {}, params = nil)
      @context = context
      @errors = []
      @operations = []
      @fields = {}
      @includes = []
      @filters = {}

      setup(params) if params
    end

    def setup(params)
      @resource_klass ||= self.class.resource_for(params[:controller]) if params[:controller]

      unless params.nil?
        case params[:action]
          when 'index'
            parse_fields(params)
            parse_includes(params)
            parse_filters(params)
          when 'show_associations'
          when 'show'
            parse_fields(params)
            parse_includes(params)
          when 'create'
            parse_fields(params)
            parse_includes(params)
            parse_add_operation(params)
          when 'create_association'
            parse_fields(params)
            parse_includes(params)
            parse_add_association_operation(params)
          when 'update'
            parse_fields(params)
            parse_includes(params)
            parse_replace_operation(params)
          when 'destroy'
            parse_remove_operation(params)
          when 'destroy_association'
            parse_remove_association_operation(params)
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
          @errors.concat(JSONAPI::Exceptions::InvalidResource.new(type).errors)
        else
          unless values.nil?
            values.each do |field|
              if type_resource._validate_field(field)
                fields[type].push field
              else
                @errors.concat(JSONAPI::Exceptions::InvalidField.new(type, field).errors)
              end
            end
          else
            @errors.concat(JSONAPI::Exceptions::InvalidField.new(type, 'nil').errors)
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
          @errors.concat(JSONAPI::Exceptions::FilterNotAllowed.new(filter).errors)
        end
      end
      @filters = filters
    end

    def parse_add_operation(params)
      object_params_raw = params.require(@resource_klass._type)

      if object_params_raw.is_a?(Array)
        object_params_raw.each do |p|
          @operations.push JSONAPI::CreateResourceOperation.new(@resource_klass,
                                                                  @resource_klass.verify_create_params(p, @context))
        end
      else
        @operations.push JSONAPI::CreateResourceOperation.new(@resource_klass,
                                                                @resource_klass.verify_create_params(object_params_raw,
                                                                                                     @context))
      end
    rescue ActionController::ParameterMissing => e
      @errors.concat(JSONAPI::Exceptions::ParameterMissing.new(e.param).errors)
    rescue JSONAPI::Exceptions::Error => e
      @errors.concat(e.errors)
    end

    def parse_add_association_operation(params)
      association_type = params[:association].to_sym

      parent_key = params[resource_klass._as_parent_key]

      if params[association_type].nil?
        raise ActionController::ParameterMissing.new(association_type)
      end

      object_params = {links: {association_type => params[association_type]}}
      verified_param_set = @resource_klass.verify_update_params(object_params, @context)

      association = resource_klass._association(association_type)

      if association.is_a?(JSONAPI::Association::HasOne)
        @operations.push JSONAPI::ReplaceHasOneAssociationOperation.new(resource_klass,
                                                                          parent_key,
                                                                          association_type,
                                                                          verified_param_set[:has_one].values[0])
      else
        @operations.push JSONAPI::CreateHasManyAssociationOperation.new(resource_klass,
                                                                          parent_key,
                                                                          association_type,
                                                                          verified_param_set[:has_many].values[0])
      end
    rescue ActionController::ParameterMissing => e
      @errors.concat(JSONAPI::Exceptions::ParameterMissing.new(e.param).errors)
    end

    def parse_replace_operation(params)
      object_params_raw = params.require(@resource_klass._type)

      keys = params[@resource_klass._key]
      if object_params_raw.is_a?(Array)
        if keys.count != object_params_raw.count
          raise JSONAPI::Exceptions::CountMismatch
        end

        object_params_raw.each do |object_params|
          if object_params[@resource_klass._key].nil?
            raise JSONAPI::Exceptions::MissingKey.new
          end

          if !keys.include?(object_params[@resource_klass._key])
            raise JSONAPI::Exceptions::KeyNotIncludedInURL.new(object_params[@resource_klass._key])
          end
          @operations.push JSONAPI::ReplaceFieldsOperation.new(@resource_klass,
                                                                 object_params[@resource_klass._key],
                                                                 @resource_klass.verify_update_params(object_params,
                                                                                                      @context))
        end
      else
        if !object_params_raw[@resource_klass._key].nil? && keys != object_params_raw[@resource_klass._key]
          raise JSONAPI::Exceptions::KeyNotIncludedInURL.new(object_params_raw[@resource_klass._key])
        end

        @operations.push JSONAPI::ReplaceFieldsOperation.new(@resource_klass,
                                                               params[@resource_klass._key],
                                                               @resource_klass.verify_update_params(object_params_raw,
                                                                                                    @context))
      end

    rescue ActionController::ParameterMissing => e
      @errors.concat(JSONAPI::Exceptions::ParameterMissing.new(e.param).errors)
    rescue JSONAPI::Exceptions::Error => e
      @errors.concat(e.errors)
    end

    def parse_remove_operation(params)
      keys = parse_key_array(params.permit(@resource_klass._key)[@resource_klass._key])

      keys.each do |key|
        @operations.push JSONAPI::RemoveResourceOperation.new(@resource_klass, key)
      end
    rescue ActionController::UnpermittedParameters => e
      @errors.concat(JSONAPI::Exceptions::ParametersNotAllowed.new(e.params).errors)
    rescue JSONAPI::Exceptions::Error => e
      @errors.concat(e.errors)
    end

    def parse_remove_association_operation(params)
      association_type = params[:association].to_sym

      parent_key = params[resource_klass._as_parent_key]

      association = resource_klass._association(association_type)
      if association.is_a?(JSONAPI::Association::HasMany)
        keys = parse_key_array(params[:keys])
        keys.each do |key|
          @operations.push JSONAPI::RemoveHasManyAssociationOperation.new(resource_klass,
                                                                            parent_key,
                                                                            association_type,
                                                                            key)
        end
      else
        @operations.push JSONAPI::RemoveHasOneAssociationOperation.new(resource_klass,
                                                                         parent_key,
                                                                         association_type)
      end
    end

    def parse_key_array(raw)
      keys = []
      raw.split(/,/).collect do |key|
        keys.push @resource_klass.verify_key(key, context)
      end
      return keys
    end
  end
end