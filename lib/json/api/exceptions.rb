module JSON
  module API
    module Exceptions
      class Error < RuntimeError; end

      class InvalidResource < Error
        attr_accessor :resource
        def initialize(resource)
          @resource = resource
        end

        def errors
          [JSON::API::Error.new(code: JSON::API::INVALID_RESOURCE,
                               status: :bad_request,
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
          [JSON::API::Error.new(code: JSON::API::RECORD_NOT_FOUND,
                               status: :not_found,
                               title: 'Record not found',
                               detail: "The record identified by #{id} could not be found.")]
        end
      end

      class FilterNotAllowed < Error
        attr_accessor :filter
        def initialize(filter)
          @filter = filter
        end

        def errors
          [JSON::API::Error.new(code: JSON::API::FILTER_NOT_ALLOWED,
                               status: :bad_request,
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
          [JSON::API::Error.new(code: JSON::API::INVALID_FILTER_VALUE,
                               status: :bad_request,
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
          [JSON::API::Error.new(code: JSON::API::INVALID_FIELD_VALUE,
                               status: :bad_request,
                               title: 'Invalid field value',
                               detail: "#{value} is not a valid value for #{field}.")]
        end
      end

      class InvalidField < Error
        attr_accessor :field, :type
        def initialize(type, field)
          @field = field
          @type = type
        end

        def errors
          [JSON::API::Error.new(code: JSON::API::INVALID_FIELD,
                               status: :bad_request,
                               title: 'Invalid field',
                               detail: "#{field} is not a valid field for #{type}.")]
        end
      end

      class ParamsNotAllowed < Error
        attr_accessor :params
        def initialize(params)
          @params = params
        end

        def errors
              params.collect { |param|
                JSON::API::Error.new(code: JSON::API::PARAM_NOT_ALLOWED,
                               status: :bad_request,
                               title: 'Param not allowed',
                               detail: "#{param} is not allowed.")
              }

        end
      end

      class ParamMissing < Error
        attr_accessor :param
        def initialize(param)
          @param = param
        end

        def errors
          [JSON::API::Error.new(code: JSON::API::PARAM_MISSING,
                               status: :bad_request,
                               title: 'Missing Param',
                               detail: "The required param, #{param}, is missing.")]
        end
      end

      class RecordLocked < Error
        attr_accessor :message
        def initialize(message)
          @message = message
        end

        def errors
          [JSON::API::Error.new(code: JSON::API::LOCKED,
                               status: :locked,
                               title: 'Locked resource',
                               detail: "#{message}")]
        end
      end

      class ValidationErrors < Error
        attr_accessor :errors
        def initialize(errors)
          @errors = errors
        end
      end

    end
  end
end