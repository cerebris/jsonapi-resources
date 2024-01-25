# frozen_string_literal: true

module JSONAPI
  module Resources
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load 'tasks/check_upgrade.rake'
      end

      # https://guides.rubyonrails.org/v6.0/engines.html#available-hooks
      ActiveSupport.on_load(:action_dispatch_integration_test) do
        # Make response.parsed_body work
        ::ActionDispatch::IntegrationTest.register_encoder :api_json,
          param_encoder: ->(params) {
            params
          },
          response_parser: ->(body) {
            ::JSONAPI::MimeTypes.parser.call(body)
          }
      end

      initializer "jsonapi_resources.initialize", after: :initialize do
        JSONAPI::Utils::PolymorphicTypesLookup.polymorphic_types_lookup_clear!
      end
    end
  end
end
