module JSONAPI
  class Operation

    attr_reader :resource_klass

    def initialize(resource_klass)
      @resource_klass = resource_klass
    end

    def apply(context)
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

      return JSONAPI::OperationResult.new(:created, resource)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::OperationResult.new(e.errors[0].code, nil, e.errors)
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
      return JSONAPI::OperationResult.new(e.errors[0].code, nil, e.errors)
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

      return JSONAPI::OperationResult.new(:ok, resource)
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
