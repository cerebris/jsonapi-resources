module JSONAPI
  class Operation
    attr_reader :resource_klass, :operation_type, :options

    def initialize(operation_type, resource_klass, options)
      @operation_type = operation_type
      @resource_klass = resource_klass
      @options = options
    end

    def process
      processor.process
    end

    private
    def processor
      JSONAPI::Processor.processor_instance_for(resource_klass, operation_type, options)
    end
  end
end
