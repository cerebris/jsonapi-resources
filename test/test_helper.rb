require 'minitest/autorun'
require 'minitest/spec'
require 'rails/all'


JSON::API::Routes = ActionDispatch::Routing::RouteSet.new
JSON::API::Routes.draw do
  resources 'posts'
end

ActionController::Base.send :include, JSON::API::Routes.url_helpers

class ActiveSupport::TestCase
  setup do
    @routes = JSON::API::Routes
  end
end
