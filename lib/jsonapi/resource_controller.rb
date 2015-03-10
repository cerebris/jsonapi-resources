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
    before_filter :ensure_correct_media_type, only: [:create, :update, :create_association, :update_association]
    before_filter :setup_request
    after_filter :setup_response

    def index
      serializer = JSONAPI::ResourceSerializer.new(resource_klass,
                                                   include: @request.include,
                                                   fields: @request.fields,
                                                   base_url: base_url,
                                                   key_formatter: key_formatter,
                                                   route_formatter: route_formatter)

      resource_records = resource_klass.find(resource_klass.verify_filters(@request.filters, context),
                                             context: context,
                                             sort_criteria: @request.sort_criteria,
                                             paginator: @request.paginator)

      render json: serializer.serialize_to_hash(resource_records)
    rescue => e
      handle_exceptions(e)
    end

    def show
      serializer = JSONAPI::ResourceSerializer.new(resource_klass,
                                                   include: @request.include,
                                                   fields: @request.fields,
                                                   base_url: base_url,
                                                   key_formatter: key_formatter,
                                                   route_formatter: route_formatter)

      key = resource_klass.verify_key(params[resource_klass._primary_key], context)

      resource_record = resource_klass.find_by_key(key, context: context)

      render json: serializer.serialize_to_hash(resource_record)
    rescue => e
      handle_exceptions(e)
    end

    def show_association
      association_type = params[:association]

      parent_key = params[resource_klass._as_parent_key]

      parent_resource = resource_klass.find_by_key(parent_key, context: context)

      association = resource_klass._association(association_type)

      serializer = JSONAPI::ResourceSerializer.new(resource_klass,
                                                   fields: @request.fields,
                                                   base_url: base_url,
                                                   key_formatter: key_formatter,
                                                   route_formatter: route_formatter)

      render json: serializer.serialize_to_links_hash(parent_resource, association)
    rescue => e
      # :nocov:
      handle_exceptions(e)
      # :nocov:
    end

    def create
      process_request_operations
    end

    def create_association
      process_request_operations
    end

    def update_association
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

    def get_related_resource
      association_type = params[:association]
      source_resource = @request.source_klass.find_by_key(@request.source_id, context: context)

      serializer = JSONAPI::ResourceSerializer.new(@request.source_klass,
                                                   include: @request.include,
                                                   fields: @request.fields,
                                                   base_url: base_url,
                                                   key_formatter: key_formatter,
                                                   route_formatter: route_formatter)

      render json: serializer.serialize_to_hash(source_resource.send(association_type))
    end

    def get_related_resources
      association_type = params[:association]
      source_resource = @request.source_klass.find_by_key(@request.source_id, context: context)

      related_resources = source_resource.send(association_type,
                                               {
                                                 filters:  @request.source_klass.verify_filters(@request.filters, context),
                                                 sort_criteria: @request.sort_criteria,
                                                 paginator: @request.paginator
                                               })

      serializer = JSONAPI::ResourceSerializer.new(@request.source_klass,
                                                   include: @request.include,
                                                   fields: @request.fields,
                                                   base_url: base_url,
                                                   key_formatter: key_formatter,
                                                   route_formatter: route_formatter)

      render json: serializer.serialize_to_hash(related_resources)
    end

    # Override this to use another operations processor
    def create_operations_processor
      JSONAPI::ActiveRecordOperationsProcessor.new
    end

    private
    def resource_klass
      @resource_klass ||= resource_klass_name.safe_constantize
    end

    def base_url
      @base_url ||= request.protocol + request.host_with_port
    end

    def resource_klass_name
      @resource_klass_name ||= "#{self.class.name.sub(/Controller$/, '').singularize}Resource"
    end

    def ensure_correct_media_type
      unless request.content_type == JSONAPI::MEDIA_TYPE
        raise JSONAPI::Exceptions::UnsupportedMediaTypeError.new(request.content_type)
      end
    rescue => e
      # :nocov:
      handle_exceptions(e)
      # :nocov:
    end

    def setup_request
      @request = JSONAPI::Request.new(params, {
        context: context,
        key_formatter: key_formatter
      })
      render_errors(@request.errors) unless @request.errors.empty?
    rescue => e
      # :nocov:
      handle_exceptions(e)
      # :nocov:
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

    def render_errors(errors)
      render(json: {errors: errors}, status: errors[0].status)
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
        render status: errors[0].status, json: {errors: errors}
      else
        if results.length > 0 && resources.length > 0
          serializer = JSONAPI::ResourceSerializer.new(resource_klass,
                                                       include: @request.include,
                                                       fields: @request.fields,
                                                       base_url: base_url,
                                                       key_formatter: key_formatter,
                                                       route_formatter: route_formatter)

          render status: results[0].code,
                 json: serializer.serialize_to_hash(resources.length > 1 ? resources : resources[0])
        else
          render status: results[0].code, json: nil
        end
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
          # :nocov:
          raise e
          # :nocov:
      end
    end
  end
end
