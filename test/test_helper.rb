require 'simplecov'

# To run tests with coverage:
# COVERAGE=true bundle exec rake test

# To test on a specific rails version use this:
# export RAILS_VERSION=4.2.6; bundle update rails; bundle exec rake test
# export RAILS_VERSION=5.0.0; bundle update rails; bundle exec rake test
# export RAILS_VERSION=5.1.0; bundle update rails; bundle exec rake test

# We are no longer having Travis test Rails 4.1.x., but you can try it with:
# export RAILS_VERSION=4.1.0; bundle update rails; bundle exec rake test

# To Switch rails versions and run a particular test order:
# export RAILS_VERSION=4.2.6; bundle update rails; bundle exec rake TESTOPTS="--seed=39333" test

if ENV['COVERAGE']
  SimpleCov.start do
  end
end

require 'active_record/railtie'
require 'rails/test_help'
require 'minitest/mock'
require 'jsonapi-resources'
require 'pry'

require File.expand_path('../helpers/value_matchers', __FILE__)
require File.expand_path('../helpers/assertions', __FILE__)
require File.expand_path('../helpers/functional_helpers', __FILE__)
require File.expand_path('../helpers/configuration_helpers', __FILE__)

Rails.env = 'test'

I18n.load_path += Dir[File.expand_path("../../locales/*.yml", __FILE__)]
I18n.enforce_available_locales = false

JSONAPI.configure do |config|
  config.json_key_format = :camelized_key
end

puts "Testing With RAILS VERSION #{Rails.version}"

class TestApp < Rails::Application
  config.eager_load = false
  config.root = File.dirname(__FILE__)
  config.session_store :cookie_store, key: 'session'
  config.secret_key_base = 'secret'

  #Raise errors on unsupported parameters
  config.action_controller.action_on_unpermitted_parameters = :raise

  ActiveRecord::Schema.verbose = false
  config.active_record.schema_format = :none
  config.active_support.test_order = :random

  if Rails::VERSION::MAJOR >= 5
    config.active_support.halt_callback_chains_on_return_false = false
    config.active_record.time_zone_aware_types = [:time, :datetime]
    config.active_record.belongs_to_required_by_default = false
  end
end

module MyEngine
  class Engine < ::Rails::Engine
    isolate_namespace MyEngine
  end
end

module ApiV2Engine
  class Engine < ::Rails::Engine
    isolate_namespace ApiV2Engine
  end
end

# Monkeypatch ActionController::TestCase to delete the RAW_POST_DATA on subsequent calls in the same test.
if Rails::VERSION::MAJOR >= 5
  module ClearRawPostHeader
    def process(action, *args)
      @request.delete_header 'RAW_POST_DATA'
      super
    end
  end

  class ActionController::TestCase
    prepend ClearRawPostHeader
  end
end

# Tests are now using the rails 5 format for the http methods. So for rails 4 we will simply convert them back
# in a standard way.
if Rails::VERSION::MAJOR < 5
  module Rails4ActionControllerProcess
    def process(*args)
      if args[2] && args[2][:params]
        args[2] = args[2][:params]
      end
      super
    end
  end
  class ActionController::TestCase
    prepend Rails4ActionControllerProcess
  end

  module ActionDispatch
    module Integration #:nodoc:
      module Rails4IntegrationProcess
        def process(method, path, parameters = nil, headers_or_env = nil)
          params = parameters.nil? ? nil : parameters[:params]
          headers = parameters.nil? ? nil : parameters[:headers]
          super method, path, params, headers
        end
      end

      class Session
        prepend Rails4IntegrationProcess
      end
    end
  end
end

