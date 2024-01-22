# frozen_string_literal: true

module JSONAPI
  module Resources
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load 'tasks/check_upgrade.rake'
      end


      initializer "jsonapi_resources.testing", after: :initialize do
        next unless Rails.env.test?
        # Make response.parsed_body work
        ActionDispatch::IntegrationTest.register_encoder :api_json,
          param_encoder: ->(params) {
            params
          },
          response_parser: ->(body) {
            JSONAPI::MimeTypes.parser.call(body)
          }
      end
    end
  end
end
