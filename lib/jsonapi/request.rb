require 'jsonapi/operation'
require 'jsonapi/paginator'

module JSONAPI
  class Request
    attr_accessor :fields, :include, :filters, :sort_criteria, :errors, :operations,
                  :resource_klass, :context, :paginator, :source_klass, :source_id

    def initialize(params = nil, options = {})
      @context = options.fetch(:context, nil)
      @key_formatter = options.fetch(:key_formatter, JSONAPI.configuration.key_formatter)
      @errors = []
      @operations = []
      @fields = {}
      @include = []
      @filters = {}
      @sort_criteria = []
      @source_klass = nil
      @source_id = nil

      setup(params) if params
    end

    def setup(params)
      @resource_klass ||= Resource.resource_for(params[:controller]) if params[:controller]

      unless params.nil?
        case params[:action]
          when 'index'
            parse_fields(params[:fields])
            parse_include(params[:include])
            parse_filters(params[:filter])
            parse_sort_criteria(params[:sort])
            parse_pagination(params[:page])
          when 'get_related_resource', 'get_related_resources'
            @source_klass = Resource.resource_for(params.require(:source))
            @source_id = @source_klass.verify_key(params.require(@source_klass._as_parent_key), @context)
            parse_fields(params[:fields])
            parse_include(params[:include])
            parse_filters(params[:filter])
            parse_sort_criteria(params[:sort])
            parse_pagination(params[:page])
          when 'show'
            parse_fields(params[:fields])
            parse_include(params[:include])
          when 'create'
            parse_fields(params[:fields])
            parse_include(params[:include])
            parse_add_operation(params.require(:data))
          when 'create_association'
            parse_add_association_operation(params.require(:data),
                                            params.require(:association),
                                            params.require(@resource_klass._as_parent_key))
          when 'update_association'
            parse_update_association_operation(params.fetch(:data),
                                               params.require(:association),
                                               params.require(@resource_klass._as_parent_key))
          when 'update'
            parse_fields(params[:fields])
            parse_include(params[:include])
            parse_replace_operation(params.require(:data), params.require(@resource_klass._primary_key))
          when 'destroy'
            parse_remove_operation(params)
          when 'destroy_association'
            parse_remove_association_operation(params)
        end
      end
    rescue ActionController::ParameterMissing => e
      @errors.concat(JSONAPI::Exceptions::ParameterMissing.new(e.param).errors)
    end

    def parse_pagination(page)
      paginator_name = @resource_klass._paginator
      @paginator = JSONAPI::Paginator.paginator_for(paginator_name).new(page) unless paginator_name == :none
    rescue JSONAPI::Exceptions::Error => e
      @errors.concat(e.errors)
    end

    def parse_fields(fields)
      return if fields.nil?

      extracted_fields = {}

      # Extract the fields for each type from the fields parameters
      if fields.is_a?(ActionController::Parameters)
        fields.each do |field, value|
          resource_fields = value.split(',') unless value.nil? || value.empty?
          extracted_fields[field] = resource_fields
        end
      else
        raise JSONAPI::Exceptions::InvalidFieldFormat.new
      end

      # Validate the fields
      extracted_fields.each do |type, values|
        underscored_type = unformat_key(type)
        extracted_fields[type] = []
        begin
          if type != format_key(type)
            raise JSONAPI::Exceptions::InvalidResource.new(type)
          end
          type_resource = Resource.resource_for(@resource_klass.module_path + underscored_type.to_s)
        rescue NameError
          @errors.concat(JSONAPI::Exceptions::InvalidResource.new(type).errors)
        rescue JSONAPI::Exceptions::InvalidResource => e
        @errors.concat(e.errors)
        end

        if type_resource.nil? || !(@resource_klass._type == underscored_type ||
          @resource_klass._has_association?(underscored_type))
          @errors.concat(JSONAPI::Exceptions::InvalidResource.new(type).errors)
        else
          unless values.nil?
            valid_fields = type_resource.fields.collect { |key| format_key(key) }
            values.each do |field|
              if valid_fields.include?(field)
                extracted_fields[type].push unformat_key(field)
              else
                @errors.concat(JSONAPI::Exceptions::InvalidField.new(type, field).errors)
              end
            end
          else
            @errors.concat(JSONAPI::Exceptions::InvalidField.new(type, 'nil').errors)
          end
        end
      end

      @fields = extracted_fields.deep_transform_keys { |key| unformat_key(key) }
    end

    def check_include(resource_klass, include_parts)
      association_name = unformat_key(include_parts.first)

      association = resource_klass._association(association_name)
      if association && format_key(association_name) == include_parts.first
        unless include_parts.last.empty?
          check_include(Resource.resource_for(@resource_klass.module_path + association.class_name.to_s), include_parts.last.partition('.'))
        end
      else
        @errors.concat(JSONAPI::Exceptions::InvalidInclude.new(format_key(resource_klass._type),
                                                               include_parts.first,).errors)
      end
    end

    def parse_include(include)
      return if include.nil?

      included_resources = CSV.parse_line(include)
      return if included_resources.nil?

      @include = []
      included_resources.each do |included_resource|
        check_include(@resource_klass, included_resource.partition('.'))
        @include.push(unformat_key(included_resource).to_s)
      end
    end

    def parse_filters(filters)
      return unless filters
      @filters = {}
      filters.each do |key, value|
        filter = unformat_key(key)
        if @resource_klass._allowed_filter?(filter)
          @filters[filter] = value
        else
          @errors.concat(JSONAPI::Exceptions::FilterNotAllowed.new(filter).errors)
        end
      end
    end

    def parse_sort_criteria(sort_criteria)
      return unless sort_criteria

      @sort_criteria = CSV.parse_line(sort_criteria).collect do |sort|
        sort_criteria = {field: unformat_key(sort[1..-1]).to_s}
        if sort.start_with?('+')
          sort_criteria[:direction] = :asc
        elsif sort.start_with?('-')
          sort_criteria[:direction] = :desc
        else
          @errors.concat(JSONAPI::Exceptions::InvalidSortFormat
                           .new(format_key(resource_klass._type), sort).errors)
        end

        check_sort_criteria(@resource_klass, sort_criteria)
        sort_criteria
      end
    end

    def check_sort_criteria(resource_klass, sort_criteria)
      sort_field = sort_criteria[:field]
      sortable_fields = resource_klass.sortable_fields(context)

      unless sortable_fields.include? sort_field.to_sym
        @errors.concat(JSONAPI::Exceptions::InvalidSortCriteria
                         .new(format_key(resource_klass._type), sort_field).errors)
      end
    end

    def parse_add_operation(data)
      if data.is_a?(Array)
        data.each do |p|
          @operations.push JSONAPI::CreateResourceOperation.new(@resource_klass,
                                                                parse_params(verify_and_remove_type(p),
                                                                             @resource_klass.createable_fields(@context)))
        end
      else
        @operations.push JSONAPI::CreateResourceOperation.new(@resource_klass,
                                                              parse_params(verify_and_remove_type(data),
                                                                           @resource_klass.createable_fields(@context)))
      end
    rescue JSONAPI::Exceptions::Error => e
      @errors.concat(e.errors)
    end

    def verify_and_remove_type(params)
      #remove type and verify it matches the resource
      if unformat_key(params[:type]) == @resource_klass._type
        params.delete(:type)
      else
        if params[:type].nil?
          raise JSONAPI::Exceptions::ParameterMissing.new(:type)
        else
          raise JSONAPI::Exceptions::InvalidResource.new(params[:type])
        end
      end
      params
    end

    def parse_has_one_links_object(raw)
      if raw.nil?
        return {
          type: nil,
          id: nil
        }
      elsif raw.is_a?(Hash) && raw.has_key?('linkage')
        raw = raw['linkage']
      end

      if !raw.is_a?(Hash) || raw.length != 2 || !(raw.has_key?('type') && raw.has_key?('id'))
        raise JSONAPI::Exceptions::InvalidLinksObject.new
      end

      {
        type: raw['type'],
        id: raw['id']
      }
    end

    def parse_has_many_links_object(raw)
      if raw.nil?
        raise JSONAPI::Exceptions::InvalidLinksObject.new
      elsif raw.is_a?(Hash) && raw.has_key?('linkage')
        raw = raw['linkage']
      end

      links_object = {}
      if raw.is_a?(Array)
        raw.each do |link|
          link_object = parse_has_one_links_object(link)
          links_object[link_object[:type]] ||= []
          links_object[link_object[:type]].push(link_object[:id])
        end
      else
        raise JSONAPI::Exceptions::InvalidLinksObject.new
      end
      links_object
    end

    def parse_params(params, allowed_fields)
      verify_permitted_params(params, allowed_fields)

      checked_attributes = {}
      checked_has_one_associations = {}
      checked_has_many_associations = {}

      params.each do |key, value|
        if key == 'links' || key == :links
          value.each do |link_key, link_value|
            param = unformat_key(link_key)

            association = @resource_klass._association(param)

            if association.is_a?(JSONAPI::Association::HasOne)
              links_object = parse_has_one_links_object(link_value)
              # Since we do not yet support polymorphic associations we will raise an error if the type does not match the
              # association's type.
              # ToDo: Support Polymorphic associations
              if links_object[:type] && (links_object[:type] != association.type.to_s)
                raise JSONAPI::Exceptions::TypeMismatch.new(links_object[:type])
              end

              unless links_object[:id].nil?
                association_resource = Resource.resource_for(@resource_klass.module_path + links_object[:type])
                checked_has_one_associations[param] = association_resource.verify_key(links_object[:id], @context)
              else
                checked_has_one_associations[param] = nil
              end
            elsif association.is_a?(JSONAPI::Association::HasMany)
              links_object = parse_has_many_links_object(link_value)

              # Since we do not yet support polymorphic associations we will raise an error if the type does not match the
              # association's type.
              # ToDo: Support Polymorphic associations

              if links_object.length == 0
                checked_has_many_associations[param] = []
              else
                if links_object.length > 1 || !links_object.has_key?(association.type.to_s)
                  raise JSONAPI::Exceptions::TypeMismatch.new(links_object[:type])
                end

                links_object.each_pair do |type, keys|
                  association_resource = Resource.resource_for(@resource_klass.module_path + type)
                  checked_has_many_associations[param] = association_resource.verify_keys(keys, @context)
                end
              end
            end
          end
        else
          param = unformat_key(key)
          checked_attributes[param] = unformat_value(param, value)
        end
      end

      return {
        'attributes' => checked_attributes,
        'has_one' => checked_has_one_associations,
        'has_many' => checked_has_many_associations
      }.deep_transform_keys { |key| unformat_key(key) }
    end

    def unformat_value(attribute, value)
      value_formatter = JSONAPI::ValueFormatter.value_formatter_for(@resource_klass._attribute_options(attribute)[:format])
      value_formatter.unformat(value, @context)
    end

    def verify_permitted_params(params, allowed_fields)
      formatted_allowed_fields = allowed_fields.collect { |field| format_key(field).to_sym }
      params_not_allowed = []
      params.each do |key, value|
        if key == 'links' || key == :links
          value.each_key do |links_key|
            params_not_allowed.push(links_key) unless formatted_allowed_fields.include?(links_key.to_sym)
          end
        else
          params_not_allowed.push(key) unless formatted_allowed_fields.include?(key.to_sym)
        end
      end
      raise JSONAPI::Exceptions::ParametersNotAllowed.new(params_not_allowed) if params_not_allowed.length > 0
    end

    def parse_add_association_operation(data, association_type, parent_key)
      association = resource_klass._association(association_type)

      if association.is_a?(JSONAPI::Association::HasMany)
        object_params = {links: {association.name => data}}
        verified_param_set = parse_params(object_params, @resource_klass.updateable_fields(@context))

        @operations.push JSONAPI::CreateHasManyAssociationOperation.new(resource_klass,
                                                                        parent_key,
                                                                        association_type,
                                                                        verified_param_set[:has_many].values[0])
      end
    end

    def parse_update_association_operation(data, association_type, parent_key)
      association = resource_klass._association(association_type)

      if association.is_a?(JSONAPI::Association::HasOne)
        object_params = {links: {association.name => data}}

        verified_param_set = parse_params(object_params, @resource_klass.updateable_fields(@context))

        @operations.push JSONAPI::ReplaceHasOneAssociationOperation.new(resource_klass,
                                                                        parent_key,
                                                                        association_type,
                                                                        verified_param_set[:has_one].values[0])
      else
        object_params = {links: {association.name => data}}
        verified_param_set = parse_params(object_params, @resource_klass.updateable_fields(@context))

        @operations.push JSONAPI::ReplaceHasManyAssociationOperation.new(resource_klass,
                                                                         parent_key,
                                                                         association_type,
                                                                         verified_param_set[:has_many].values[0])
      end
    end

    def parse_single_replace_operation(data, keys)
      if data[@resource_klass._primary_key].nil?
        raise JSONAPI::Exceptions::MissingKey.new
      end

      type = data[:type]
      if type.nil? || type != @resource_klass._type.to_s
        raise JSONAPI::Exceptions::ParameterMissing.new(:type)
      end

      key = data[@resource_klass._primary_key]
      if !keys.include?(key)
        raise JSONAPI::Exceptions::KeyNotIncludedInURL.new(key)
      end

      if !keys.include?(@resource_klass._primary_key)
        data.delete(:id)
      end

      @operations.push(JSONAPI::ReplaceFieldsOperation.new(@resource_klass,
                                                           key,
                                                           parse_params(verify_and_remove_type(data),
                                                                        @resource_klass.updateable_fields(@context))))
    end

    def parse_replace_operation(data, keys)
      if data.is_a?(Array)
        if keys.count != data.count
          raise JSONAPI::Exceptions::CountMismatch
        end

        data.each do |object_params|
          parse_single_replace_operation(object_params, keys)
        end
      else
        parse_single_replace_operation(data, [keys])
      end

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
      unformatted_key = @key_formatter.unformat(key)
      unformatted_key.nil? ? nil : unformatted_key.to_sym
    end
  end
end
