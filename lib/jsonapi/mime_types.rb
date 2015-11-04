# coding: utf-8
module JSONAPI
  MEDIA_TYPE = 'application/vnd.api+json'
end

Mime::Type.register JSONAPI::MEDIA_TYPE, :api_json

if ActionDispatch::ParamsParser.constants.include? :DEFAULT_PARSERS
  # Rails <= 4.y
  ActionDispatch::ParamsParser::DEFAULT_PARSERS[Mime::Type.lookup(JSONAPI::MEDIA_TYPE)] =
    lambda do |body|
      JSON.parse(body)
    end
else
  # Rails 5 >= rails/rails@b93c226d19615fe504f9e12d6c0ee2d70683e5fa
  ActionDispatch::Http::Parameters::DEFAULT_PARSERS[Mime::Type.lookup(JSONAPI::MEDIA_TYPE)] =
    lambda do |body|
      JSON.parse(body)
    end
end
