module JSONAPI
  class Operation
    attr_reader :resource_klass, :options, :transactional

    def initialize(resource_klass, options = {})
      @resource_klass = resource_klass
      @options = options
      @transactional = true
    end

    def apply(context)
    end
  end

  class FindOperation < Operation
    attr_reader :filters, :include_directives, :sort_criteria, :paginator

    def initialize(resource_klass, options = {})
      @filters = options[:filters]
      @include_directives = options[:include_directives]
      @sort_criteria = options.fetch(:sort_criteria, [])
      @paginator = options[:paginator]
      super(resource_klass, false)
    end

    def record_count
      @_record_count ||= @resource_klass.find_count(@resource_klass.verify_filters(@filters, @context),
                                                     context: @context,
                                                     include_directives: @include_directives)
    end

    def pagination_params
      if @paginator && JSONAPI.configuration.top_level_links_include_pagination
        options = {}
        options[:record_count] = record_count if @paginator.class.requires_record_count
        return @paginator.links_page_params(options)
      else
        return {}
      end
    end

    def apply(context)
      resource_records = @resource_klass.find(@resource_klass.verify_filters(@filters, context),
                                             context: context,
                                             include_directives: @include_directives,
                                             sort_criteria: @sort_criteria,
                                             paginator: @paginator)

      options = {}
      if JSONAPI.configuration.top_level_links_include_pagination
        options[:pagination_params] = pagination_params
      end

      if JSONAPI.configuration.top_level_meta_include_record_count
        options[:record_count] = record_count
      end

      return JSONAPI::ResourcesOperationResult.new(:ok,
                                                   resource_records,
                                                   options)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end
  end

  class ShowOperation < Operation
    attr_reader :id, :include_directives

    def initialize(resource_klass, options = {})
      @id = options.fetch(:id)
      @include_directives = options[:include_directives]
      @transactional = false
      super(resource_klass, options)
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
    attr_reader :parent_key, :association_type

    def initialize(resource_klass, options = {})
      @parent_key = options.fetch(:parent_key)
      @association_type = options.fetch(:association_type)
      @transactional = false
      super(resource_klass, options)
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
    attr_reader :source_klass, :source_id, :association_type

    def initialize(resource_klass, options = {})
      @source_klass = options.fetch(:source_klass)
      @source_id = options.fetch(:source_id)
      @association_type = options.fetch(:association_type)
      @transactional = false
      super(resource_klass, options)
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
    attr_reader :source_klass, :source_id, :association_type, :filters, :sort_criteria, :paginator

    def initialize(resource_klass, options = {})
      @source_klass = options.fetch(:source_klass)
      @source_id = options.fetch(:source_id)
      @association_type = options.fetch(:association_type)
      @filters = options[:filters]
      @sort_criteria = options[:sort_criteria]
      @paginator = options[:paginator]
      @transactional = false
      super(resource_klass, options)
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
    attr_reader :data

    def initialize(resource_klass, options = {})
      @data = options.fetch(:data)
      super(resource_klass, options)
    end

    def apply(context)
      resource = @resource_klass.create(context)
      result = resource.replace_fields(@data)

      return JSONAPI::ResourceOperationResult.new((result == :completed ? :created : :accepted), resource)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end
  end

  class RemoveResourceOperation < Operation
    attr_reader :resource_id
    def initialize(resource_klass, options = {})
      @resource_id = options.fetch(:resource_id)
      super(resource_klass, options)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      result = resource.remove

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted)

    rescue JSONAPI::Exceptions::Error => e
      return JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end
  end

  class ReplaceFieldsOperation < Operation
    attr_reader :data, :resource_id

    def initialize(resource_klass, options = {})
      @resource_id = options.fetch(:resource_id)
      @data = options.fetch(:data)
      super(resource_klass, options)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      result = resource.replace_fields(data)

      return JSONAPI::ResourceOperationResult.new(result == :completed ? :ok : :accepted, resource)
    end
  end

  class ReplaceHasOneAssociationOperation < Operation
    attr_reader :resource_id, :association_type, :key_value

    def initialize(resource_klass, options = {})
      @resource_id = options.fetch(:resource_id)
      @key_value = options.fetch(:key_value)
      @association_type = options.fetch(:association_type).to_sym
      super(resource_klass, options)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      result = resource.replace_has_one_link(@association_type, @key_value)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted)
    end
  end

  class CreateHasManyAssociationOperation < Operation
    attr_reader :resource_id, :association_type, :data

    def initialize(resource_klass, options)
      @resource_id = options.fetch(:resource_id)
      @data = options.fetch(:data)
      @association_type = options.fetch(:association_type).to_sym
      super(resource_klass, options)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      result = resource.create_has_many_links(@association_type, @data)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted)
    end
  end

  class ReplaceHasManyAssociationOperation < Operation
    attr_reader :resource_id, :association_type, :data

    def initialize(resource_klass, options)
      @resource_id = options.fetch(:resource_id)
      @data = options.fetch(:data)
      @association_type = options.fetch(:association_type).to_sym
      super(resource_klass, options)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      result = resource.replace_has_many_links(@association_type, @data)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted)
    end
  end

  class RemoveHasManyAssociationOperation < Operation
    attr_reader :resource_id, :association_type, :associated_key

    def initialize(resource_klass, options)
      @resource_id = options.fetch(:resource_id)
      @associated_key = options.fetch(:associated_key)
      @association_type = options.fetch(:association_type).to_sym
      super(resource_klass, options)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      result = resource.remove_has_many_link(@association_type, @associated_key)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted)
    end
  end

  class RemoveHasOneAssociationOperation < Operation
    attr_reader :resource_id, :association_type

    def initialize(resource_klass, options)
      @resource_id = options.fetch(:resource_id)
      @association_type = options.fetch(:association_type).to_sym
      super(resource_klass, options)
    end

    def apply(context)
      resource = @resource_klass.find_by_key(@resource_id, context: context)
      result = resource.remove_has_one_link(@association_type)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted)
    end
  end
end
