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
        resource.replace_fields(@values, context)
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
        resource.remove(context)

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
        resource.replace_fields(values, context)
        resource.save

        return JSON::API::OperationResult.new(:ok, resource)

      rescue JSON::API::Exceptions::Error => e
        return JSON::API::OperationResult.new(e.errors.count == 1 ? e.errors[0].code : :bad_request, nil, e.errors)
      end
    end

    class AddHasOneAssociationOperation < Operation
      attr_reader :resource_id, :association_type, :key_value

      def initialize(resource_klass, resource_id, association_type, key_value)
        @resource_id = resource_id
        @key_value = key_value
        @association_type = association_type
        super(resource_klass)
      end

      def apply(context)
        resource = @resource_klass.find_by_key(@resource_id, context)
        resource.replace_has_one_link(@association_type, @key_value, context)
        resource.save

        return JSON::API::OperationResult.new(:created, resource)
      end
    end

    class AddHasManyAssociationOperation < Operation
      attr_reader :resource_id, :association_type, :key_values

      def initialize(resource_klass, resource_id, association_type, key_values)
        @resource_id = resource_id
        @key_values = key_values
        @association_type = association_type
        super(resource_klass)
      end

      def apply(context)
        resource = @resource_klass.find_by_key(@resource_id, context)
        @key_values.each do |value|
          resource.create_has_many_link(@association_type, value, context)
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
        resource.remove_has_many_link(@association_type, @associated_key, context)

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
        resource.remove_has_one_link(@association_type, context)
        resource.save

        return JSON::API::OperationResult.new(:no_content)
      end
    end
  end
end