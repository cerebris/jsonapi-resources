require 'json/api/resource_for'
require 'json/api/resource_serializer'
require 'action_controller'
require 'json/api/exceptions'
require 'json/api/error'
require 'json/api/error_codes'
require 'json/api/request'
require 'json/api/operations_processor'
require 'csv'

module JSON
  module API
    class ResourceController < ActionController::Base
      include ResourceFor

      before_filter {
        @request = JSON::API::Request.new(resource_klass, params)
        render_errors(@request.errors) unless @request.errors.empty?
      }

      def index
        render json: JSON::API::ResourceSerializer.new.serialize(
            resource_klass.find({filters: @request.filters}, find_options),
            {include: @request.includes,
            fields: @request.fields}.merge(serialize_options)
        )
      rescue JSON::API::Exceptions::Error => e
        render_errors(e.errors)
      end

      def show
        ids = parse_id_array(params[resource_klass._key])

        resources = []
        ids.each do |id|
          resources.push(resource_klass.find_by_key(id, find_options))
        end

        render json: JSON::API::ResourceSerializer.new.serialize(
            resources,
            {include: @request.includes,
             fields: @request.fields}.merge(serialize_options)
        )
      rescue JSON::API::Exceptions::Error => e
        render_errors(e.errors)
      end

      def create
        options = {batch: true,
                   include: @request.includes,
                   fields: @request.fields}.merge(serialize_options).merge(update_options)

        process_operations(options)
      end

      def update
        options = {batch: true,
                   include: @request.includes,
                   fields: @request.fields}.merge(serialize_options).merge(update_options)

        process_operations(options)
      end

      def destroy
        process_operations({batch: true})
      end

      private
      if RUBY_VERSION >= '2.0'
        def resource_klass
          @resource_klass ||= Object.const_get resource_klass_name
        end
      else
        def resource_klass
          @resource_klass ||= resource_klass_name.safe_constantize
        end
      end

      def resource_klass_name
        @resource_klass_name ||= "#{self.class.name.demodulize.sub(/Controller$/, '').singularize}Resource"
      end

      def parse_id_array(raw)
        ids = []
        raw.split(/,/).collect do |id|
          ids.push resource_klass.verify_id(id)
        end
        return ids
      end

      # override to set standard serializer options
      def serialize_options
        {}
      end

      # override to set standard update options
      def update_options
        {}
      end

      # override to set standard find options
      def find_options
        {}
      end

      def before_create(checked_params, checked_associations)
      end

      def before_update(obj, checked_params, checked_associations)
      end

      def before_destroy(obj)
      end

      def transaction
        ActiveRecord::Base.transaction do
          yield
        end
      end

      def transaction_rollback
        raise ActiveRecord::Rollback
      end

      def render_errors(errors, status = :bad_request)
        render(json: {errors: errors}, status: errors.count == 1 ? errors[0].status : status)
      end

      def process_operations(options = {})
        op = JSON::API::OperationsProcessor.new(method(:transaction), method(:transaction_rollback))
        results = op.process(@request.operations, options)

        errors = []
        result_hash = {}
        resources = []

        results.each do |result|
          if result.has_errors?
            errors.concat(result.errors)
          else
            resources.push(result.resource) unless result.resource.nil?
            result_hash.merge!(result.result)
          end
        end

        if errors.count > 0
          render :status => errors.count == 1 ? errors[0].status : :bad_request, json: {errors: errors}
        else
          if options[:batch]
            render :status => results[0].code, json: JSON::API::ResourceSerializer.new.serialize(resources, options)
          else
            render :status => results.count == 1 ? results[0].code : :ok, json: result_hash
          end
        end
      end
    end
  end
end
