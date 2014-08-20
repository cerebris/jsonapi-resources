module JSON
  module API
    class Operation

      attr_reader :resource_klass

      def initialize(resource_klass)
        @resource_klass = resource_klass
      end
    end

    class AddResourceOperation < Operation
      attr_reader :values

      def initialize(resource_klass, values = {})
        @values = values
        super(resource_klass)
      end
    end

    class RemoveResourceOperation < Operation
      attr_reader :resource_id
      def initialize(resource_klass, resource_id)
        @resource_id = resource_id
        super(resource_klass)
      end
    end

    class ReplaceAttributesOperation < Operation
      attr_reader :values, :resource_id

      def initialize(resource_klass, resource_id, values)
        @resource_id = resource_id
        @values = values
        super(resource_klass)
      end
    end

    class AddHasOneAssociationOperation < Operation
      attr_reader :resource_id, :association_type, :key, :key_value

      def initialize(resource_klass, resource_id, association_type, key, key_value)
        @resource_id = resource_id
        @key = key
        @key_value = key_value
        @association_type = association_type
        super(resource_klass)
      end
    end

    class AddHasManyAssociationOperation < Operation
      attr_reader :resource_id, :association_type, :key, :key_values

      def initialize(resource_klass, resource_id, association_type, key, key_values)
        @resource_id = resource_id
        @key = key
        @key_values = key_values
        @association_type = association_type
        super(resource_klass)
      end
    end

    class RemoveHasManyAssociationOperation < Operation
      attr_reader :resource_id, :association_type, :associated_key

      def initialize(resource_klass, resource_id, association_type, associated_key)
        @resource_id = resource_id
        @associated_key = associated_key
        @association_type = association_type
        super(resource_klass)
      end
    end

    class RemoveHasOneAssociationOperation < Operation
      attr_reader :resource_id, :association_type

      def initialize(resource_klass, resource_id, association_type)
        @resource_id = resource_id
        @association_type = association_type
        super(resource_klass)
      end
    end
  end
end