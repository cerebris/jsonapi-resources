require 'json'

module JSONAPI
  MEDIA_TYPE = 'application/vnd.api+json'.freeze

  module MimeTypes
    def self.install
      Mime::Type.register JSONAPI::MEDIA_TYPE, :api_json

      # :nocov:
      if Rails::VERSION::MAJOR >= 5
        parsers = ActionDispatch::Request.parameter_parsers.merge(
          Mime::Type.lookup(JSONAPI::MEDIA_TYPE).symbol => parser
        )
        ActionDispatch::Request.parameter_parsers = parsers
      else
        ActionDispatch::ParamsParser::DEFAULT_PARSERS[Mime::Type.lookup(JSONAPI::MEDIA_TYPE)] = parser
      end
      # :nocov:
    end

    def self.parser
      lambda do |body|
        begin
          data = JSON.parse(body)
          raise JSONAPI::Exceptions::InvalidRequestFormat unless data.is_a?(Hash)
          data.with_indifferent_access
        rescue JSON::ParserError => e
          { _parser_exception: JSONAPI::Exceptions::BadRequest.new(e.to_s) }
        rescue => e
          { _parser_exception: e }
        end
      end
    end
  end

  MimeTypes.install
end
