# frozen_string_literal: true

module JSONAPI
  module Utils
    module PolymorphicTypesLookup
      extend self

      def polymorphic_types(name, rebuild: false)
        polymorphic_types_lookup(rebuild: rebuild).fetch(name.to_sym) do
          klass = name.classify.safe_constantize
          if klass.nil?
            warn "[POLYMORPHIC TYPE NOT FOUND] No polymorphic types found for #{name}"
          else
            polymorphic_type = format_polymorphic_klass_type(klass)
            warn "[POLYMORPHIC TYPE] Found polymorphic types through reflection for #{name}: #{polymorphic_type}"
            polymorphic_types_lookup[name.to_sym] = [polymorphic_type]
          end
        end
      end

      def polymorphic_types_lookup(rebuild: false)
        polymorphic_types_lookup_clear! if rebuild
        @polymorphic_types_lookup ||= build_polymorphic_types_lookup
      end

      def polymorphic_types_lookup_clear!
        @polymorphic_types_lookup = nil
      end

      def build_polymorphic_types_lookup
        public_send(build_polymorphic_types_lookup_strategy)
      end

      def build_polymorphic_types_lookup_strategy
        :build_polymorphic_types_lookup_from_object_space
      end

      def build_polymorphic_types_lookup_from_descendants
        {}.tap do |lookup|
          ActiveRecord::Base
            .descendants
            .select(&:name)
            .reject(&:abstract_class)
            .select(&:model_name).map {|klass|
              add_polymorphic_types_lookup(klass: klass, lookup: lookup)
            }
        end
      end

      def build_polymorphic_types_lookup_from_object_space
        {}.tap do |lookup|
          ObjectSpace.each_object do |klass|
            next unless Module === klass
            is_active_record_inspectable = ActiveRecord::Base > klass
            is_active_record_inspectable &&= klass.respond_to?(:reflect_on_all_associations, true)
            is_active_record_inspectable &&= format_polymorphic_klass_type(klass).present?
            if is_active_record_inspectable
              add_polymorphic_types_lookup(klass: klass, lookup: lookup)
            end
          end
        end
      end

      def add_polymorphic_types_lookup(klass:, lookup:)
        klass.reflect_on_all_associations(:has_many).select { |r| r.options[:as] }.each do |reflection|
          (lookup[reflection.options[:as]] ||= []) << format_polymorphic_klass_type(klass).underscore
        end
      end

      def format_polymorphic_klass_type(klass)
        klass.name ||
          begin
            klass.model_name.name
          rescue ArgumentError => ex
            # klass.base_class may be nil
            warn "[POLYMORPHIC TYPE] #{__callee__} #{klass} #{ex.inspect}"
            nil
          end
      end
    end
  end
end
