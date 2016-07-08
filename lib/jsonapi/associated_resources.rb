module JSONAPI
  class AssociatedResources
    class << self
      def associated_resources_for(resource, relationship_name, options = {})
        relationship = resource._relationships[relationship_name]
        associated_records_method_name = case relationship
                                           when JSONAPI::Relationship::ToOne then "record_for_#{relationship_name}"
                                           when JSONAPI::Relationship::ToMany then "records_for_#{relationship_name}"
                                         end
        if relationship.is_a?(JSONAPI::Relationship::ToOne)
          if relationship.belongs_to?
            _associated_resource_for_belongs_to(resource, relationship, associated_records_method_name, options)
          else
            _associated_resource_for_has_one(resource, relationship, associated_records_method_name, options)
          end

        elsif relationship.is_a?(JSONAPI::Relationship::ToMany)
          _associated_resources_for_has_many(resource, relationship, associated_records_method_name, options)
        end

      end

      def associated_foreign_keys_for(resource, relationship_name)
        relationship = resource._relationships[relationship_name]
        foreign_key = relationship.foreign_key
        associated_records_method_name = case relationship
                                           when JSONAPI::Relationship::ToOne then "record_for_#{relationship_name}"
                                           when JSONAPI::Relationship::ToMany then "records_for_#{relationship_name}"
                                         end
        if relationship.is_a?(JSONAPI::Relationship::ToOne)
          if relationship.belongs_to?
            _associated_foreign_key_for_belongs_to(resource, relationship, associated_records_method_name)
          else
            _associated_foreign_key_for_has_one(resource, relationship, associated_records_method_name)
          end
        elsif relationship.is_a?(JSONAPI::Relationship::ToMany)
          _associated_foreign_keys_for_has_many(resource, relationship, associated_records_method_name)
        end
      end

      private

      def _associated_foreign_key_for_belongs_to(resource, relationship, associated_records_method_name)
        resource._model.respond_to?(relationship.foreign_key) ? resource._model.method(relationship.foreign_key).call : resource.associated_foreign_keys_for(relationship.name.to_sym)
      end

      def _associated_foreign_key_for_has_one(resource, relationship, associated_records_method_name)
        record = resource.respond_to?(associated_records_method_name) ? resource.public_send(associated_records_method_name) : resource.associated_records_for(relationship.name.to_sym)
        return nil if record.nil?
        record.public_send(relationship.resource_klass._primary_key)
      end

      def _associated_foreign_keys_for_has_many(resource, relationship, associated_records_method_name)
        records = resource.respond_to?(associated_records_method_name) ? resource.public_send(associated_records_method_name) : resource.associated_records_for(relationship.name.to_sym)
        return records.collect do |record|
          record.public_send(relationship.resource_klass._primary_key)
        end
      end

      def _associated_resource_for_belongs_to(resource, relationship, associated_records_method_name = nil, options = {})
        if relationship.polymorphic?
          associated_model = associated_records_method_name.nil? ? resource.associated_records_for(relationship_name) : resource.public_send(associated_records_method_name)
          resource_klass = resource.class.resource_for_model(associated_model) if associated_model
          return resource_klass.new(associated_model, @context) if resource_klass
        else
          resource_klass = relationship.resource_klass
          if resource_klass
            associated_model = resource.respond_to?(associated_records_method_name) ? resource.public_send(associated_records_method_name) : resource.associated_records_for(relationship_name)
            return associated_model ? resource_klass.new(associated_model, @context) : nil
          end
        end

      end

      def _associated_resource_for_has_one(resource, relationship, associated_records_method_name = nil, options = {})
        resource_klass = relationship.resource_klass
        if resource_klass
          associated_model = resource.respond_to?(associated_records_method_name) ? resource.public_send(associated_records_method_name) : resource.associated_records_for(relationship_name)
              return associated_model ? resource_klass.new(associated_model, @context) : nil
        end
      end

      def _associated_resources_for_has_many(resource, relationship, associated_records_method_name = nil, options = {})
        resource_klass = relationship.resource_klass
        records = resource.respond_to?(associated_records_method_name) ? resource.public_send(associated_records_method_name) : resource.associated_records_for(relationship.name.to_sym)

        filters = options.fetch(:filters, {})
        unless filters.nil? || filters.empty?
          records = resource_klass.apply_filters(records, filters, options)
        end

        sort_criteria =  options.fetch(:sort_criteria, {})
        unless sort_criteria.nil? || sort_criteria.empty?
          order_options = relationship.resource_klass.construct_order_options(sort_criteria)
          records = resource_klass.apply_sort(records, order_options, @context)
        end

        paginator = options[:paginator]
        if paginator
          records = resource_klass.apply_pagination(records, paginator, order_options)
        end

        return records.collect do |record|
          if relationship.polymorphic?
            resource_klass = resource.class.resource_for_model(record)
          end
          resource_klass.new(record, @context)
        end
      end

    end

  end
end