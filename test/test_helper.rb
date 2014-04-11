require 'minitest/autorun'
require 'minitest/spec'
require 'rails/all'

require File.expand_path('../helpers/value_matchers', __FILE__)
require File.expand_path('../helpers/hash_helpers', __FILE__)

JSON::API::Routes = ActionDispatch::Routing::RouteSet.new
JSON::API::Routes.draw do
  resources 'posts'
end

ActionController::Base.send :include, JSON::API::Routes.url_helpers

class MiniTest::Unit::TestCase
  include Helpers::HashHelpers
  include Helpers::ValueMatchers
end

class ActiveSupport::TestCase
  setup do
    @routes = JSON::API::Routes
  end
end
