# frozen_string_literal: true

require 'jsonapi/acts_as_resource_controller'
require 'jsonapi/basic_resource'
if Rails::VERSION::MAJOR >= 6
  ActiveSupport.on_load(:action_controller_base) do
    require 'jsonapi/resource_controller'
  end
else
  require 'jsonapi/resource_controller'
end
Dir[File.expand_path('jsonapi/**/*.rb', __dir__)].reverse.each do |f|
  require f
end
