require 'json/api/resource_for'
require 'json/api/resource_serializer'
require 'action_controller'
require 'json/api/exceptions'
require 'json/api/error'
require 'json/api/error_codes'
require 'json/api/request'
require 'json/api/operations_processor'
require 'json/api/active_record_operations_processor'
require 'csv'

module JSON
  module API
    class ResourceController < ActionController::Base
      include ResourceFor

      before_filter {
        begin
          @request = JSON::API::Request.new(context, params)
          render_errors(@request.errors) unless @request.errors.empty?
        rescue => e
          handle_exceptions(e)
        end
      }

      def index
        render json: JSON::API::ResourceSerializer.new.serialize(
            resource_klass.find(resource_klass.verify_filters(@request.filters, context), context),
            @request.includes,
            @request.fields,
            context)
      rescue => e
        handle_exceptions(e)
      end

      def show
        keys = parse_key_array(params[resource_klass._key])

        resources = []
        keys.each do |key|
          resources.push(resource_klass.find_by_key(key, context))
        end

        render json: JSON::API::ResourceSerializer.new.serialize(
            resources,
            @request.includes,
            @request.fields,
            context)
      rescue => e
        handle_exceptions(e)
      end

      def show_association
        association_type = params[:association]

        parent_key = params[resource_klass._as_parent_key]

        parent_resource = resource_klass.find_by_key(parent_key, context)

        association = resource_klass._association(association_type)
        render json: { association_type => parent_resource.send(association.key)}
      rescue => e
        handle_exceptions(e)
      end

      def create
        process_request_operations
      end

      def create_association
        process_request_operations
      end

      def update
        process_request_operations
      end

      def destroy
        process_request_operations
      end

      def destroy_association
        process_request_operations
      end

      # Override this to use another operations processor
      def create_operations_processor
        JSON::API::ActiveRecordOperationsProcessor.new
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

      def parse_key_array(raw)
        keys = []
        raw.split(/,/).collect do |key|
          keys.push resource_klass.verify_key(key, context)
        end
        return keys
      end

      # override to set context
      def context
        {}
      end

      def render_errors(errors, status = :bad_request)
        render(json: {errors: errors}, status: errors.count == 1 ? errors[0].status : status)
      end

      def process_request_operations
        op = create_operations_processor

        results = op.process(@request)

        errors = []
        resources = []

        results.each do |result|
          if result.has_errors?
            errors.concat(result.errors)
          else
            resources.push(result.resource) unless result.resource.nil?
          end
        end

        if errors.count > 0
          render :status => errors.count == 1 ? errors[0].status : :bad_request, json: {errors: errors}
        else
          # if patch
            render :status => results[0].code, json: JSON::API::ResourceSerializer.new.serialize(resources,
                                                                                                 @request.includes,
                                                                                                 @request.fields,
                                                                                                 context)
          # else
          #   result_hash = {}
          #   resources.each do |resource|
          #     result_hash.merge!(JSON::API::ResourceSerializer.new.serialize(resource, @request.includes, @request.fields, context))
          #   end
          #   render :status => results.count == 1 ? results[0].code : :ok, json: result_hash
          # end
        end
      rescue => e
        handle_exceptions(e)
      end

      # override this to process other exceptions
      # Note: Be sure to either call super(e) or handle JSON::API::Exceptions::Error and raise unhandled exceptions
      def handle_exceptions(e)
        case e
          when JSON::API::Exceptions::Error
            render_errors(e.errors)
          else # raise all other exceptions
            raise e
        end
      end
    end
  end
end
