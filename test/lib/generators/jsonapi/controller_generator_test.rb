require File.expand_path('../../../../test_helper', __FILE__)
require 'generators/jsonapi/controller/controller_generator'

module Jsonapi
  class ControllerGeneratorTest < Rails::Generators::TestCase
    tests ControllerGenerator
    destination File.expand_path('../tmp', __dir__ )
    setup :prepare_destination
    teardown :cleanup_destination_root

    def cleanup_destination_root
      FileUtils.rm_rf destination_root
    end

    def prepare_destination
      super
      FileUtils.cp_r File.expand_path('app_template/', __dir__ ) + '/.', destination_root
    end

    test "controller is created" do
      run_generator ["post"]
      assert_file 'app/controllers/posts_controller.rb', /class PostsController < JSONAPI::ResourceController/
    end

    test "base controller class is settable" do
      run_generator %w[post --base_controller BaseController]
      assert_file 'app/controllers/posts_controller.rb', /class PostsController < BaseController/
    end

    test "controller is created with namespace" do
      run_generator ["api/post"]
      assert_file 'app/controllers/api/posts_controller.rb', /class Api::PostsController < JSONAPI::ResourceController/
      assert_file 'config/routes.rb', /^( *)namespace :api do\n( *)jsonapi_resources :posts\n( *)end$/
    end
  end
end
