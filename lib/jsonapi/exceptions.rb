module JSONAPI
  module Exceptions
    class Error < RuntimeError; end

    class InternalServerError < Error
      attr_accessor :exception

      def initialize(exception)
        @exception = exception
      end

      def errors
        unless Rails.env.production?
          meta = Hash.new
          meta[:exception] = exception.message
          meta[:backtrace] = exception.backtrace
        end

        [JSONAPI::Error.new(code: JSONAPI::INTERNAL_SERVER_ERROR,
                            status: :internal_server_error,
                            title: I18n.translate('exceptions.internal_server_error.title'),
                            detail: I18n.translate('exceptions.internal_server_error.detail'),
                            meta: meta)]
      end
    end

    class InvalidResource < Error
      attr_accessor :resource
      def initialize(resource)
        @resource = resource
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_RESOURCE,
                            status: :bad_request,
                            title: I18n.translate('exceptions.invalid_resource.title'),
                            detail: I18n.translate('exceptions.invalid_resource.detail', resource: resource))]
      end
    end

    class RecordNotFound < Error
      attr_accessor :id
      def initialize(id)
        @id = id
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::RECORD_NOT_FOUND,
                            status: :not_found,
                            title: I18n.translate('exceptions.record_not_found.title'),
                            detail: I18n.translate('exceptions.record_not_found.detail', id: id))]
      end
    end

    class UnsupportedMediaTypeError < Error
      attr_accessor :media_type
      def initialize(media_type)
        @media_type = media_type
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::UNSUPPORTED_MEDIA_TYPE,
                            status: :unsupported_media_type,
                            title: I18n.translate('exceptions.unsupported_media_type.title'),
                            detail: I18n.translate("exceptions.unsupported_media_type.detail",
                                                   needed_media_type: JSONAPI::MEDIA_TYPE,
                                                   media_type: media_type))]
      end
    end

    class HasManyRelationExists < Error
      attr_accessor :id
      def initialize(id)
        @id = id
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::RELATION_EXISTS,
                            status: :bad_request,
                            title: I18n.translate('exceptions.has_many_relation.title'),
                            detail: I18n.translate('exceptions.has_many_relation.detail', id: id))]
      end
    end

    class ToManySetReplacementForbidden < Error
      def errors
        [JSONAPI::Error.new(code: JSONAPI::FORBIDDEN,
                            status: :forbidden,
                            title: I18n.translate('exceptions.to_many_set_replacement_forbidden.title'),
                            detail: I18n.translate('exceptions.to_many_set_replacement_forbidden.detail'))]
      end
    end

    class InvalidFiltersSyntax < Error
      attr_accessor :filters
      def initialize(filters)
        @filters = filters
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_FILTERS_SYNTAX,
                            status: :bad_request,
                            title: I18n.translate('exceptions.invalid_filter_syntax.title'),
                            detail: I18n.translate('exceptions.invalid_filter_syntax.title'))]
      end
    end

    class FilterNotAllowed < Error
      attr_accessor :filter
      def initialize(filter)
        @filter = filter
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::FILTER_NOT_ALLOWED,
                            status: :bad_request,
                            title: I18n.translate('exceptions.filter_not_allowed.title'),
                            detail: I18n.translate('exceptions.filter_not_allowed.detail', filter: filter))]
      end
    end

    class InvalidFilterValue < Error
      attr_accessor :filter, :value
      def initialize(filter, value)
        @filter = filter
        @value = value
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_FILTER_VALUE,
                            status: :bad_request,
                            title: I18n.translate('exceptions.invalid_filter_value.title'),
                            detail: I18n.translate('exceptions.invalid_filter_value.detail'),
                                                    value: value, filter: filter)]
      end
    end

    class InvalidFieldValue < Error
      attr_accessor :field, :value
      def initialize(field, value)
        @field = field
        @value = value
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_FIELD_VALUE,
                            status: :bad_request,
                            title: I18n.translate('exceptions.invalid_field_value.title'),
                            detail: I18n.translate('exceptions.invalid_field_value.detail',
                                                    value: value, field: field))]
      end
    end

    class InvalidFieldFormat < Error
      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_FIELD_FORMAT,
                            status: :bad_request,
                            title: I18n.translate('exceptions.invalid_field_format.title'),
                            detail: I18n.translate('exceptions.invalid_field_format.detail'))]
      end
    end

    class InvalidLinksObject < Error
      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_LINKS_OBJECT,
                            status: :bad_request,
                            title: I18n.translate('exceptions.invalid_links_object.title'),
                            detail: I18n.translate('exceptions.invalid_links_object.detail'))]
      end
    end

    class TypeMismatch < Error
      attr_accessor :type
      def initialize(type)
        @type = type
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::TYPE_MISMATCH,
                            status: :bad_request,
                            title: I18n.translate('exceptions.type_mismatch.title'),
                            detail: I18n.translate('exceptions.type_mismatch.detail', type: type))]
      end
    end

    class InvalidField < Error
      attr_accessor :field, :type
      def initialize(type, field)
        @field = field
        @type = type
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_FIELD,
                            status: :bad_request,
                            title: I18n.translate('exceptions.invalid_field.title'),
                            detail: I18n.translate('exceptions.invalid_field.detail',
                                                    field: field, type: type))]
      end
    end

    class InvalidInclude < Error
      attr_accessor :relationship, :resource
      def initialize(resource, relationship)
        @resource = resource
        @relationship = relationship
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_INCLUDE,
                            status: :bad_request,
                            title: I18n.translate('exceptions.invalid_include.title'),
                            detail: I18n.translate('exceptions.invalid_include.detail',
                                                    relationship: relationship, resource: resource))]
      end
    end

    class InvalidSortCriteria < Error
      attr_accessor :sort_criteria, :resource
      def initialize(resource, sort_criteria)
        @resource = resource
        @sort_criteria = sort_criteria
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_SORT_CRITERIA,
                            status: :bad_request,
                            title: I18n.translate('exceptions.invalid_sort_criteria.title'),
                            detail: I18n.translate('exceptions.invalid_sort_criteria.detail',
                                                    sort_criteria: sort_criteria, resource: resource))]
      end
    end

    class ParametersNotAllowed < Error
      attr_accessor :params
      def initialize(params)
        @params = params
      end

      def errors
        params.collect do |param|
          JSONAPI::Error.new(code: JSONAPI::PARAM_NOT_ALLOWED,
                             status: :bad_request,
                             title: I18n.translate('exceptions.parameters_not_allowed.title'),
                             detail: I18n.translate('exceptions.parameters_not_allowed.detail', param: param))

        end
      end
    end

    class ParameterMissing < Error
      attr_accessor :param
      def initialize(param)
        @param = param
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::PARAM_MISSING,
                            status: :bad_request,
                            title: I18n.translate('exceptions.parameter_missing.title'),
                            detail: I18n.translate('exceptions.parameter_missing.detail', param: param))]
      end
    end

    class CountMismatch < Error
      def errors
        [JSONAPI::Error.new(code: JSONAPI::COUNT_MISMATCH,
                            status: :bad_request,
                            title: I18n.translate('exceptions.count_mismatch.title'),
                            detail: I18n.translate('exceptions.count_mismatch.detail'))]
      end
    end

    class KeyNotIncludedInURL < Error
      attr_accessor :key
      def initialize(key)
        @key = key
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::KEY_NOT_INCLUDED_IN_URL,
                            status: :bad_request,
                            title: I18n.translate('exceptions.key_not_included_in_url.title'),
                            detail: I18n.translate('exceptions.key_not_included_in_url.detail',
                                                    key: key))]
      end
    end

    class MissingKey < Error
      def errors
        [JSONAPI::Error.new(code: JSONAPI::KEY_ORDER_MISMATCH,
                            status: :bad_request,
                            title: I18n.translate('exceptions.missing_key.title'),
                            detail: I18n.translate('exceptions.missing_key.detail'))]
      end
    end

    class RecordLocked < Error
      attr_accessor :message
      def initialize(message)
        @message = message
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::LOCKED,
                            status: :locked,
                            title: I18n.translate('exceptions.record_locked.title'),
                            detail: "#{message}")]
      end
    end

    class ValidationErrors < Error
      attr_reader :error_messages, :resource_relationships

      def initialize(resource)
        @error_messages = resource.model_error_messages
        @resource_relationships = resource.class._relationships.keys
        @key_formatter = JSONAPI.configuration.key_formatter
      end

      def format_key(key)
        @key_formatter.format(key)
      end

      def errors
        error_messages.flat_map do |attr_key, messages|
          messages.map { |message| json_api_error(attr_key, message) }
        end
      end

      private

      def json_api_error(attr_key, message)
        JSONAPI::Error.new(code: JSONAPI::VALIDATION_ERROR,
                           status: :unprocessable_entity,
                           title: message,
                           detail: "#{format_key(attr_key)} - #{message}",
                           source: { pointer: pointer(attr_key) })
      end

      def pointer(attr_or_relationship_name)
        formatted_attr_or_relationship_name = format_key(attr_or_relationship_name)
        if resource_relationships.include?(attr_or_relationship_name)
          "/data/relationships/#{formatted_attr_or_relationship_name}"
        else
          "/data/attributes/#{formatted_attr_or_relationship_name}"
        end
      end
    end

    class SaveFailed < Error
      def errors
        [JSONAPI::Error.new(code: JSONAPI::SAVE_FAILED,
                            status: :unprocessable_entity,
                            title: I18n.translate('exceptions.save_failed.title'),
                            detail: I18n.translate('exceptions.save_failed.detail'))]
      end
    end

    class InvalidPageObject < Error
      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_PAGE_OBJECT,
                            status: :bad_request,
                            title: I18n.translate('exceptions.invalid_page_object.title'),
                            detail: I18n.translate('exceptions.invalid_page_object.detail'))]
      end
    end

    class PageParametersNotAllowed < Error
      attr_accessor :params
      def initialize(params)
        @params = params
      end

      def errors
        params.collect do |param|
          JSONAPI::Error.new(code: JSONAPI::PARAM_NOT_ALLOWED,
                             status: :bad_request,
                             title: I18n.translate('exceptions.page_parameters_not_allowed.title'),
                             detail: I18n.translate('exceptions.page_parameters_not_allowed.detail', param: param))
        end
      end
    end

    class InvalidPageValue < Error
      attr_accessor :page, :value
      def initialize(page, value, msg = nil)
        @page = page
        @value = value
        @msg = msg || I18n.translate('exceptions.invalid_page_value.detail', value: value, page: page)
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_PAGE_VALUE,
                            status: :bad_request,
                            title: I18n.translate('exceptions.invalid_page_value.title'),
                            detail: @msg)]
      end
    end
  end
end
