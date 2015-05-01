require 'simplecov'

# To run tests with coverage:
# COVERAGE=true rake test
# To Switch rails versions and run a particular test order:
# export RAILS_VERSION=4.2; bundle update rails; bundle exec rake TESTOPTS="--seed=39333" test

if ENV['COVERAGE']
  SimpleCov.start do
  end
end

require 'rails/all'
require 'rails/test_help'
if Rails::VERSION::MAJOR < 4
  require 'jsonapi/rails-3.2/polyfill'
  require 'minitest/autorun'
  require 'minitest/spec'
end
require 'jsonapi-resources'

require File.expand_path('../helpers/value_matchers', __FILE__)
require File.expand_path('../helpers/hash_helpers', __FILE__)
require File.expand_path('../helpers/functional_helpers', __FILE__)

Rails.env = 'test'

JSONAPI.configure do |config|
  config.json_key_format = :camelized_key
end

puts "Testing With RAILS VERSION #{Rails.version}"

class TestApp < Rails::Application
  config.eager_load = false
  config.root = File.dirname(__FILE__)
  config.session_store :cookie_store, key: 'session'
  config.secret_key_base = 'secret'

  #Raise errors on unsupported parameters
  config.action_controller.action_on_unpermitted_parameters = :raise

  config.active_record.schema_format = :none
  config.active_support.test_order = :random

  # Turn off millisecond precision to maintain Rails 4.0 and 4.1 compatibility in test results
  ActiveSupport::JSON::Encoding.time_precision = 0 if Rails::VERSION::MAJOR >= 4 && Rails::VERSION::MINOR >= 1
end

# Patch RAILS 4.0 to not use millisecond precision
if Rails::VERSION::MAJOR >= 4 && Rails::VERSION::MINOR < 1
  module ActiveSupport
    class TimeWithZone
      def as_json(options = nil)
        if ActiveSupport::JSON::Encoding.use_standard_json_time_format
          xmlschema
        else
          %(#{time.strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)})
        end
      end
    end
  end
end

TestApp.initialize!

require File.expand_path('../fixtures/active_record', __FILE__)

JSONAPI.configuration.route_format = :underscored_route
TestApp.routes.draw do
  jsonapi_resources :people
  jsonapi_resources :comments
  jsonapi_resources :tags
  jsonapi_resources :posts do
    jsonapi_relationships
  end
  jsonapi_resources :sections
  jsonapi_resources :iso_currencies
  jsonapi_resources :expense_entries
  jsonapi_resources :breeds
  jsonapi_resources :planets
  jsonapi_resources :planet_types
  jsonapi_resources :moons
  jsonapi_resources :preferences
  jsonapi_resources :facts

  namespace :api do
    namespace :v1 do
      jsonapi_resources :people
      jsonapi_resources :comments
      jsonapi_resources :tags
      jsonapi_resources :posts
      jsonapi_resources :sections
      jsonapi_resources :iso_currencies
      jsonapi_resources :expense_entries
      jsonapi_resources :breeds
      jsonapi_resources :planets
      jsonapi_resources :planet_types
      jsonapi_resources :moons
      jsonapi_resources :preferences
      jsonapi_resources :likes
    end

    JSONAPI.configuration.route_format = :underscored_route
    namespace :v2 do
      jsonapi_resources :posts do
        jsonapi_link :author, except: [:destroy]
      end

      jsonapi_resource :preferences

      jsonapi_resources :books
      jsonapi_resources :book_comments
    end

    namespace :v3 do
      jsonapi_resource :preferences do
        # Intentionally empty block to skip association urls
      end

      jsonapi_resources :posts, except: [:destroy] do
        jsonapi_link :author, except: [:destroy]
        jsonapi_links :tags, only: [:show, :create]
      end
    end

    JSONAPI.configuration.route_format = :camelized_route
    namespace :v4 do
      jsonapi_resources :posts do
      end

      jsonapi_resources :expense_entries do
        jsonapi_link :iso_currency
        jsonapi_related_resource :iso_currency
      end

      jsonapi_resources :iso_currencies do
      end
    end

    JSONAPI.configuration.route_format = :dasherized_route
    namespace :v5 do
      jsonapi_resources :posts do
      end

      jsonapi_resources :authors
      jsonapi_resources :expense_entries
      jsonapi_resources :iso_currencies

      jsonapi_resources :employees

    end
    JSONAPI.configuration.route_format = :underscored_route

    JSONAPI.configuration.route_format = :dasherized_route
    namespace :v6 do
      jsonapi_resources :customers
      jsonapi_resources :purchase_orders
      jsonapi_resources :line_items
    end
    JSONAPI.configuration.route_format = :underscored_route

    namespace :v7 do
      jsonapi_resources :customers
      jsonapi_resources :purchase_orders
      jsonapi_resources :line_items
    end

    namespace :v8 do
      jsonapi_resources :numeros_telefone
    end
  end
end

# Ensure backward compatibility with Minitest 4
Minitest::Test = MiniTest::Unit::TestCase unless defined?(Minitest::Test)

class Minitest::Test
  include Helpers::HashHelpers
  include Helpers::ValueMatchers
  include Helpers::FunctionalHelpers
end

class ActiveSupport::TestCase
  self.fixture_path = "#{Rails.root}/fixtures"
  fixtures :all
  setup do
    @routes = TestApp.routes
  end
end

class ActionDispatch::IntegrationTest
  self.fixture_path = "#{Rails.root}/fixtures"
  fixtures :all
end

class UpperCamelizedKeyFormatter < JSONAPI::KeyFormatter
  class << self
    def format(key)
      super.camelize(:upper)
    end

    def unformat(formatted_key)
      formatted_key.to_s.underscore
    end
  end
end

class DateWithTimezoneValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value)
      raw_value.in_time_zone('Eastern Time (US & Canada)').to_s
    end
  end
end

class DateValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value)
      raw_value.strftime('%m/%d/%Y')
    end
  end
end

class TitleValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value)
      super(raw_value).titlecase
    end

    def unformat(value)
      value.to_s.downcase
    end
  end
end
