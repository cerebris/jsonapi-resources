require 'csv'

module JSONAPI
  module ActsAsResourceController
    extend ActiveSupport::Concern

    included do
      before_filter :ensure_correct_media_type, only: [:create, :update, :create_association, :update_association]
      before_filter :setup_request
      after_filter :setup_response
    end

    def index
      serializer = JSONAPI::ResourceSerializer.new(resource_klass,
                                                   include: @request.include,
                                                   include_directives: @request.include_directives,
                                                   fields: @request.fields,
                                                   base_url: base_url,
                                                   key_formatter: key_formatter,
                                                   route_formatter: route_formatter)

      resource_records = resource_klass.find(resource_klass.verify_filters(@request.filters, context),
                                             context: context,
                                             include_directives: @request.include_directives,
                                             sort_criteria: @request.sort_criteria,
                                             paginator: @request.paginator)

      render json: serializer.serialize_to_hash(resource_records)
    rescue => e
      handle_exceptions(e)
    end

    def show
      serializer = JSONAPI::ResourceSerializer.new(resource_klass,
                                                   include: @request.include,
                                                   include_directives: @request.include_directives,
                                                   fields: @request.fields,
                                                   base_url: base_url,
                                                   key_formatter: key_formatter,
                                                   route_formatter: route_formatter)

      key = resource_klass.verify_key(params[:id], context)

      resource_record = resource_klass.find_by_key(key,
                                                   context: context,
                                                   include_directives: @request.include_directives)

      render json: serializer.serialize_to_hash(resource_record)
    rescue => e
      handle_exceptions(e)
    end

    def show_association
      association_type = params[:association]

      parent_key = resource_klass.verify_key(params[resource_klass._as_parent_key], context)

      parent_resource = resource_klass.find_by_key(parent_key, context: context)

      association = resource_klass._association(association_type)

      serializer = JSONAPI::ResourceSerializer.new(resource_klass,
                                                   fields: @request.fields,
                                                   include_directives: @request.include_directives,
                                                   base_url: base_url,
                                                   key_formatter: key_formatter,
                                                   route_formatter: route_formatter)

      render json: serializer.serialize_to_links_hash(parent_resource, association)
    rescue => e
      handle_exceptions(e)
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
      @resource_klass_name ||= "#{self.class.name.underscore.sub(/_controller$/, '').singularize}_resource".camelize
    end

    def ensure_correct_media_type
      unless request.content_type == JSONAPI::MEDIA_TYPE
        raise JSONAPI::Exceptions::UnsupportedMediaTypeError.new(request.content_type)
      end
    rescue => e
      handle_exceptions(e)
    end

    def setup_request
      @request = JSONAPI::Request.new(params, {
                                              context: context,
                                              key_formatter: key_formatter
                                            })
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

    def render_errors(errors)
      render(json: {errors: errors}, status: errors[0].status)
    end

    def process_request_operations
      results   = create_operations_processor.process(@request)
      errors    = results.select(&:has_errors?).flat_map(&:errors).compact
      resources = results.reject(&:has_errors?).flat_map(&:resource).compact

      status, json = case
                       when errors.any?
                         [errors[0].status, {errors: errors}]
                       when results.any? && resources.any?
                         res = resources.length > 1 ? resources : resources[0]
                         [results[0].code, processing_serializer.serialize_to_hash(res)]
                       else
                         [results[0].code, nil]
                     end

      render status: status, json: json
    rescue => e
      handle_exceptions(e)
    end

    def processing_serializer
      JSONAPI::ResourceSerializer.new(resource_klass,
                                      include: @request.include,
                                      fields: @request.fields,
                                      base_url: base_url,
                                      key_formatter: key_formatter,
                                      route_formatter: route_formatter)
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
