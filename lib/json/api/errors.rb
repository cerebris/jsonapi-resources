module JSON
  module API
    module Errors
      class Error < RuntimeError; end
      class InvalidArgument < Error; end
    end
  end
end