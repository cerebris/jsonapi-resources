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

require File.expand_path('../helpers/value_matchers', __FILE__)
require File.expand_path('../helpers/hash_helpers', __FILE__)
require File.expand_path('../helpers/functional_helpers', __FILE__)

Rails.env = 'test'

class TestApp < Rails::Application
  config.eager_load = false
  config.root = File.dirname(__FILE__)
  config.session_store :cookie_store, key: 'session'
  config.secret_key_base = 'secret'
end

TestApp.initialize!

TestApp.routes.draw do
  resources :people
  resources :posts
  resources :tags
  resources :expense_entries
  resources :currencies, :param => :code
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
