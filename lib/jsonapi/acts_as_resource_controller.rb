require 'csv'

module JSONAPI
  module ActsAsResourceController
    MEDIA_TYPE_MATCHER = /.+".+"[^,]*|[^,]+/
    ALL_MEDIA_TYPES = '*/*'

    def self.included(base)
      base.extend ClassMethods
      base.include Callbacks
      base.cattr_reader :server_error_callbacks
      base.define_jsonapi_resources_callbacks :process_operations,
                                              :transaction,
                                              :rollback
    end

    attr_reader :response_document

    def index
      process_request
    end

    def show
      process_request
    end

    def show_relationship
      process_request
    end

    def create
      process_request
    end

    def create_relationship
      process_request
    end

    def update_relationship
      process_request
    end

    def update
      process_request
    end

    def destroy
      process_request
    end

    def destroy_relationship
      process_request
    end

    def get_related_resource
      process_request
    end

    def get_related_resources
      process_request
    end

    def operations
      process_request
    end

    def process_request
      @response_document = create_response_document

      unless verify_content_type_header && verify_accept_header
        render_response_document
        return
      end

      request_parser = JSONAPI::RequestParser.new(
          params,
          response_document: @response_document,
          content_type: request.content_type,
          context: context,
          allowed_resource_types: allowed_operation_resource_types,
          key_formatter: key_formatter,
          server_error_callbacks: (self.class.server_error_callbacks || []))

      transactional = request_parser.transactional?

      force_rollback = false
      run_in_transaction(transactional) do
        begin
          run_callbacks :process_operations do
            begin
              request_parser.each do |op|
                op.options[:serializer] = resource_serializer_klass.new(
                    op.resource_klass,
                    include_directives: op.options[:include_directives],
                    fields: op.options[:fields],
                    base_url: base_url,
                    key_formatter: key_formatter,
                    route_formatter: route_formatter,
                    serialization_options: serialization_options
                )
                op.options[:cache_serializer_output] = !JSONAPI.configuration.resource_cache.nil?

                process_operation(op)
              end
            rescue => e
              handle_exceptions(e)
            end
          end
        rescue => e
          force_rollback = true
          raise e
        ensure
          if response_document.has_errors? || force_rollback
            rollback_transaction(transactional)
          end
        end
      end
      render_response_document
    end

    def run_in_transaction(transactional)
      if transactional
        run_callbacks :transaction do
          transaction do
            yield
          end
        end
      else
        yield
      end
    end

    def rollback_transaction(transactional)
      if transactional
        run_callbacks :rollback do
          rollback
        end
      end
    end

    def process_operation(operation)
      result = operation.process
      response_document.add_result(result, operation)
    end

    def transaction
      ActiveRecord::Base.transaction do
        yield
      end
    end

    def rollback
      fail ActiveRecord::Rollback
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

    def verify_content_type_header
      if params[:action] == 'operations'
        unless request.content_type == JSONAPI::OPERATIONS_MEDIA_TYPE
          fail JSONAPI::Exceptions::UnsupportedMediaTypeError.new(request.content_type)
        end
      else
        if ['create', 'create_relationship', 'update_relationship', 'update'].include?(params[:action])
          unless request.content_type == JSONAPI::MEDIA_TYPE
            fail JSONAPI::Exceptions::UnsupportedMediaTypeError.new(request.content_type)
          end
        end
      end
      true
    rescue => e
      handle_exceptions(e)
      false
    end

    def verify_accept_header
      unless valid_accept_media_type?
        fail JSONAPI::Exceptions::NotAcceptableError.new(request.accept)
      end
      true
    rescue => e
      handle_exceptions(e)
      false
    end

    def valid_accept_media_type?
      media_types = media_types_for('Accept')

      media_types.blank? || media_types.any? do |media_type|
        if request.content_type == JSONAPI::OPERATIONS_MEDIA_TYPE
          (media_type == JSONAPI::OPERATIONS_MEDIA_TYPE || media_type.start_with?(ALL_MEDIA_TYPES))
        else
          (media_type == JSONAPI::MEDIA_TYPE || media_type.start_with?(ALL_MEDIA_TYPES))
        end
      end
    end

  def media_types_for(header)
      (request.headers[header] || '')
        .scan(MEDIA_TYPE_MATCHER)
        .to_a
        .map(&:strip)
    end

    # override to set context
    def context
      {}
    end

    def allowed_operation_resource_types
      [ resource_klass._type ]
    end

    def serialization_options
      {}
    end

    # Control by setting in an initializer:
    #     JSONAPI.configuration.json_key_format = :camelized_key
    #     JSONAPI.configuration.route = :camelized_route
    #
    # Override if you want to set a per controller key format.
    # Must return an instance of a class derived from KeyFormatter.
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
      base_response_meta
    end

    def base_response_links
      {}
    end

    def render_response_document
      if request.content_type == JSONAPI::OPERATIONS_MEDIA_TYPE
        content = response_document.contents

        render_options = {}
        if response_document.has_errors?
          render_options[:json] = content
          status = 400
        else
          render_options[:body] = JSON.generate(content)
          status = 200
        end

        # For whatever reason, `render` ignores :status and :content_type when :body is set.
        # But, we can just set those values directly in the Response object instead.
        response.status = status
        response.headers['Content-Type'] = JSONAPI::OPERATIONS_MEDIA_TYPE

        render(render_options)
      else
        content = response_document.contents

        render_options = {}
        if response_document.has_errors?
          render_options[:json] = content
        else
          # Bypasing ActiveSupport allows us to use CompiledJson objects for cached response fragments
          render_options[:body] = JSON.generate(content)

          render_options[:location] = content['data']['links']['self'] if (response_document.status == 201 && content[:data].class != Array)
        end

        # For whatever reason, `render` ignores :status and :content_type when :body is set.
        # But, we can just set those values directly in the Response object instead.
        response.status = response_document.status
        response.headers['Content-Type'] = JSONAPI::MEDIA_TYPE

        render(render_options)
      end
    end

    def create_response_document
      JSONAPI::ResponseDocument.new(
          key_formatter: key_formatter,
          base_meta: base_meta,
          base_links: base_response_links,
          request: request,
          content_type: request.content_type
      )
    end

    # override this to process other exceptions
    # Note: Be sure to either call super(e) or handle JSONAPI::Exceptions::Error and raise unhandled exceptions
    def handle_exceptions(e)
      case e
        when JSONAPI::Exceptions::Error
          errors = e.errors
        when ActionController::ParameterMissing
          errors = JSONAPI::Exceptions::ParameterMissing.new(e.param).errors
        else
          if JSONAPI.configuration.exception_class_whitelisted?(e)
            fail e
          else
            if self.class.server_error_callbacks
              self.class.server_error_callbacks.each { |callback|
                safe_run_callback(callback, e)
              }
            end

            internal_server_error = JSONAPI::Exceptions::InternalServerError.new(e)
            Rails.logger.error { "Internal Server Error: #{e.message} #{e.backtrace.join("\n")}" }
            errors = internal_server_error.errors
          end
      end

      response_document.add_result(JSONAPI::ErrorsOperationResult.new(errors[0].status, errors), nil)
    end

    def safe_run_callback(callback, error)
      begin
        callback.call(error)
      rescue => e
        Rails.logger.error { "Error in error handling callback: #{e.message} #{e.backtrace.join("\n")}" }
        internal_server_error = JSONAPI::Exceptions::InternalServerError.new(e)
        return JSONAPI::ErrorsOperationResult.new(internal_server_error.errors[0].code, internal_server_error.errors)
      end
    end

    # Pass in a methods or a block to be run when an exception is
    # caught that is not a JSONAPI::Exceptions::Error
    # Useful for additional logging or notification configuration that
    # would normally depend on rails catching and rendering an exception.
    # Ignores whitelist exceptions from config

    module ClassMethods

      def on_server_error(*args, &callback_block)
        callbacks ||= []

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
        self.class_variable_set :@@server_error_callbacks, callbacks
      end

    end
  end
end
