require 'jsonapi/resource_for'
require 'jsonapi/operation'

module JSONAPI
  class Request
    include ResourceFor

    attr_accessor :fields, :include, :filters, :sort_params, :errors, :operations, :resource_klass, :context

    def initialize(params = nil, options = {})
      @context = options.fetch(:context, nil)
      @key_formatter = options.fetch(:key_formatter, JSONAPI.configuration.key_formatter)
      @errors = []
      @operations = []
      @fields = {}
      @include = []
      @filters = {}

      setup(params) if params
    end

    def setup(params)
      @resource_klass ||= self.class.resource_for(params[:controller]) if params[:controller]

      unless params.nil?
        case params[:action]
          when 'index'
            parse_fields(params)
            parse_include(params)
            parse_filters(params)
            parse_sort_params(params)
          when 'show_associations'
          when 'show'
            parse_fields(params)
            parse_include(params)
          when 'create'
            parse_fields(params)
            parse_include(params)
            parse_add_operation(params)
          when 'create_association'
            parse_add_association_operation(params)
          when 'update_association'
            parse_update_association_operation(params)
          when 'update'
            parse_fields(params)
            parse_include(params)
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
          resource_fields = value.split(',') unless value.nil? || value.empty?
          type = @resource_klass._type
          fields[type] = resource_fields
        elsif params[:fields].is_a?(ActionController::Parameters)
          params[:fields].each do |param, value|
            resource_fields = value.split(',') unless value.nil? || value.empty?
            type = param
            fields[type] = resource_fields
          end
        end
      end

      # Validate the fields
      fields.each do |type, values|
        underscored_type = unformat_key(type)
        fields[type] = []
        begin
          type_resource = self.class.resource_for(underscored_type)
        rescue NameError
          @errors.concat(JSONAPI::Exceptions::InvalidResource.new(type).errors)
        end
          if type_resource.nil? || !(@resource_klass._type == underscored_type ||
                                     @resource_klass._has_association?(underscored_type))
            @errors.concat(JSONAPI::Exceptions::InvalidResource.new(type).errors)
        else
          unless values.nil?
            valid_fields = type_resource.fields.collect {|key| format_key(key)}
            values.each do |field|
              if valid_fields.include?(field)
                fields[type].push unformat_key(field)
              else
                @errors.concat(JSONAPI::Exceptions::InvalidField.new(type, field).errors)
              end
            end
          else
            @errors.concat(JSONAPI::Exceptions::InvalidField.new(type, 'nil').errors)
          end
        end
      end

      @fields = fields.deep_transform_keys{ |key| unformat_key(key) }
    end

    def check_include(resource_klass, include_parts)
      association_name = unformat_key(include_parts.first)

      association = resource_klass._association(association_name)
      if association
        unless include_parts.last.empty?
          check_include(Resource.resource_for(association.class_name), include_parts.last.partition('.'))
        end
      else
        @errors.concat(JSONAPI::Exceptions::InvalidInclude.new(format_key(resource_klass._type),
                                                               include_parts.first, ).errors)
      end
    end

    def parse_include(params)
      included_resources_raw = CSV.parse_line(params[:include]) unless params[:include].nil? || params[:include].empty?
      @include = []
      return if included_resources_raw.nil?
      included_resources_raw.each do |include|
        check_include(@resource_klass, include.partition('.'))
        @include.push(unformat_key(include).to_s)
      end
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

        # Ignore non-filter parameters
        next if JSONAPI.configuration.allowed_request_params.include?(filter)

        filter = unformat_key(key).to_sym
        if @resource_klass._allowed_filter?(filter)
          filters[filter] = value
        else
          @errors.concat(JSONAPI::Exceptions::FilterNotAllowed.new(filter).errors)
        end
      end
      @filters = filters
    end

    def parse_sort_params(params)
      @sort_params = if params[:sort].present?
        CSV.parse_line(params[:sort]).collect do |sort_param|
          # A parameter name may not start with a dash
          # We need to preserve the dash as the sort direction before we unformat the string
          if sort_param.start_with?('-')
            unformatted_sort_param = unformat_key(sort_param[1..-1]).to_s
            unformatted_sort_param.prepend('-')
          else
            unformatted_sort_param = unformat_key(sort_param).to_s
          end

          check_sort_param(@resource_klass, unformatted_sort_param)
          unformatted_sort_param
        end
      else
        []
      end
    end

    def check_sort_param(resource_klass, sort_param)
      sort_param = sort_param.sub(/\A-/, '')
      sortable_fields = resource_klass.sortable_fields(context)

      unless sortable_fields.include? sort_param.to_sym
        @errors.concat(JSONAPI::Exceptions::InvalidSortParam
          .new(format_key(resource_klass._type), sort_param).errors)
      end
    end

    def parse_add_operation(params)
      object_params_raw = params.require(format_key(@resource_klass._type))

      if object_params_raw.is_a?(Array)
        object_params_raw.each do |p|
          @operations.push JSONAPI::CreateResourceOperation.new(@resource_klass,
                                                                parse_params(p, @resource_klass.createable_fields(@context)))
        end
      else
        @operations.push JSONAPI::CreateResourceOperation.new(@resource_klass,
                                                              parse_params(object_params_raw, @resource_klass.createable_fields(@context)))
      end
    rescue ActionController::ParameterMissing => e
      @errors.concat(JSONAPI::Exceptions::ParameterMissing.new(e.param).errors)
    rescue JSONAPI::Exceptions::Error => e
      @errors.concat(e.errors)
    end

    def parse_params(params, allowed_fields)
      # push links into top level param list with attributes in order to check for invalid params
      if params[:links]
        params[:links].each do |link, value|
          params[link] = value
        end
        params.delete(:links)
      end
      verify_permitted_params(params, allowed_fields)

      checked_attributes = {}
      checked_has_one_associations = {}
      checked_has_many_associations = {}

      params.each do |key, value|
        param = unformat_key(key)

        association = @resource_klass._association(param)

        if association.is_a?(JSONAPI::Association::HasOne)
          checked_has_one_associations[param] = @resource_klass.resource_for(association.type).verify_key(value, @context)
        elsif association.is_a?(JSONAPI::Association::HasMany)
          keys = []
          if value.is_a?(Array)
            keys = @resource_klass.resource_for(association.type).verify_keys(value, @context)
          else
            keys.push(@resource_klass.resource_for(association.type).verify_key(value, @context))
          end
          checked_has_many_associations[param] = keys
        else
          checked_attributes[param] = unformat_value(param, value)
        end
      end

      return {
        'attributes' => checked_attributes,
        'has_one' => checked_has_one_associations,
        'has_many' => checked_has_many_associations
      }.deep_transform_keys{ |key| unformat_key(key) }
    end

    def unformat_value(attribute, value)
      value_formatter = JSONAPI::ValueFormatter.value_formatter_for(@resource_klass._attribute_options(attribute)[:format])
      value_formatter.unformat(value, @context)
    end

    def verify_permitted_params(params, allowed_fields)
      formatted_allowed_fields = allowed_fields.collect {|field| format_key(field).to_sym}
      params_not_allowed = []
      params.keys.each do |key|
        params_not_allowed.push(key) unless formatted_allowed_fields.include?(key.to_sym)
      end
      raise JSONAPI::Exceptions::ParametersNotAllowed.new(params_not_allowed) if params_not_allowed.length > 0
    end

    def parse_add_association_operation(params)
      association_type = params[:association]

      parent_key = params[resource_klass._as_parent_key]

      association = resource_klass._association(association_type)

      if association.is_a?(JSONAPI::Association::HasOne)
        plural_association_type = association_type.pluralize

        if params[plural_association_type].nil?
          raise ActionController::ParameterMissing.new(plural_association_type)
        end

        object_params = {links: {association_type => params[plural_association_type]}}
        verified_param_set = parse_params(object_params, @resource_klass.updateable_fields(@context))

        @operations.push JSONAPI::CreateHasOneAssociationOperation.new(resource_klass,
                                                                      parent_key,
                                                                      association_type,
                                                                      verified_param_set[:has_one].values[0])
      else
        if params[association_type].nil?
          raise ActionController::ParameterMissing.new(association_type)
        end

        object_params = {links: {association_type => params[association_type]}}
        verified_param_set = parse_params(object_params, @resource_klass.updateable_fields(@context))

        @operations.push JSONAPI::CreateHasManyAssociationOperation.new(resource_klass,
                                                                        parent_key,
                                                                        association_type,
                                                                        verified_param_set[:has_many].values[0])
      end
    rescue ActionController::ParameterMissing => e
      @errors.concat(JSONAPI::Exceptions::ParameterMissing.new(e.param).errors)
    end

    def parse_update_association_operation(params)
      association_type = params[:association]

      parent_key = params[resource_klass._as_parent_key]

      association = resource_klass._association(association_type)

      if association.is_a?(JSONAPI::Association::HasOne)
        plural_association_type = association_type.pluralize

        if params[plural_association_type].nil?
          raise ActionController::ParameterMissing.new(plural_association_type)
        end

        object_params = {links: {association_type => params[plural_association_type]}}
        verified_param_set = parse_params(object_params, @resource_klass.updateable_fields(@context))

        @operations.push JSONAPI::ReplaceHasOneAssociationOperation.new(resource_klass,
                                                                        parent_key,
                                                                        association_type,
                                                                        verified_param_set[:has_one].values[0])
      else
        if params[association_type].nil?
          raise ActionController::ParameterMissing.new(association_type)
        end

        object_params = {links: {association_type => params[association_type]}}
        verified_param_set = parse_params(object_params, @resource_klass.updateable_fields(@context))

        @operations.push JSONAPI::ReplaceHasManyAssociationOperation.new(resource_klass,
                                                                         parent_key,
                                                                         association_type,
                                                                         verified_param_set[:has_many].values[0])
      end
    rescue ActionController::ParameterMissing => e
      @errors.concat(JSONAPI::Exceptions::ParameterMissing.new(e.param).errors)
    end

    def parse_replace_operation(params)
      object_params_raw = params.require(format_key(@resource_klass._type))

      keys = params[@resource_klass._primary_key]
      if object_params_raw.is_a?(Array)
        if keys.count != object_params_raw.count
          raise JSONAPI::Exceptions::CountMismatch
        end

        object_params_raw.each do |object_params|
          if object_params[@resource_klass._primary_key].nil?
            raise JSONAPI::Exceptions::MissingKey.new
          end

          if !keys.include?(object_params[@resource_klass._primary_key])
            raise JSONAPI::Exceptions::KeyNotIncludedInURL.new(object_params[@resource_klass._primary_key])
          end
          @operations.push JSONAPI::ReplaceFieldsOperation.new(@resource_klass,
                                                               object_params[@resource_klass._primary_key],
                                                               parse_params(object_params, @resource_klass.updateable_fields(@context)))
        end
      else
        if !object_params_raw[@resource_klass._primary_key].nil? && keys != object_params_raw[@resource_klass._primary_key]
          raise JSONAPI::Exceptions::KeyNotIncludedInURL.new(object_params_raw[@resource_klass._primary_key])
        end

        @operations.push JSONAPI::ReplaceFieldsOperation.new(@resource_klass,
                                                               params[@resource_klass._primary_key],
                                                               parse_params(object_params_raw, @resource_klass.updateable_fields(@context)))
      end

    rescue ActionController::ParameterMissing => e
      @errors.concat(JSONAPI::Exceptions::ParameterMissing.new(e.param).errors)
    rescue JSONAPI::Exceptions::Error => e
      @errors.concat(e.errors)
    end

    def parse_remove_operation(params)
      keys = parse_key_array(params.permit(@resource_klass._primary_key)[@resource_klass._primary_key])

      keys.each do |key|
        @operations.push JSONAPI::RemoveResourceOperation.new(@resource_klass, key)
      end
    rescue ActionController::UnpermittedParameters => e
      @errors.concat(JSONAPI::Exceptions::ParametersNotAllowed.new(e.params).errors)
    rescue JSONAPI::Exceptions::Error => e
      @errors.concat(e.errors)
    end

    def parse_remove_association_operation(params)
      association_type = params[:association]

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
      return @resource_klass.verify_keys(raw.split(/,/), context)
    end

    def format_key(key)
      @key_formatter.format(key)
    end

    def unformat_key(key)
      @key_formatter.unformat(key)
    end
  end
end
