require File.expand_path('../../../../test_helper', __FILE__)
require 'generators/jsonapi/resource/resource_generator'

module Jsonapi
  class ResourceGeneratorTest < Rails::Generators::TestCase
    tests ResourceGenerator
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

    test "resource is created" do
      run_generator %w[post]
      assert_file 'app/resources/post_resource.rb', /class PostResource < JSONAPI::Resource/
    end

    test "resource created with controller and processors" do
      run_generator %w[post --controller --processor]
      assert_file 'app/resources/post_resource.rb', /class PostResource < JSONAPI::Resource/
      assert_file 'app/controllers/posts_controller.rb', /class PostsController < JSONAPI::ResourceController/
      assert_file 'app/processors/post_processor.rb', /class PostProcessor < JSONAPI::Processor/
    end

    test "base resource class is settable" do
      run_generator %w[post --base_resource BaseResource]
      assert_file 'app/resources/post_resource.rb', /class PostResource < BaseResource/
    end

    test "resource is singular" do
      run_generator %w[posts]
      assert_file 'app/resources/post_resource.rb', /class PostResource < JSONAPI::Resource/
    end

    test "namespaced resource is created" do
      run_generator %w[api/post]
      assert_file 'app/resources/api/post_resource.rb', /class Api::PostResource < JSONAPI::Resource/
    end

    test "namespaced resource, controller and processor are created" do
      run_generator %w[api/post --controller --processor]
      assert_file 'app/resources/api/post_resource.rb', /class Api::PostResource < JSONAPI::Resource/
      assert_file 'app/controllers/api/posts_controller.rb', /class Api::PostsController < JSONAPI::ResourceController/
      assert_file 'app/processors/api/post_processor.rb', /class Api::PostProcessor < JSONAPI::Processor/
      assert_file 'config/routes.rb', /^( *)namespace :api do\n( *)jsonapi_resources :posts\n( *)end$/
    end
  end
end
