require 'csv'

module JSONAPI
  module ActsAsResourceController
    extend ActiveSupport::Concern

    included do
      before_filter :ensure_correct_media_type, only: [:create, :update, :create_relationship, :update_relationship]
      append_before_filter :setup_request
      after_filter :setup_response
    end

    def index
      process_request_operations
    end

    def show
      process_request_operations
    end

    def show_relationship
      process_request_operations
    end

    def create
      process_request_operations
    end

    def create_relationship
      process_request_operations
    end

    def update_relationship
      process_request_operations
    end

    def update
      process_request_operations
    end

    def destroy
      process_request_operations
    end

    def destroy_relationship
      process_request_operations
    end

    def get_related_resource
      process_request_operations
    end

    def get_related_resources
      process_request_operations
    end

    # set the operations processor in the configuration or override this to use another operations processor
    def create_operations_processor
      JSONAPI.configuration.operations_processor.new
    end

    private

    def resource_klass
      @resource_klass ||= resource_klass_name.safe_constantize
    end

    def resource_serializer_klass
      @resource_serializer_klass ||= JSONAPI::ResourceSerializer
    end

    def base_url
      @base_url ||= request.protocol + request.host_with_port
    end

    def resource_klass_name
      @resource_klass_name ||= "#{self.class.name.underscore.sub(/_controller$/, '').singularize}_resource".camelize
    end

    def ensure_correct_media_type
      unless request.content_type == JSONAPI::MEDIA_TYPE
        fail JSONAPI::Exceptions::UnsupportedMediaTypeError.new(request.content_type)
      end
    rescue => e
      handle_exceptions(e)
    end

    def setup_request
      @request = JSONAPI::Request.new(params, context: context, key_formatter: key_formatter)

      render_errors(@request.errors) unless @request.errors.empty?
    rescue => e
      handle_exceptions(e)
    end

    def setup_response
      if response.body.size > 0
        response.headers['Content-Type'] = JSONAPI::MEDIA_TYPE
      end
    end

    # override to set context
    def context
      {}
    end

    # Control by setting in an initializer:
    #     JSONAPI.configuration.json_key_format = :camelized_key
    #     JSONAPI.configuration.route = :camelized_route
    #
    # Override if you want to set a per controller key format.
    # Must return a class derived from KeyFormatter.
    def key_formatter
      JSONAPI.configuration.key_formatter
    end

    def route_formatter
      JSONAPI.configuration.route_formatter
    end

    def base_response_meta
      {}
    end

    def base_meta
      if @request.nil? || @request.warnings.empty?
        base_response_meta
      else
        base_response_meta.merge(warnings: @request.warnings)
      end
    end

    def base_response_links
      {}
    end

    def render_errors(errors)
      operation_results = JSONAPI::OperationResults.new
      result = JSONAPI::ErrorsOperationResult.new(errors[0].status, errors)
      operation_results.add_result(result)

      render_results(operation_results)
    end

    def render_results(operation_results)
      response_doc = create_response_document(operation_results)
      render status: response_doc.status, json: response_doc.contents
    end

    def create_response_document(operation_results)
      JSONAPI::ResponseDocument.new(
        operation_results,
        primary_resource_klass: resource_klass,
        include_directives: @request ? @request.include_directives : nil,
        fields: @request ? @request.fields : nil,
        base_url: base_url,
        key_formatter: key_formatter,
        route_formatter: route_formatter,
        base_meta: base_meta,
        base_links: base_response_links,
        resource_serializer_klass: resource_serializer_klass,
        request: @request
      )
    end

    def process_request_operations
      operation_results = create_operations_processor.process(@request)
      render_results(operation_results)
    rescue => e
      handle_exceptions(e)
    end

    # override this to process other exceptions
    # Note: Be sure to either call super(e) or handle JSONAPI::Exceptions::Error and raise unhandled exceptions
    def handle_exceptions(e)
      case e
      when JSONAPI::Exceptions::Error
        render_errors(e.errors)
      else # raise all other exceptions
        # :nocov:
        fail e
        # :nocov:
      end
    end

    def add_error_callbacks(callbacks)
      @request.server_error_callbacks = callbacks || []
    end

    # Pass in a methods or a block to be run when an exception is 
    # caught that is not a JSONAPI::Exceptions::Error
    # Useful for additional logging or notification configuration that 
    # would normally depend on rails catching and rendering an exception.
    # Ignores whitelist exceptions from config

    module ClassMethods
      def on_server_error(*args, &callback_block)
        callbacks = []

        if callback_block 
          callbacks << callback_block
        end

        method_callbacks = args.map do |method|
          ->(error) do 
            if self.respond_to? method
              send(method, error)
            else
              Rails.logger.warn("#{method} not defined on #{self}, skipping error callback")
            end
          end
        end.compact
        callbacks += method_callbacks
        append_before_filter { add_error_callbacks(callbacks) }
      end
    end
  end
end
