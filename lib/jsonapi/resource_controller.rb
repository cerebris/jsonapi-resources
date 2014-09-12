require 'jsonapi/resource_for'
require 'jsonapi/resource_serializer'
require 'action_controller'
require 'jsonapi/exceptions'
require 'jsonapi/error'
require 'jsonapi/error_codes'
require 'jsonapi/request'
require 'jsonapi/operations_processor'
require 'jsonapi/active_record_operations_processor'
require 'csv'

module JSONAPI
  class ResourceController < ActionController::Base
    include ResourceFor

    before_filter {
      begin
        @request = JSONAPI::Request.new(context, params, key_formatter)
        render_errors(@request.errors) unless @request.errors.empty?
      rescue => e
        handle_exceptions(e)
      end
    }

    def index
      render json: JSONAPI::ResourceSerializer.new.serialize_to_hash(
          resource_klass.find(resource_klass.verify_filters(@request.filters, context), context),
          include: @request.include,
          fields: @request.fields,
          context: context,
          attribute_formatters: attribute_formatters,
          key_formatter: key_formatter)
    rescue => e
      handle_exceptions(e)
    end

    def show
      keys = parse_key_array(params[resource_klass._key])

      resources = []
      keys.each do |key|
        resources.push(resource_klass.find_by_key(key, context))
      end

      render json: JSONAPI::ResourceSerializer.new.serialize_to_hash(
          resources,
          include: @request.include,
          fields: @request.fields,
          context: context,
          attribute_formatters: attribute_formatters,
          key_formatter: key_formatter)
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
      JSONAPI::ActiveRecordOperationsProcessor.new
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

    # Control by setting in an initializer:
    #     JSONAPI.configuration.json_key_format = :camelized
    #
    # Override if you want to set a per controller key format. Must return a Proc
    def key_formatter
      case JSONAPI.configuration.json_key_format
        when :underscored
          lambda{|key| key.to_s.underscore}
        when :camelized
          lambda{|key| key.to_s.camelize(:lower)}
        when :dasherized
          lambda{|key| key.to_s.dasherize}
        when Proc
          JSONAPI.configuration.json_key_format
      end
    end

    # override to setup custom attribute_formatters
    def attribute_formatters
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
        render :status => results[0].code,
               json: JSONAPI::ResourceSerializer.new.serialize_to_hash(resources,
                                                                       include: @request.include,
                                                                       fields: @request.fields,
                                                                       context: context,
                                                                       attribute_formatters: attribute_formatters,
                                                                       key_formatter: key_formatter)
      end
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
          raise e
      end
    end
  end
end