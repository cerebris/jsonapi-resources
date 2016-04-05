module JSONAPI
  class Operation
    attr_reader :resource_klass, :options, :transactional

    def initialize(resource_klass, options)
      @resource_klass = resource_klass
      @options = options
      @transactional = true
    end

    def processor_method_name
      @processor_method_name ||= self.class.name.gsub(/^.*::/, '').underscore.gsub(/_operation$/, '')
    end

    def apply
      processor.public_send(processor_method_name)
    end

    def processor
      JSONAPI::OperationProcessor.operation_processor_instance_for(resource_klass, options)
    end
  end

  class TransactionalOperation < Operation
  end

  class NontransactionalOperation < Operation
    def initialize(resource_klass, options)
      super(resource_klass, options)
      @transactional = false
    end
  end

  class FindOperation < NontransactionalOperation
  end

  class ShowOperation < NontransactionalOperation
  end

  class ShowRelationshipOperation < NontransactionalOperation
  end

  class ShowRelatedResourceOperation < NontransactionalOperation
  end

  class ShowRelatedResourcesOperation < NontransactionalOperation
  end

  class CreateResourceOperation < TransactionalOperation
  end

  class RemoveResourceOperation < TransactionalOperation
  end

  class ReplaceFieldsOperation < TransactionalOperation
  end

  class ReplaceToOneRelationshipOperation < TransactionalOperation
  end

  class ReplacePolymorphicToOneRelationshipOperation < TransactionalOperation
  end

  class CreateToManyRelationshipOperation < TransactionalOperation
  end

  class ReplaceToManyRelationshipOperation < TransactionalOperation
  end

  class RemoveToManyRelationshipOperation < TransactionalOperation
  end

  class RemoveToOneRelationshipOperation < TransactionalOperation
  end
end
