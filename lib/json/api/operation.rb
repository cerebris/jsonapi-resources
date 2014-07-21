module JSON
  module API
    class Operation

      attr_reader :resource_klass, :op, :resource_id, :path, :values

      def initialize(resource_klass, op, resource_id, path, values = {})
        @resource_klass = resource_klass
        @op = op
        @resource_id = resource_id
        @path = path
        @values = values
      end
    end
  end
end