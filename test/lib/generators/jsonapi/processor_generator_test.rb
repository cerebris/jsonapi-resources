require File.expand_path('../../../../test_helper', __FILE__)
require 'generators/jsonapi/processor/processor_generator'

module Jsonapi
  class ProcessorGeneratorTest < Rails::Generators::TestCase
    tests ProcessorGenerator
    destination File.expand_path('../tmp', __dir__ )
    setup :prepare_destination
    teardown :cleanup_destination_root

    def cleanup_destination_root
      FileUtils.rm_rf destination_root
    end

    test "processor is created" do
      run_generator %w[post]
      assert_file 'app/processors/post_processor.rb', /class PostProcessor < JSONAPI::Processor/
    end

    test "base processor class is settable" do
      run_generator %w[post --base_processor BaseProcessor]
      assert_file 'app/processors/post_processor.rb', /class PostProcessor < BaseProcessor/
    end

    test "processor is singular" do
      run_generator %w[posts]
      assert_file 'app/processors/post_processor.rb', /class PostProcessor < JSONAPI::Processor/
    end

    test "processor is created with namespace" do
      run_generator %w[api/v1/post]
      assert_file 'app/processors/api/v1/post_processor.rb', /class Api::V1::PostProcessor < JSONAPI::Processor/
    end
  end
end
