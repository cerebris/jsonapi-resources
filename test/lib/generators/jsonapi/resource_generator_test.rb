require 'test_helper'
require 'generators/jsonapi/resource_generator'

module Jsonapi
  class ResourceGeneratorTest < Rails::Generators::TestCase
    tests ResourceGenerator
    destination Rails.root.join('../resources')
    setup :prepare_destination

    test "resource is created" do
      run_generator ["post"]
      assert_file 'app/resources/post_resource.rb'
    end
  end
end
