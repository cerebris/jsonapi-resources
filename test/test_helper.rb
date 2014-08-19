require 'simplecov'

# To run tests with coverage
# COVERAGE=true rake test
if ENV['COVERAGE']
  SimpleCov.start do
  end
end

require 'minitest/autorun'
require 'minitest/spec'
require 'rails/all'

require 'json/api/routing_ext'

require File.expand_path('../helpers/value_matchers', __FILE__)
require File.expand_path('../helpers/hash_helpers', __FILE__)
require File.expand_path('../helpers/functional_helpers', __FILE__)

Rails.env = 'test'

class TestApp < Rails::Application
  config.eager_load = false
  config.root = File.dirname(__FILE__)
  config.session_store :cookie_store, key: 'session'
  config.secret_key_base = 'secret'

  #Raise errors on unsupported parameters
  config.action_controller.action_on_unpermitted_parameters = :raise
end

TestApp.initialize!

require File.expand_path('../fixtures/active_record', __FILE__)

TestApp.routes.draw do
  jsonapi_resources :authors
  jsonapi_all_resources

  namespace :api do
    namespace :v1 do
      jsonapi_all_resources
    end

    namespace :v2 do
      jsonapi_resources :authors
      jsonapi_resources :posts
      jsonapi_resource :preferences
    end

    namespace :v3 do
      jsonapi_resources :posts, except: [:destroy]
    end
  end
end

class MiniTest::Unit::TestCase
  include Helpers::HashHelpers
  include Helpers::ValueMatchers
  include Helpers::FunctionalHelpers
end

class ActiveSupport::TestCase
  setup do
    @routes = TestApp.routes
  end
end
