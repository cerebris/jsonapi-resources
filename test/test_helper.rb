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

  #Raise errors on unsupported parameters
  config.action_controller.action_on_unpermitted_parameters = :raise
end

TestApp.initialize!

require File.expand_path('../fixtures/active_record', __FILE__)

# TestApp.routes.finalize!

TestApp.routes.draw do
  resources :author
end

# TestApp.routes.draw do
#   JSON::API::Resource._resource_types.each do |resource_type|
#     resource = JSON::API::Resource.resource_for(resource_type)
#     resources resource_type, resource.routing_resource_options
#   end
#   resources :author
# end

# TestApp.routes.draw do
#   resources :author
#   resources :people
#   # resources :posts
#   resources :posts do
#     match 'links/:relation', controller: 'posts', action: 'show', via: [:get]
#     match 'links/:relation', controller: 'posts', action: 'update', via: [:put]
#     match 'links/:relation', controller: 'posts', action: 'destroy', via: [:delete]
#   end
#
#   resources :tags
#   resources :expense_entries
#   resources :currencies, :param => :code
#   resources :breeds
#
#
#   namespace :api, defaults: {format: 'json'}  do
#     namespace :v1 do
#
#     end
#   end
# end

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
