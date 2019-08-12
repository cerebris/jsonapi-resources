
JSONAPI.configuration.default_record_accessor_klass = JSONAPI::ActiveRecordRecordAccessor

TestApp.class_eval do
  config.active_record.schema_format = :none

  if Rails::VERSION::MAJOR >= 5
    config.active_support.halt_callback_chains_on_return_false = false
    config.active_record.time_zone_aware_types = [:time, :datetime]
    config.active_record.belongs_to_required_by_default = false
    if Rails::VERSION::MINOR >= 2
      config.active_record.sqlite3.represent_boolean_as_integer = true
    end
  end
end

class Minitest::Test
  include ActiveRecord::TestFixtures

  self.fixture_path = "#{Rails.root}/fixtures"
  fixtures :all
end

class ActiveSupport::TestCase
  self.fixture_path = "#{Rails.root}/fixtures"
  fixtures :all
end

class ActionDispatch::IntegrationTest
  self.fixture_path = "#{Rails.root}/fixtures"
  fixtures :all
end
