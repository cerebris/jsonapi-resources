require 'jsonapi/resource'
require 'jsonapi/resource_controller'
require 'jsonapi/resources/version'
require 'jsonapi/configuration'
require 'jsonapi/paginator'
require 'jsonapi/formatter'
require 'jsonapi/routing_ext'
require 'jsonapi/mime_types'
if Rails::VERSION::MAJOR < 4
  require 'jsonapi/rails-3.2/polyfill'
end
