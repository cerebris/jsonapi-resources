require File.expand_path('../../../../test_helper', __FILE__)
require 'generators/jsonapi/resource_generator'

module Jsonapi
  class ResourceGeneratorTest < Rails::Generators::TestCase
    tests ResourceGenerator
    destination Rails.root.join('../resources')
    setup :prepare_destination
    teardown :cleanup_destination_root

    def cleanup_destination_root
      FileUtils.rm_rf destination_root
    end

    test "resource is created" do
      run_generator ["post"]
      assert_file 'app/resources/post_resource.rb', /class PostResource < JSONAPI::Resource/
    end

    test "resource is singular" do
      run_generator ["posts"]
      assert_file 'app/resources/post_resource.rb', /class PostResource < JSONAPI::Resource/
    end

    test "resource is created with namespace" do
      run_generator ["api/v1/post"]
      assert_file 'app/resources/api/v1/post_resource.rb', /class Api::V1::PostResource < JSONAPI::Resource/
    end
  end
end
