module JSONAPI
  MEDIA_TYPE = 'application/vnd.api+json'
end

Mime::Type.register JSONAPI::MEDIA_TYPE, :api_json

params_klass = case Rails::VERSION::MAJOR
               when 5 then ActionDispatch::Http::Parameters
               else ActionDispatch::ParamsParser
               end

params_klass::DEFAULT_PARSERS[Mime::Type.lookup(JSONAPI::MEDIA_TYPE)] = lambda do |body|
  data = JSON.parse(body)
  data = {:_json => data} unless data.is_a?(Hash)
  data.with_indifferent_access
end
