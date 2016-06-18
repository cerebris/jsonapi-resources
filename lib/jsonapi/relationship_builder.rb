require 'pry'

module JSONAPI
  class RelationshipBuilder
    attr_reader :_model_class, :options

    class DefinitionProxy
      def initialize(target)
        @target = target
      end

      def define_method(name, &body)
        @target.inject_class_method(name, body)
      end

      def method_defined?(name)
        @target.method_defined?(name)
      end
    end

    def initialize(relationship_class, options, model_class, resource_relationships, resource_klass)
      @relationship_class = relationship_class
      @options = options
      @_model_class = model_class
      @_relationships = resource_relationships
      @resource_klass = resource_klass
    end

    #TODO change reference in code once refactor is complete
    def klass
      @relationship_class
    end

    def target_resource
      @proxy ||= DefinitionProxy.new(@resource_klass)
    end

    def build_relationship(attrs)
        attrs.each do |attr|
          relationship_name = attr.to_sym

          @resource_klass.check_reserved_relationship_name(relationship_name)

          # Initialize from an ActiveRecord model's properties
          if _model_class && _model_class.ancestors.collect{|ancestor| ancestor.name}.include?('ActiveRecord::Base')
            model_association = _model_class.reflect_on_association(relationship_name)
            if model_association
              options[:class_name] ||= model_association.class_name
            end
          end

          @_relationships[relationship_name] = relationship = klass.new(relationship_name, options)

          associated_records_method_name = case relationship
                                           when JSONAPI::Relationship::ToOne then "record_for_#{relationship_name}"
                                           when JSONAPI::Relationship::ToMany then "records_for_#{relationship_name}"
                                           end

          foreign_key = relationship.foreign_key

          target_resource.define_method "#{foreign_key}=" do |value|
            @model.method("#{foreign_key}=").call(value)
          end unless target_resource.method_defined?("#{foreign_key}=")

          target_resource.define_method associated_records_method_name do
            relationship = self.class._relationships[relationship_name]
            relation_name = relationship.relation_name(context: @context)
            records_for(relation_name)
          end unless target_resource.method_defined?(associated_records_method_name)

          if relationship.is_a?(JSONAPI::Relationship::ToOne)
            if relationship.belongs_to?
              target_resource.define_method foreign_key do
                @model.method(foreign_key).call
              end unless target_resource.method_defined?(foreign_key)

              target_resource.define_method relationship_name do |options = {}|
                relationship = self.class._relationships[relationship_name]

                if relationship.polymorphic?
                  associated_model = public_send(associated_records_method_name)
                  resource_klass = self.class.resource_for_model(associated_model) if associated_model
                  return resource_klass.new(associated_model, @context) if resource_klass
                else
                  resource_klass = relationship.resource_klass
                  if resource_klass
                    associated_model = public_send(associated_records_method_name)
                    return associated_model ? resource_klass.new(associated_model, @context) : nil
                  end
                end
              end unless target_resource.method_defined?(relationship_name)
            else
              target_resource.define_method foreign_key do
                relationship = self.class._relationships[relationship_name]

                record = public_send(associated_records_method_name)
                return nil if record.nil?
                record.public_send(relationship.resource_klass._primary_key)
              end unless target_resource.method_defined?(foreign_key)

              target_resource.define_method relationship_name do |options = {}|
                relationship = self.class._relationships[relationship_name]

                resource_klass = relationship.resource_klass
                if resource_klass
                  associated_model = public_send(associated_records_method_name)
                  return associated_model ? resource_klass.new(associated_model, @context) : nil
                end
              end unless target_resource.method_defined?(relationship_name)
            end
          elsif relationship.is_a?(JSONAPI::Relationship::ToMany)
            target_resource.define_method foreign_key do
              records = public_send(associated_records_method_name)
              return records.collect do |record|
                record.public_send(relationship.resource_klass._primary_key)
              end
            end unless target_resource.method_defined?(foreign_key)

            target_resource.define_method relationship_name do |options = {}|
              relationship = self.class._relationships[relationship_name]

              resource_klass = relationship.resource_klass
              records = public_send(associated_records_method_name)

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
                  resource_klass = self.class.resource_for_model(record)
                end
                resource_klass.new(record, @context)
              end
            end unless target_resource.method_defined?(relationship_name)
          end
        end
    end
  end
end
