# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'json/api/resources/version'

Gem::Specification.new do |spec|
  spec.name          = 'json-api-resources'
  spec.version       = JSON::API::Resources::VERSION
  spec.authors       = ['Larry Gebhardt']
  spec.email         = ['larry@cerebris.com']
  spec.summary       = %q{Provides JSON API support.}
  spec.description   = %q{Provides JSON API support.}
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest'

  spec.add_dependency 'activemodel'
  spec.add_dependency 'activesupport'
end
