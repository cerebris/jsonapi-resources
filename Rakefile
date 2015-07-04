#!/usr/bin/env rake
require 'bundler/gem_tasks'
require 'rake/testtask'
require './test/test_helper.rb'

TestApp.load_tasks

task default: :test

desc 'Run tests in isolated processes'
namespace :test do
  task :isolated do
    Dir[test_task.pattern].each do |file|
      cmd = ['ruby']
      test_task.libs.each { |l| cmd << '-I' << l }
      cmd << file
      sh cmd.join(' ')
    end
  end
end
