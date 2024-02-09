#!/usr/bin/env rake
require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.verbose = true
  t.warning = false
  t.test_files = FileList['test/**/*_test.rb']
end

namespace :test do

  desc 'prepare test database'
  task :prepare_database do
    database_url = ENV["DATABASE_URL"]
    next if database_url.nil? || database_url.empty?
    require "active_record/railtie"
    connection_class = ActiveRecord::Base
    connection_class.establish_connection(database_url)
    database_config = connection_class
      .connection_db_config
      .configuration_hash
    database_adapter = database_config.fetch(:adapter)
    database_name = database_config.fetch(:database)
    database_username = database_config[:username]
    case database_adapter
    when :postgresql, "postgresql"
      sh "psql -c 'DROP DATABASE IF EXISTS #{database_name};' -U #{database_username};"
      sh "psql -c 'CREATE DATABASE #{database_name};' -U #{database_username};"
    when :mysql2, "mysql2"
      sh "mysql -c 'DROP DATABASE IF EXISTS #{database_name};' -U #{database_username};"
      sh "mysql -c 'CREATE DATABASE #{database_name};' -U #{database_username};"
    else
      nil # nothing to do for this database_adapter
    end
    puts "Preparing to run #{database_adapter} tests"
    connection_class.connection.disconnect!
  end

  desc 'Run benchmarks'
  Rake::TestTask.new(:benchmark) do |t|
    t.pattern = 'test/benchmark/*_benchmark.rb'
  end

  desc 'Test bug report template'
  namespace :bug_report_template do
    task :rails_5 do
      puts 'Test bug report templates'
      jsonapi_resources_root = File.expand_path('..', __FILE__)
      chdir_path = File.join(jsonapi_resources_root, 'lib', 'bug_report_templates')
      report_env = {'SILENT' => 'true', 'JSONAPI_RESOURCES_PATH' => jsonapi_resources_root}
      Bundler.with_clean_env do
        Dir.chdir(chdir_path) do
          abort('bug report template rails_5_master fails') unless system(report_env, Gem.ruby, 'rails_5_master.rb')
        end
      end
    end
  end
end

task default: [:"test:prepare_database", :test]