# Patch to allow :api_json mime type to be treated as JSON
# Otherwise it is run through `to_query` and empty arrays are dropped.
if Rails::VERSION::MAJOR >= 5
  module ActionController
    class TestRequest < ActionDispatch::TestRequest
      def assign_parameters(routes, controller_path, action, parameters, generated_path, query_string_keys)
        non_path_parameters = {}
        path_parameters = {}

        parameters.each do |key, value|
          if query_string_keys.include?(key)
            non_path_parameters[key] = value
          else
            if value.is_a?(Array)
              value = value.map(&:to_param)
            else
              value = value.to_param
            end

            path_parameters[key] = value
          end
        end

        if get?
          if self.query_string.blank?
            self.query_string = non_path_parameters.to_query
          end
        else
          if ENCODER.should_multipart?(non_path_parameters)
            self.content_type = ENCODER.content_type
            data = ENCODER.build_multipart non_path_parameters
          else
            fetch_header('CONTENT_TYPE') do |k|
              set_header k, 'application/x-www-form-urlencoded'
            end

            # parser = ActionDispatch::Http::Parameters::DEFAULT_PARSERS[Mime::Type.lookup(fetch_header('CONTENT_TYPE'))]

            case content_mime_type.to_sym
              when nil
                raise "Unknown Content-Type: #{content_type}"
              when :json, :api_json
                data = ActiveSupport::JSON.encode(non_path_parameters)
              when :xml
                data = non_path_parameters.to_xml
              when :url_encoded_form
                data = non_path_parameters.to_query
              else
                @custom_param_parsers[content_mime_type] = ->(_) { non_path_parameters }
                data = non_path_parameters.to_query
            end
          end

          set_header 'CONTENT_LENGTH', data.length.to_s
          set_header 'rack.input', StringIO.new(data)
        end

        fetch_header("PATH_INFO") do |k|
          set_header k, generated_path
        end
        path_parameters[:controller] = controller_path
        path_parameters[:action] = action

        self.path_parameters = path_parameters
      end
    end
  end
end

def assert_query_count(expected, msg = nil, &block)
  @queries = []
  callback = lambda {|_, _, _, _, payload| @queries.push payload[:sql] }
  ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &block)

  show_queries unless expected == @queries.size
  assert expected == @queries.size, "Expected #{expected} queries, ran #{@queries.size} queries"
  @queries = nil
end

def show_queries
  @queries.each_with_index do |query, index|
    puts "sql[#{index}]: #{query}"
  end
end

TestApp.initialize!

require File.expand_path('../fixtures/active_record', __FILE__)

module Pets
  module V1
    class CatsController < JSONAPI::ResourceController

    end

    class CatResource < JSONAPI::Resource
      attribute :name
      attribute :breed

      key_type :uuid
    end
  end
end

JSONAPI.configuration.route_format = :underscored_route
TestApp.routes.draw do
  jsonapi_resources :people
  jsonapi_resources :special_people
  jsonapi_resources :comments
  jsonapi_resources :firms
  jsonapi_resources :tags
  jsonapi_resources :hair_cuts
  jsonapi_resources :posts do
    jsonapi_relationships
    jsonapi_links :special_tags
  end
  jsonapi_resources :sections
  jsonapi_resources :iso_currencies
  jsonapi_resources :expense_entries
  jsonapi_resources :breeds
  jsonapi_resources :planets
  jsonapi_resources :planet_types
  jsonapi_resources :moons
  jsonapi_resources :craters
  jsonapi_resources :preferences
  jsonapi_resources :facts
  jsonapi_resources :categories
  jsonapi_resources :pictures
  jsonapi_resources :documents
  jsonapi_resources :products
  jsonapi_resources :vehicles
  jsonapi_resources :cars
  jsonapi_resources :boats
  jsonapi_resources :flat_posts
  jsonapi_resources :blog_posts

  jsonapi_resources :books
  jsonapi_resources :authors

  jsonapi_resources :questions
  jsonapi_resources :answers
  jsonapi_resources :doctors
  jsonapi_resources :patients

  namespace :api do
    jsonapi_resources :boxes

    namespace :v1 do
      jsonapi_resources :people
      jsonapi_resources :comments
      jsonapi_resources :tags
      jsonapi_resources :posts
      jsonapi_resources :sections
      jsonapi_resources :iso_currencies
      jsonapi_resources :expense_entries
      jsonapi_resources :breeds
      jsonapi_resources :planets
      jsonapi_resources :planet_types
      jsonapi_resources :moons
      jsonapi_resources :craters
      jsonapi_resources :preferences
      jsonapi_resources :likes
      jsonapi_resources :pictures
    end

    JSONAPI.configuration.route_format = :underscored_route
    namespace :v2 do
      jsonapi_resources :posts do
        jsonapi_link :author, except: :destroy
      end

      jsonapi_resource :preferences, except: [:create, :destroy]

      jsonapi_resources :authors
      jsonapi_resources :books
      jsonapi_resources :book_comments
    end

    namespace :v3 do
      jsonapi_resource :preferences do
        # Intentionally empty block to skip relationship urls
      end

      jsonapi_resources :posts, except: [:destroy] do
        jsonapi_link :author, except: [:destroy]
        jsonapi_links :tags, only: [:show, :create]
      end
    end

    JSONAPI.configuration.route_format = :camelized_route
    namespace :v4 do
      jsonapi_resources :posts do
      end

      jsonapi_resources :expense_entries do
        jsonapi_link :iso_currency
        jsonapi_related_resource :iso_currency
      end

      jsonapi_resources :iso_currencies do
      end

      jsonapi_resources :books
    end

    JSONAPI.configuration.route_format = :dasherized_route
    namespace :v5 do
      jsonapi_resources :posts do
      end

      jsonapi_resources :authors
      jsonapi_resources :expense_entries
      jsonapi_resources :iso_currencies

      jsonapi_resources :employees

    end
    JSONAPI.configuration.route_format = :underscored_route

    JSONAPI.configuration.route_format = :dasherized_route
    namespace :v6 do
      jsonapi_resources :posts
      jsonapi_resources :sections
      jsonapi_resources :customers
      jsonapi_resources :purchase_orders
      jsonapi_resources :line_items
    end
    JSONAPI.configuration.route_format = :underscored_route

    namespace :v7 do
      jsonapi_resources :customers
      jsonapi_resources :purchase_orders
      jsonapi_resources :line_items
      jsonapi_resources :categories

      jsonapi_resources :clients
    end

    namespace :v8 do
      jsonapi_resources :numeros_telefone
    end
  end

  namespace :admin_api do
    namespace :v1 do
      jsonapi_resources :people
    end
  end

  namespace :dasherized_namespace, path: 'dasherized-namespace' do
    namespace :v1 do
      jsonapi_resources :people
    end
  end

  namespace :pets do
    namespace :v1 do
      jsonapi_resources :cats
    end
  end

  jsonapi_resources :keepers, only: [:show]
  jsonapi_resources :workers, only: [:show]

  mount MyEngine::Engine => "/boomshaka", as: :my_engine
  mount ApiV2Engine::Engine => "/api_v2", as: :api_v2_engine
