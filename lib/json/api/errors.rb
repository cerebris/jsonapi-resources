module JSON
  module API
    module Errors
      class Error < RuntimeError; end

      class InvalidArgument < Error
        attr_accessor :argument
        def initialize(argument)
          @argument = argument
        end
      end

      class FilterNotAllowed < Error
        attr_accessor :filter
        def initialize(filter)
          @filter = filter
        end
      end

      class InvalidFilterValue < Error
        attr_accessor :field, :value
        def initialize(filter, value)
          @filter = filter
          @value = value
        end
      end

      class InvalidField < Error
        attr_accessor :field, :type
        def initialize(type, field)
          @field = field
          @type = type
        end
      end

      class InvalidFieldFormat < Error; end

    end
  end
end