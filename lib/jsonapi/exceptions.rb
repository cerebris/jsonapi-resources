module JSONAPI
  module Exceptions
    class Error < RuntimeError; end

    class InternalServerError < Error
      attr_accessor :exception

      def initialize(exception)
        @exception = exception
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::INTERNAL_SERVER_ERROR,
                            status: 500,
                            title: 'Internal Server Error',
                            detail: 'Internal Server Error')]
      end
    end

    class InvalidResource < Error
      attr_accessor :resource
      def initialize(resource)
        @resource = resource
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_RESOURCE,
                            status: 400,
                            title: 'Invalid resource',
                            detail: "#{resource} is not a valid resource.")]
      end
    end

    class RecordNotFound < Error
      attr_accessor :id
      def initialize(id)
        @id = id
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::RECORD_NOT_FOUND,
                            status: 404,
                            title: 'Record not found',
                            detail: "The record identified by #{id} could not be found.")]
      end
    end

    class UnsupportedMediaTypeError < Error
      attr_accessor :media_type
      def initialize(media_type)
        @media_type = media_type
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::UNSUPPORTED_MEDIA_TYPE,
                            status: 415,
                            title: 'Unsupported media type',
                            detail: "All requests that create or update resources must use the '#{JSONAPI::MEDIA_TYPE}' Content-Type. This request specified '#{media_type}.'")]
      end
    end

    class HasManyRelationExists < Error
      attr_accessor :id
      def initialize(id)
        @id = id
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::RELATION_EXISTS,
                            status: 400,
                            title: 'Relation exists',
                            detail: "The relation to #{id} already exists.")]
      end
    end

    class ToManySetReplacementForbidden < Error
      def errors
        [JSONAPI::Error.new(code: JSONAPI::FORBIDDEN,
                            status: 403,
                            title: 'Complete replacement forbidden',
                            detail: 'Complete replacement forbidden for this relationship')]
      end
    end

    class InvalidFiltersSyntax < Error
      attr_accessor :filters
      def initialize(filters)
        @filters = filters
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_FILTERS_SYNTAX,
                            status: 400,
                            title: 'Invalid filters syntax',
                            detail: "#{filters} is not a valid syntax for filtering.")]
      end
    end

    class FilterNotAllowed < Error
      attr_accessor :filter
      def initialize(filter)
        @filter = filter
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::FILTER_NOT_ALLOWED,
                            status: 400,
                            title: 'Filter not allowed',
                            detail: "#{filter} is not allowed.")]
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
                            status: 400,
                            title: 'Invalid filter value',
                            detail: "#{value} is not a valid value for #{filter}.")]
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
                            status: 400,
                            title: 'Invalid field value',
                            detail: "#{value} is not a valid value for #{field}.")]
      end
    end

    class InvalidFieldFormat < Error
      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_FIELD_FORMAT,
                            status: 400,
                            title: 'Invalid field format',
                            detail: 'Fields must specify a type.')]
      end
    end

    class InvalidLinksObject < Error
      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_LINKS_OBJECT,
                            status: 400,
                            title: 'Invalid Links Object',
                            detail: 'Data is not a valid Links Object.')]
      end
    end

    class TypeMismatch < Error
      attr_accessor :type
      def initialize(type)
        @type = type
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::TYPE_MISMATCH,
                            status: 400,
                            title: 'Type Mismatch',
                            detail: "#{type} is not a valid type for this operation.")]
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
                            status: 400,
                            title: 'Invalid field',
                            detail: "#{field} is not a valid field for #{type}.")]
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
                            status: 400,
                            title: 'Invalid field',
                            detail: "#{relationship} is not a valid relationship of #{resource}")]
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
                            status: 400,
                            title: 'Invalid sort criteria',
                            detail: "#{sort_criteria} is not a valid sort criteria for #{resource}")]
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
                             status: 400,
                             title: 'Param not allowed',
                             detail: "#{param} is not allowed.")
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
                            status: 400,
                            title: 'Missing Parameter',
                            detail: "The required parameter, #{param}, is missing.")]
      end
    end

    class CountMismatch < Error
      def errors
        [JSONAPI::Error.new(code: JSONAPI::COUNT_MISMATCH,
                            status: 400,
                            title: 'Count to key mismatch',
                            detail: 'The resource collection does not contain the same number of objects as the number of keys.')]
      end
    end

    class KeyNotIncludedInURL < Error
      attr_accessor :key
      def initialize(key)
        @key = key
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::KEY_NOT_INCLUDED_IN_URL,
                            status: 400,
                            title: 'Key is not included in URL',
                            detail: "The URL does not support the key #{key}")]
      end
    end

    class MissingKey < Error
      def errors
        [JSONAPI::Error.new(code: JSONAPI::KEY_ORDER_MISMATCH,
                            status: 400,
                            title: 'A key is required',
                            detail: 'The resource object does not contain a key.')]
      end
    end

    class RecordLocked < Error
      attr_accessor :message
      def initialize(message)
        @message = message
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::LOCKED,
                            status: 423,
                            title: 'Locked resource',
                            detail: "#{message}")]
      end
    end

    class ValidationErrors < Error
      attr_reader :error_messages, :resource_relationships

      def initialize(resource)
        @error_messages = resource.model.errors.messages
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
                           status: 422,
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
                            status: 422,
                            title: 'Save failed or was cancelled',
                            detail: 'Save failed or was cancelled')]
      end
    end

    class InvalidPageObject < Error
      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_PAGE_OBJECT,
                            status: 400,
                            title: 'Invalid Page Object',
                            detail: 'Invalid Page Object.')]
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
                             status: 400,
                             title: 'Page parameter not allowed',
                             detail: "#{param} is not an allowed page parameter.")
        end
      end
    end

    class InvalidPageValue < Error
      attr_accessor :page, :value
      def initialize(page, value, msg = nil)
        @page = page
        @value = value
        @msg = msg || "#{value} is not a valid value for #{page} page parameter."
      end

      def errors
        [JSONAPI::Error.new(code: JSONAPI::INVALID_PAGE_VALUE,
                            status: 400,
                            title: 'Invalid page value',
                            detail: @msg)]
      end
    end
  end
end
