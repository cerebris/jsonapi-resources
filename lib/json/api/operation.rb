module JSON
  module API
    class Operation

      attr_reader :resource_klass

      def initialize(resource_klass)
        @resource_klass = resource_klass
      end

      def apply(context)
      end
    end

    class AddResourceOperation < Operation
      attr_reader :values

      def initialize(resource_klass, values = {})
        @values = values
        super(resource_klass)
      end

      def apply(context)
        resource = @resource_klass.new
        resource.update_values(@values)
        resource.save

        return JSON::API::OperationResult.new(:created, resource)

      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, e.errors)
      end
    end

    class RemoveResourceOperation < Operation
      attr_reader :resource_id
      def initialize(resource_klass, resource_id)
        @resource_id = resource_id
        super(resource_klass)
      end

      def apply(context)
        resource = @resource_klass.find_by_key(@resource_id, context)
        resource.remove

        return JSON::API::OperationResult.new(:no_content)

      rescue ActiveRecord::DeleteRestrictionError => e
        record_locked_error = JSON::API::Exceptions::RecordLocked.new(e.message)
        return JSON::API::OperationResult.new(record_locked_error.errors[0].code, nil, record_locked_error.errors)
      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, e.errors)
      end
    end

    class ReplaceAttributesOperation < Operation
      attr_reader :values, :resource_id

      def initialize(resource_klass, resource_id, values)
        @resource_id = resource_id
        @values = values
        super(resource_klass)
      end

      def apply(context)
        resource = @resource_klass.find_by_key(@resource_id, context)
        resource.update_values(values)
        resource.save

        return JSON::API::OperationResult.new(:ok, resource)

      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, e.errors)
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

      def apply(context)
        resource = @resource_klass.find_by_key(@resource_id, context)
        resource.create_has_one_link(@key, @key_value)

        return JSON::API::OperationResult.new(:created, resource)
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

      def apply(context)
        resource = @resource_klass.find_by_key(@resource_id, context)
        association = resource.class._association(@association_type)
        @key_values.each do |value|
          related_resource = Resource.resource_for(association.serialize_type_name).find_by_key(value, context)
          resource.create_has_many_link(@association_type, related_resource)
        end

        return JSON::API::OperationResult.new(:created, resource)
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

      def apply(context)
        resource = @resource_klass.find_by_key(@resource_id, context)
        resource.remove_has_many_link(@association_type, @associated_key)

        return JSON::API::OperationResult.new(:no_content)
      end

    end

    class RemoveHasOneAssociationOperation < Operation
      attr_reader :resource_id, :association_type

      def initialize(resource_klass, resource_id, association_type)
        @resource_id = resource_id
        @association_type = association_type
        super(resource_klass)
      end

      def apply(context)
        resource = @resource_klass.find_by_key(@resource_id, context)
        key = @resource_klass._association(@association_type).key
        resource.remove_has_one_link(key)

        return JSON::API::OperationResult.new(:no_content)
      end
    end
  end
end