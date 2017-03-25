# To specify a different ORM, set ORM environment variable to the name of the orm, like 'sequel'.
ENV["ORM"] ||= "active_record"

module Orm
  class TestConfigurator
    attr_accessor :name, :railtie_file

    def record_accessor_class
      "JSONAPI::#{name.classify}RecordAccessor".constantize
    end

    def models_path
      File.expand_path("../fixtures/#{name}", __FILE__)
    end

  end

end

ORM_TEST_CONFIGURATOR = Orm::TestConfigurator.new

require_relative "#{ENV["ORM"]}/orm_test_configurator"