module JSONAPI
  MEDIA_TYPE = 'application/vnd.api+json'

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
        data = JSON.parse(body)
        data = {:_json => data} unless data.is_a?(Hash)
        data.with_indifferent_access
      end
    end
  end

  MimeTypes.install
end
