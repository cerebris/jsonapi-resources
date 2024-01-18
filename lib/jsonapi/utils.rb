# frozen_string_literal: true

module JSONAPI
  module Utils
    extend self

    def polymorphic_types(name)
      @poly_hash ||= {}.tap do |hash|
        ObjectSpace.each_object do |klass|
          next unless Module === klass
          if ActiveRecord::Base > klass
            klass.reflect_on_all_associations(:has_many).select { |r| r.options[:as] }.each do |reflection|
              (hash[reflection.options[:as]] ||= []) << klass.name.underscore
            end
          end
        end
      end
      @poly_hash[name.to_sym]
    end
  end
end