end

MyEngine::Engine.routes.draw do
  namespace :api do
    namespace :v1 do
      jsonapi_resources :people
    end
  end

  namespace :admin_api do
    namespace :v1 do
      jsonapi_resources :people
    end
  end

  namespace :dasherized_namespace, path: 'dasherized-namespace' do
    namespace :v1 do
      jsonapi_resources :people
    end
  end
end

ApiV2Engine::Engine.routes.draw do
  jsonapi_resources :people
end

# Ensure backward compatibility with Minitest 4
Minitest::Test = MiniTest::Unit::TestCase unless defined?(Minitest::Test)

class Minitest::Test
  include Helpers::Assertions
  include Helpers::ValueMatchers
  include Helpers::FunctionalHelpers
  include Helpers::ConfigurationHelpers
  include ActiveRecord::TestFixtures

  def run_in_transaction?
    true
  end

  self.fixture_path = "#{Rails.root}/fixtures"
  fixtures :all
end

class ActiveSupport::TestCase
  self.fixture_path = "#{Rails.root}/fixtures"
  fixtures :all
  setup do
    @routes = TestApp.routes
  end
end

class ActionDispatch::IntegrationTest
  self.fixture_path = "#{Rails.root}/fixtures"
  fixtures :all

  def assert_jsonapi_response(expected_status, msg = nil)
    assert_equal JSONAPI::MEDIA_TYPE, response.content_type
    if status != expected_status && status >= 400
      pp json_response rescue nil
    end
    assert_equal expected_status, status, msg
  end

  def assert_jsonapi_get(url, msg = "GET response must be 200")
    get url, headers: { 'Accept' => JSONAPI::MEDIA_TYPE }
    assert_jsonapi_response 200, msg
  end

  # Perform a GET request, make sure it returns 200, then try it again with caching enabled
  # to make sure that doesn't affect the output.
  def assert_cacheable_jsonapi_get(url, cached_classes = :all)
    assert_nil JSONAPI.configuration.resource_cache

    assert_jsonapi_get url
    non_caching_response = json_response.dup

    cache = ActiveSupport::Cache::MemoryStore.new

    warmup = with_resource_caching(cache, cached_classes) do
      assert_jsonapi_get url, "Cache warmup GET response must be 200"
    end

    assert_equal(
      non_caching_response.pretty_inspect,
      json_response.pretty_inspect,
      "Cache warmup response must match normal response"
    )

    cached = with_resource_caching(cache, cached_classes) do
      assert_jsonapi_get url, "Cached GET response must be 200"
    end

    assert_equal(
      non_caching_response.pretty_inspect,
      json_response.pretty_inspect,
      "Cached response must match normal response"
    )
    assert_equal 0, cached[:total][:misses], "Cached response must not cause any cache misses"
    assert_equal warmup[:total][:misses], cached[:total][:hits], "Cached response must use cache"
  end
end

