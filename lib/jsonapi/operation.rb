module JSONAPI
  class Operation

    attr_reader :resource_klass, :transactional

    def initialize(resource_klass, transactional = true)
      @resource_klass = resource_klass
      @transactional = transactional
    end

    def apply(context)
    end
  end

  class FindOperation < Operation
    def initialize(resource_klass, filters, include_directives, sort_criteria, paginator)
      @filters = filters
      @include_directives = include_directives
      @sort_criteria = sort_criteria
      @paginator = paginator
      super(resource_klass, false)
    end

    def apply(context)
      resource_records = @resource_klass.find(@resource_klass.verify_filters(@filters, context),
                                             context: context,
                                             include_directives: @include_directives,
                                             sort_criteria: @sort_criteria,
                                             paginator: @paginator)

      return JSONAPI::ResourcesOperationResult.new(:ok, resource_records)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end
  end

  class ShowOperation < Operation
    def initialize(resource_klass, id, include_directives)
      @id = id
      @include_directives = include_directives
      super(resource_klass, false)
    end

    def apply(context)
      key = @resource_klass.verify_key(@id, context)

      resource_record = resource_klass.find_by_key(key,
                                                   context: context,
                                                   include_directives: @include_directives)

      return JSONAPI::ResourceOperationResult.new(:ok, resource_record)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end
  end

  class ShowAssociationOperation < Operation
    def initialize(resource_klass, association_type, parent_key)
      @parent_key = parent_key
      @association_type = association_type
      super(resource_klass, false)
    end

    def apply(context)
      parent_resource = resource_klass.find_by_key(@parent_key, context: context)

      return JSONAPI::LinksObjectOperationResult.new(:ok,
                                                     parent_resource,
                                                     resource_klass._association(@association_type))

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end
  end

  class ShowRelatedResourceOperation < Operation
    def initialize(resource_klass, association_type, source_klass, source_id)
      @source_klass = source_klass
      @source_id = source_id
      @association_type = association_type
      super(resource_klass, false)
    end

    def apply(context)
      source_resource = @source_klass.find_by_key(@source_id, context: context)

      related_resource = source_resource.send(@association_type)

      return JSONAPI::ResourceOperationResult.new(:ok, related_resource)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end
  end

  class ShowRelatedResourcesOperation < Operation
    def initialize(resource_klass, association_type, source_klass, source_id, filters, sort_criteria, paginator)
      @source_klass = source_klass
      @source_id = source_id
      @association_type = association_type
      @filters = filters
      @sort_criteria = sort_criteria
      @paginator = paginator
      super(resource_klass, false)
    end

    def apply(context)
      source_resource = @source_klass.find_by_key(@source_id, context: context)

      related_resource = source_resource.send(@association_type,
                                              {
                                                filters:  @filters,
                                                sort_criteria: @sort_criteria,
                                                paginator: @paginator
                                              })

      return JSONAPI::ResourceOperationResult.new(:ok, related_resource)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end
  end

  class CreateResourceOperation < Operation
    attr_reader :values

    def initialize(resource_klass, values = {})
      @values = values
      super(resource_klass)
    end

    def apply(context)
      resource = @resource_klass.create(context)
      resource.replace_fields(@values)

      return JSONAPI::ResourceOperationResult.new(:created, resource)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end
  end

  class RemoveResourceOperation < Operation
    attr_reader :resource_id
    def initialize(resource_klass, resource_id)
      @resource_id = resource_id
      super(resource_klass)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      resource.remove

      return JSONAPI::OperationResult.new(:no_content)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end
  end

  class ReplaceFieldsOperation < Operation
    attr_reader :values, :resource_id

    def initialize(resource_klass, resource_id, values)
      @resource_id = resource_id
      @values = values
      super(resource_klass)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      resource.replace_fields(values)

      return JSONAPI::ResourceOperationResult.new(:ok, resource)
    end
  end

  class ReplaceHasOneAssociationOperation < Operation
    attr_reader :resource_id, :association_type, :key_value

    def initialize(resource_klass, resource_id, association_type, key_value)
      @resource_id = resource_id
      @key_value = key_value
      @association_type = association_type.to_sym
      super(resource_klass)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      resource.replace_has_one_link(@association_type, @key_value)

      return JSONAPI::OperationResult.new(:no_content)
    end
  end

  class CreateHasManyAssociationOperation < Operation
    attr_reader :resource_id, :association_type, :key_values

    def initialize(resource_klass, resource_id, association_type, key_values)
      @resource_id = resource_id
      @key_values = key_values
      @association_type = association_type.to_sym
      super(resource_klass)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      resource.create_has_many_links(@association_type, @key_values)

      return JSONAPI::OperationResult.new(:no_content)
    end
  end

  class ReplaceHasManyAssociationOperation < Operation
    attr_reader :resource_id, :association_type, :key_values

    def initialize(resource_klass, resource_id, association_type, key_values)
      @resource_id = resource_id
      @key_values = key_values
      @association_type = association_type.to_sym
      super(resource_klass)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      resource.replace_has_many_links(@association_type, @key_values)

      return JSONAPI::OperationResult.new(:no_content)
    end
  end

  class RemoveHasManyAssociationOperation < Operation
    attr_reader :resource_id, :association_type, :associated_key

    def initialize(resource_klass, resource_id, association_type, associated_key)
      @resource_id = resource_id
      @associated_key = associated_key
      @association_type = association_type.to_sym
      super(resource_klass)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      resource.remove_has_many_link(@association_type, @associated_key)

      return JSONAPI::OperationResult.new(:no_content)
    end
  end

  class RemoveHasOneAssociationOperation < Operation
    attr_reader :resource_id, :association_type

    def initialize(resource_klass, resource_id, association_type)
      @resource_id = resource_id
      @association_type = association_type.to_sym
      super(resource_klass)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      resource.remove_has_one_link(@association_type)

      return JSONAPI::OperationResult.new(:no_content)
    end
  end
end
