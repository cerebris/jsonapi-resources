require 'json'

module JSONAPI
  MEDIA_TYPE = 'application/vnd.api+json'
  OPERATIONS_MEDIA_TYPE = 'application/vnd.operations+json'

  module MimeTypes
    def self.install
      Mime::Type.register JSONAPI::MEDIA_TYPE, :api_json
      Mime::Type.register JSONAPI::OPERATIONS_MEDIA_TYPE, :api_json_operations

      # :nocov:
      if Rails::VERSION::MAJOR >= 5
        parsers = ActionDispatch::Request.parameter_parsers.merge(
            Mime::Type.lookup(JSONAPI::MEDIA_TYPE).symbol => json_parser,
            Mime::Type.lookup(JSONAPI::OPERATIONS_MEDIA_TYPE).symbol => json_parser
        )
        ActionDispatch::Request.parameter_parsers = parsers
      else
        ActionDispatch::ParamsParser::DEFAULT_PARSERS[Mime::Type.lookup(JSONAPI::MEDIA_TYPE)] = json_parser
        ActionDispatch::ParamsParser::DEFAULT_PARSERS[Mime::Type.lookup(JSONAPI::OPERATIONS_MEDIA_TYPE)] = json_parser
      end
      # :nocov:
    end

    def self.json_parser
      lambda do |body|
        begin
          data = JSON.parse(body)
          if data.is_a?(Hash)
            data.with_indifferent_access
          else
            fail JSONAPI::Exceptions::InvalidRequestFormat.new
          end
        rescue JSON::ParserError => e
          { _parser_exception: JSONAPI::Exceptions::BadRequest.new(e.to_s)  }
        rescue => e
          { _parser_exception: e }
        end
      end
    end
  end

  MimeTypes.install
end