class ActionController::TestCase
  def assert_cacheable_get(action, *args)
    assert_nil JSONAPI.configuration.resource_cache

    normal_queries = []
    normal_query_callback = lambda {|_, _, _, _, payload| normal_queries.push payload[:sql] }
    ActiveSupport::Notifications.subscribed(normal_query_callback, 'sql.active_record') do
      get action, *args
    end
    non_caching_response = json_response_sans_backtraces
    non_caching_status = response.status

    # Don't let all the cache-testing requests mess with assert_query_count
    orig_queries = @queries.try(:dup)
    orig_request_headers = @request.headers.dup

    ar_resource_klass = nil
    modes = {none: [], all: :all}
    if @controller.class.included_modules.include?(JSONAPI::ActsAsResourceController)
      ar_resource_klass = @controller.send(:resource_klass)
      if ar_resource_klass._model_class.respond_to?(:arel_table)
        modes[:root_only] = [ar_resource_klass]
        modes[:all_but_root] = {except: [ar_resource_klass]}
      else
        ar_resource_klass = nil
      end
    end

    modes.each do |mode, cached_resources|
      cache = ActiveSupport::Cache::MemoryStore.new
      cache_activity = {}

      [:warmup, :lookup].each do |phase|
        begin
          cache_queries = []
          cache_query_callback = lambda {|_, _, _, _, payload| cache_queries.push payload[:sql] }
          cache_activity[phase] = with_resource_caching(cache, cached_resources) do
            ActiveSupport::Notifications.subscribed(cache_query_callback, 'sql.active_record') do
              @controller = nil
              setup_controller_request_and_response
              @request.headers.merge!(orig_request_headers.dup)
              get action, *args
            end
          end
        rescue Exception
          puts "Exception raised during cache (mode: #{mode}) #{phase}"
          raise
        end

        if response.status != non_caching_status
          pp json_response rescue nil
        end
        assert_equal(
          non_caching_status,
          response.status,
          "Cache (mode: #{mode}) #{phase} response status must match normal response"
        )
        assert_equal(
          non_caching_response.pretty_inspect,
          json_response_sans_backtraces.pretty_inspect,
          "Cache (mode: #{mode}) #{phase} response body must match normal response"
        )
        assert_operator(
          cache_queries.size,
          :<=,
          normal_queries.size*2, # Allow up to double the number of queries as the uncached action
          "Cache (mode: #{mode}) #{phase} action made too many queries:\n#{cache_queries.pretty_inspect}"
        )
      end

      if mode == :all
        # TODO Should also be caching :show_related_resource (non-plural) action
        if [:index, :show, :show_related_resources].include?(action)
          if ar_resource_klass && response.status == 200 && json_response["data"].try(:size) > 0
            assert_operator(
              cache_activity[:warmup][:total][:misses],
              :>,
              0,
              "Cache (mode: #{mode}) warmup response with non-empty data must cause cache misses"
            )
          end
        end

        assert_equal 0, cache_activity[:lookup][:total][:misses],
                     "Cache (mode: #{mode}) lookup response must not cause any cache misses"
        assert_operator(
          cache_activity[:lookup][:total][:hits],
          :>=,
          cache_activity[:warmup][:total][:misses],
         "Cache (mode: #{mode}) lookup response must use cache entries created by warmup"
        )
      end
    end

    @queries = orig_queries
  end

  private

  def json_response_sans_backtraces
    return nil if response.body.to_s.strip.empty?

    r = json_response.dup
    (r["errors"] || []).each do |err|
      err["meta"].delete("backtrace") if err.has_key?("meta")
    end
    return r
  end
end

class IntegrationBenchmark < ActionDispatch::IntegrationTest
  def self.runnable_methods
    methods_matching(/^bench_/)
  end

  def self.run_one_method(klass, method_name, reporter)
    Benchmark.bmbm(method_name.length) do |job|
      job.report(method_name) do
        super(klass, method_name, reporter)
      end
    end
    puts
  end
end

class UpperCamelizedKeyFormatter < JSONAPI::KeyFormatter
  class << self
    def format(key)
      super.camelize(:upper)
    end

    def unformat(formatted_key)
      formatted_key.to_s.underscore
    end
  end
end

class DateWithTimezoneValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value)
      raw_value.in_time_zone('Eastern Time (US & Canada)').to_s
    end
  end
end

class DateValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value)
      raw_value.strftime('%m/%d/%Y')
    end
  end
end

class TitleValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value)
      super(raw_value).titlecase
    end

    def unformat(value)
      value.to_s.downcase
    end
  end
end
